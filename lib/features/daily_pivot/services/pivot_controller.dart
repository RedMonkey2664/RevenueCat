import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/market/candle.dart';
import '../../../core/market/instrument.dart';
import '../../../core/services/progress_service.dart';
import '../model/pivot_models.dart';
import 'pivot_backend.dart';
import 'pivot_price_service.dart';
import 'pivot_store.dart';

/// Which of the Pivot's screens applies right now (artboards 1g–1j plus the
/// two edges of the day the wireframes leave implicit).
enum PivotPhase {
  loading,

  /// Before 09:00 IST: today's question does not exist yet.
  beforeOpen,

  /// 1g — open, no vote yet.
  voting,

  /// 1h — vote sealed, waiting for 17:00.
  locked,

  /// 1i — 17:00 has passed; the crowd is revealed.
  pollClosed,

  /// 1j — the outcome, and what it paid.
  resolved,

  /// After 17:00 with no vote cast today.
  missed,

  /// The strike could not be read; nothing can be asked without it.
  failed,
}

@immutable
class PivotViewState {
  const PivotViewState({
    required this.phase,
    required this.dayKey,
    this.strike,
    this.live,
    this.tape = const <Candle>[],
    this.vote,
    this.tally,
    this.outcome,
    this.award,
    this.streak = 0,
    this.pivotDay = 1,
    this.error,
    this.outcomeError,
    this.sourceLabel = 'Binance · live',
  });

  final PivotPhase phase;
  final String dayKey;
  final double? strike;
  final Quote? live;
  final List<Candle> tape;
  final PivotVote? vote;
  final PivotTally? tally;
  final PivotOutcome? outcome;
  final PivotAward? award;

  /// Consecutive resolved days taken part in.
  final int streak;

  /// Days since this device's first vote, counting today: "DAY 128".
  final int pivotDay;

  final String? error;

  /// Set when 17:00 has passed but the closing price could not be read.
  final String? outcomeError;

  final String sourceLabel;

  /// Whether the sealed call is ahead at the live price.
  bool? get callInFront {
    final PivotVote? v = vote;
    final double? k = strike;
    final Quote? q = live;
    if (v == null || k == null || q == null) return null;
    return (v.choice == PivotChoice.yes) == (q.price > k);
  }

  PivotViewState copyWith({
    PivotPhase? phase,
    double? strike,
    Quote? live,
    List<Candle>? tape,
    PivotVote? vote,
    PivotTally? tally,
    PivotOutcome? outcome,
    PivotAward? award,
    int? streak,
    int? pivotDay,
    String? error,
    String? outcomeError,
    bool clearErrors = false,
  }) {
    return PivotViewState(
      phase: phase ?? this.phase,
      dayKey: dayKey,
      strike: strike ?? this.strike,
      live: live ?? this.live,
      tape: tape ?? this.tape,
      vote: vote ?? this.vote,
      tally: tally ?? this.tally,
      outcome: outcome ?? this.outcome,
      award: award ?? this.award,
      streak: streak ?? this.streak,
      pivotDay: pivotDay ?? this.pivotDay,
      error: clearErrors ? null : (error ?? this.error),
      outcomeError: clearErrors ? null : (outcomeError ?? this.outcomeError),
      sourceLabel: sourceLabel,
    );
  }
}

final NotifierProvider<PivotController, PivotViewState>
pivotControllerProvider = NotifierProvider<PivotController, PivotViewState>(
  PivotController.new,
);

/// A red dot on the PIVOT tab: today's question is open and unanswered, or
/// its outcome is in and has not been looked at.
final Provider<bool> pivotNeedsAttentionProvider = Provider<bool>((Ref ref) {
  final PivotViewState s = ref.watch(pivotControllerProvider);
  return s.phase == PivotPhase.voting ||
      (s.phase == PivotPhase.pollClosed && s.outcome != null);
});

/// The Pivot streak, for the campaign's stats strip.
final Provider<int> pivotStreakProvider = Provider<int>(
  (Ref ref) => ref.watch(pivotControllerProvider).streak,
);

/// Runs the day: fetches the strike, seals the vote, resolves the outcome at
/// 17:00 IST and pays it into the shared Discipline Points total — once.
class PivotController extends Notifier<PivotViewState> {
  /// Injectable for tests; the real clock in the app.
  @visibleForTesting
  DateTime Function() clock = () => DateTime.now().toUtc();

  PivotStore get _store => ref.read(pivotStoreProvider);
  PivotPriceService get _prices => ref.read(pivotPriceServiceProvider);
  PivotBackend get _backend => ref.read(pivotBackendProvider);

  bool _loading = false;

  @override
  PivotViewState build() {
    scheduleMicrotask(load);
    return PivotViewState(
      phase: PivotPhase.loading,
      dayKey: PivotClock.dayKey(clock()),
    );
  }

  int _streakFor(String today) {
    final Set<String> days = _store.resolvedDays;
    if (days.contains(today)) return PivotScoring.streakEndingOn(today, days);
    final String yesterday = PivotClock.previousDay(today);
    return days.contains(yesterday)
        ? PivotScoring.streakEndingOn(yesterday, days)
        : 0;
  }

  int _pivotDayFor(String today) {
    final String? first = _store.firstVoteDay;
    if (first == null) return 1;
    final DateTime a = PivotClock.openUtc(first);
    final DateTime b = PivotClock.openUtc(today);
    return b.difference(a).inDays + 1;
  }

  /// Works out where the day is and fetches what that phase needs.
  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    try {
      await _load();
    } finally {
      _loading = false;
    }
  }

  Future<void> _load() async {
    final DateTime now = clock();
    final String day = PivotClock.dayKey(now);
    final PivotWindow window = PivotWindow.at(now);
    final PivotVote? vote = _store.vote(day);

    state = PivotViewState(
      phase: state.dayKey == day ? state.phase : PivotPhase.loading,
      dayKey: day,
      vote: vote,
      strike: vote?.strike ?? _store.strike(day),
      outcome: _store.outcome(day),
      award: _store.award(day),
      streak: _streakFor(day),
      pivotDay: _pivotDayFor(day),
      live: state.dayKey == day ? state.live : null,
      tape: state.dayKey == day ? state.tape : const <Candle>[],
      sourceLabel: _prices.sourceLabel,
    );

    if (window == PivotWindow.beforeOpen) {
      state = state.copyWith(phase: PivotPhase.beforeOpen);
      return;
    }

    // The strike: stored once fetched, so a day is asked against one number.
    double? strike = state.strike;
    if (strike == null) {
      try {
        strike = await _prices.strikeFor(day);
        await _store.saveStrike(day, strike);
        state = state.copyWith(strike: strike);
      } on Object catch (error) {
        state = state.copyWith(
          phase: PivotPhase.failed,
          error: error.toString(),
        );
        return;
      }
    }

    if (window == PivotWindow.open) {
      state = state.copyWith(
        phase: vote == null ? PivotPhase.voting : PivotPhase.locked,
        tally: await _backend.tally(day),
        clearErrors: true,
      );
      await refreshLive();
      return;
    }

    // Closed. The crowd is revealed and the day can be resolved.
    final PivotTally tally = await _backend.tally(day);
    state = state.copyWith(tally: tally);

    PivotOutcome? outcome = state.outcome;
    if (outcome == null) {
      try {
        final double? close = await _prices.closeFor(day);
        if (close != null) {
          outcome = PivotOutcome(dayKey: day, strike: strike, close: close);
          await _store.saveOutcome(outcome);
        }
      } on Object catch (error) {
        state = state.copyWith(outcomeError: error.toString());
      }
    }

    if (vote == null) {
      state = state.copyWith(phase: PivotPhase.missed, outcome: outcome);
      return;
    }

    PivotAward? award = state.award;
    if (outcome != null && award == null) {
      award = await _pay(day, vote, outcome, tally);
    }

    state = state.copyWith(
      phase: outcome != null && _store.outcomeSeen(day)
          ? PivotPhase.resolved
          : PivotPhase.pollClosed,
      outcome: outcome,
      award: award,
      streak: _streakFor(day),
    );
  }

  /// Pays a resolved day exactly once: the award is stored before the points
  /// are added, so a crash between the two can under-pay, never double-pay.
  Future<PivotAward> _pay(
    String day,
    PivotVote vote,
    PivotOutcome outcome,
    PivotTally tally,
  ) async {
    final Set<String> resolved = <String>{..._store.resolvedDays, day};
    final PivotChoice? majority = tally.majority;
    final PivotAward award = PivotScoring.award(
      correct: outcome.winner == vote.choice,
      contrarian: majority != null && majority != vote.choice,
      streak: PivotScoring.streakEndingOn(day, resolved),
    );
    await _store.saveAward(day, award);
    await ref.read(progressProvider.notifier).awardPivotPoints(award.total);
    return award;
  }

  /// Seals today's call. One vote, and it cannot be changed.
  Future<void> vote(PivotChoice choice) async {
    final DateTime now = clock();
    final String day = PivotClock.dayKey(now);
    final double? strike = state.strike;
    if (state.vote != null ||
        strike == null ||
        day != state.dayKey ||
        PivotWindow.at(now) != PivotWindow.open) {
      return;
    }
    final PivotVote vote = PivotVote(
      dayKey: day,
      choice: choice,
      sealedAt: now,
      strike: strike,
    );
    await _store.saveVote(vote);
    await _backend.submitVote(vote);
    state = state.copyWith(
      phase: PivotPhase.locked,
      vote: vote,
      tally: await _backend.tally(day),
      pivotDay: _pivotDayFor(day),
    );
  }

  /// The live tape: latest price and the last ten hours of bars.
  Future<void> refreshLive() async {
    try {
      final Quote q = await _prices.live();
      state = state.copyWith(live: q);
    } on Object catch (error) {
      debugPrint('Pivot quote failed: $error');
    }
    try {
      final List<Candle> bars = await _prices.tape(clock());
      state = state.copyWith(tape: bars);
    } on Object catch (error) {
      debugPrint('Pivot tape failed: $error');
    }
  }

  /// From the crowd reveal to the outcome.
  Future<void> showOutcome() async {
    if (state.outcome == null) return;
    await _store.markOutcomeSeen(state.dayKey);
    state = state.copyWith(phase: PivotPhase.resolved);
  }

  /// Called by the screen's clock: reloads when the day or the window turns
  /// over (09:00 opens the question, 17:00 closes it).
  void sync() {
    final DateTime now = clock();
    final bool dayChanged = PivotClock.dayKey(now) != state.dayKey;
    final PivotPhase p = state.phase;
    final PivotWindow w = PivotWindow.at(now);
    final bool windowChanged =
        (p == PivotPhase.beforeOpen && w != PivotWindow.beforeOpen) ||
        ((p == PivotPhase.voting || p == PivotPhase.locked) &&
            w == PivotWindow.closed) ||
        (p == PivotPhase.pollClosed && state.outcome == null);
    if (dayChanged || windowChanged) unawaited(load());
  }
}
