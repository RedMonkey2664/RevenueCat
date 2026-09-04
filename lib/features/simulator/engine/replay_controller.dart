import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'candle_model.dart';
import 'discipline_score.dart';
import 'drawdown_detector.dart';
import 'level_model.dart';
import 'portfolio.dart';
import 'script_event_model.dart';
import 'simulation_mode.dart';

/// Milliseconds spent on one candle at 1x.
///
/// TODO(tuning): ENGINE.md §1 says to tune this by feel on a real device, not
/// by guessing. 90ms is a starting point only — ~11 candles/sec, so a 6-month
/// daily window plays out in roughly 11 seconds, which reads as fast-forward
/// rather than a crawl. Re-tune on hardware before Phase 3.
const int kBaseMillisPerCandle = 90;

/// The three real playback speeds (DESIGN.md). 0.5x and 8x exist on screen as
/// locked/dummy chrome only.
enum ReplaySpeed {
  x1('1x', 1),
  x2('2x', 2),
  x4('4x', 4);

  const ReplaySpeed(this.label, this.multiplier);

  final String label;
  final int multiplier;

  Duration get tickInterval =>
      Duration(milliseconds: (kBaseMillisPerCandle / multiplier).round());
}

enum ReplayStatus {
  /// Loaded, not yet started.
  idle,
  playing,

  /// Paused by the player (or by leaving the screen), resumable at will.
  paused,

  /// Halted on a pause point. Playback cannot resume until a decision is
  /// recorded — this is a guided sequence, not a free-scrub sandbox.
  awaitingDecision,
  finished,
}

@immutable
class ReplayState {
  const ReplayState({
    required this.level,
    required this.currentIndex,
    required this.status,
    required this.speed,
    required this.portfolio,
    required this.decisions,
    required this.resolvedPauseIndices,
    required this.isRevealed,
    required this.mode,
    required this.trades,
    this.activePausePoint,
  });

  factory ReplayState.initial(SimulationLevel level, SimulationMode mode) {
    return ReplayState(
      level: level,
      mode: mode,
      trades: const <Trade>[],
      currentIndex: 0,
      status: ReplayStatus.idle,
      speed: ReplaySpeed.x1,
      portfolio: Portfolio.opening(
        startingBalance: level.startingBalance,
        entryPrice: level.candles.first.close,
      ),
      decisions: const <RecordedDecision>[],
      resolvedPauseIndices: const <int>{},
      isRevealed: false,
    );
  }

  final SimulationLevel level;
  final int currentIndex;
  final ReplayStatus status;
  final ReplaySpeed speed;
  final Portfolio portfolio;
  final List<RecordedDecision> decisions;
  final Set<int> resolvedPauseIndices;

  final SimulationMode mode;

  /// Advanced mode's trade log, in execution order.
  final List<Trade> trades;

  /// Blind mode is strict: asset name and real dates stay hidden until the
  /// Debrief flips this (ENGINE.md §3).
  final bool isRevealed;

  final PausePoint? activePausePoint;

  Candle get currentCandle => level.candles[currentIndex];

  /// 1-based, for the "Day 14 of 126" counter that replaces the real date.
  int get dayNumber => currentIndex + 1;

  int get totalDays => level.length;

  double get portfolioValue => portfolio.valueAt(currentCandle.close);

  double get pnl => portfolio.pnlAt(currentCandle.close);

  double get pnlPercent => portfolio.pnlPercentAt(currentCandle.close);

  bool get isAwaitingDecision => status == ReplayStatus.awaitingDecision;

  bool get isFinished => status == ReplayStatus.finished;

  /// Advanced mode grades free trading against the drawdowns the price series
  /// identifies for itself, so the whole level is scoreable, not just the
  /// part played so far.
  List<DrawdownEpisode> get drawdownEpisodes =>
      DrawdownDetector.detect(level.candles);

  DisciplineScore get disciplineScore => mode.isBeginner
      ? DisciplineScore.forBeginner(decisions)
      : DisciplineScore.forAdvanced(
          trades: trades,
          episodes: drawdownEpisodes,
          startingUnits: Portfolio.opening(
            startingBalance: level.startingBalance,
            entryPrice: level.candles.first.close,
          ).units,
        );

  /// Share of portfolio value currently in the asset (advanced mode HUD).
  double get exposure => portfolio.exposureAt(currentCandle.close);

  /// How many graded moments this run holds in total, so the level screen can
  /// show "3 of 12" without knowing which mode it is in.
  int get totalMoments =>
      mode.isBeginner ? level.pausePoints.length : drawdownEpisodes.length;

  int get momentsResolved =>
      mode.isBeginner ? decisions.length : drawdownEpisodes.length;

  /// Candles revealed so far. The chart must never draw the future.
  List<Candle> get visibleCandles => level.candles.sublist(0, currentIndex + 1);

  ReplayState copyWith({
    int? currentIndex,
    ReplayStatus? status,
    ReplaySpeed? speed,
    Portfolio? portfolio,
    List<RecordedDecision>? decisions,
    Set<int>? resolvedPauseIndices,
    bool? isRevealed,
    List<Trade>? trades,
    PausePoint? activePausePoint,
    bool clearActivePausePoint = false,
  }) {
    return ReplayState(
      level: level,
      currentIndex: currentIndex ?? this.currentIndex,
      status: status ?? this.status,
      speed: speed ?? this.speed,
      portfolio: portfolio ?? this.portfolio,
      decisions: decisions ?? this.decisions,
      resolvedPauseIndices: resolvedPauseIndices ?? this.resolvedPauseIndices,
      isRevealed: isRevealed ?? this.isRevealed,
      mode: mode,
      trades: trades ?? this.trades,
      activePausePoint: clearActivePausePoint
          ? null
          : (activePausePoint ?? this.activePausePoint),
    );
  }
}

/// Set by a [ProviderScope] override at the level screen, so the engine has no
/// idea whether it is running a campaign level or an Endless window.
final Provider<SimulationLevel> currentLevelProvider = Provider<SimulationLevel>(
  (Ref ref) => throw UnimplementedError(
    'currentLevelProvider must be overridden with the level being played',
  ),
  // Marks this as a scoped provider: it is only ever read through a
  // ProviderScope override, never from the root container.
  dependencies: const [],
);

/// The mode the current run is being played in. Scoped alongside the level,
/// because mode is a property of the run, not of the level data.
final Provider<SimulationMode> currentModeProvider = Provider<SimulationMode>(
  (Ref ref) => throw UnimplementedError(
    'currentModeProvider must be overridden with the run mode',
  ),
  dependencies: const [],
);

final NotifierProvider<ReplayController, ReplayState> replayControllerProvider =
    NotifierProvider<ReplayController, ReplayState>(
  ReplayController.new,
  isAutoDispose: true,
  // Required, not decorative: without declaring the dependency, Riverpod
  // initialises this controller in the ROOT container, where
  // currentLevelProvider has no override, and the level screen throws on
  // open. Declaring it makes the controller re-scope to whichever
  // ProviderScope supplies the level.
  dependencies: [currentLevelProvider, currentModeProvider],
);

/// Drives playback through a level's candles and halts on pause points.
///
/// Deliberately knows nothing level-specific: every level, campaign or
/// endless, is just data handed to it (ENGINE.md).
class ReplayController extends Notifier<ReplayState> {
  Timer? _timer;

  @override
  ReplayState build() {
    final SimulationLevel level = ref.watch(currentLevelProvider);
    final SimulationMode mode = ref.watch(currentModeProvider);
    ref.onDispose(_cancelTimer);
    return ReplayState.initial(level, mode);
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void play() {
    if (state.isFinished || state.isAwaitingDecision) return;

    // A pause point on the very first candle would otherwise be stepped over.
    if (_haltIfPausePointAt(state.currentIndex)) return;

    state = state.copyWith(status: ReplayStatus.playing);
    _restartTimer();
  }

  void pause() {
    if (state.status != ReplayStatus.playing) return;
    _cancelTimer();
    state = state.copyWith(status: ReplayStatus.paused);
  }

  void setSpeed(ReplaySpeed speed) {
    state = state.copyWith(speed: speed);
    if (state.status == ReplayStatus.playing) _restartTimer();
  }

  /// Review-only scrubbing (Debrief). Not reachable during a timed run.
  void scrubTo(int index) {
    _cancelTimer();
    final int clamped = index.clamp(0, state.level.length - 1);
    state = state.copyWith(
      currentIndex: clamped,
      status: ReplayStatus.paused,
      clearActivePausePoint: true,
    );
  }

  /// Records the player's move at the active pause point, then resumes.
  ///
  /// Deciding does not end the level — a level can test discipline more than
  /// once (ENGINE.md §2).
  void submitDecision(DecisionAction action) {
    final PausePoint? pausePoint = state.activePausePoint;
    if (pausePoint == null) return;

    final double price = state.currentCandle.close;
    final Portfolio updated = state.portfolio.apply(action, price);

    state = state.copyWith(
      portfolio: updated,
      decisions: <RecordedDecision>[
        ...state.decisions,
        RecordedDecision(
          pausePoint: pausePoint,
          chosen: action,
          portfolioValueAtDecision: updated.valueAt(price),
        ),
      ],
      resolvedPauseIndices: <int>{
        ...state.resolvedPauseIndices,
        pausePoint.triggerIndex,
      },
      clearActivePausePoint: true,
      status: ReplayStatus.paused,
    );

    play();
  }

  /// Advanced mode: buy with [fractionOfCash] of remaining cash at the
  /// current candle's close.
  ///
  /// Deliberately does not pause playback — "at any moment, no restrictions"
  /// means the market keeps moving while you act.
  void buy(double fractionOfCash) =>
      _trade(isBuy: true, fraction: fractionOfCash);

  /// Advanced mode: sell [fractionOfUnits] of the held position.
  void sell(double fractionOfUnits) =>
      _trade(isBuy: false, fraction: fractionOfUnits);

  void _trade({required bool isBuy, required double fraction}) {
    if (state.mode.isBeginner || state.isFinished) return;

    final double price = state.currentCandle.close;
    final Portfolio before = state.portfolio;
    final Portfolio after = isBuy
        ? before.buyFraction(fraction, price)
        : before.sellFraction(fraction, price);

    final double unitsDelta = after.units - before.units;
    // Nothing to buy with, or nothing left to sell: leave no phantom trade in
    // the log, or the Debrief would grade a trade that never happened.
    if (unitsDelta.abs() < 1e-12) return;

    state = state.copyWith(
      portfolio: after,
      trades: <Trade>[
        ...state.trades,
        Trade(
          candleIndex: state.currentIndex,
          isBuy: isBuy,
          fraction: fraction,
          price: price,
          unitsDelta: unitsDelta,
        ),
      ],
    );
  }

  /// Flips blind mode off. Only the Debrief may call this.
  void reveal() {
    state = state.copyWith(isRevealed: true);
  }

  void _restartTimer() {
    _cancelTimer();
    _timer = Timer.periodic(state.speed.tickInterval, (_) => _tick());
  }

  void _tick() {
    final int next = state.currentIndex + 1;

    if (next >= state.level.length) {
      _cancelTimer();
      state = state.copyWith(
        currentIndex: state.level.length - 1,
        status: ReplayStatus.finished,
      );
      return;
    }

    state = state.copyWith(currentIndex: next);
    _haltIfPausePointAt(next);
  }

  /// Halts playback if [index] carries an unresolved pause point.
  /// Returns whether it halted.
  bool _haltIfPausePointAt(int index) {
    // Advanced mode never halts: the player trades continuously and the
    // scripted pause points are simply not used.
    if (state.mode.isAdvanced) return false;
    if (state.resolvedPauseIndices.contains(index)) return false;
    final PausePoint? pausePoint = state.level.pausePointAt(index);
    if (pausePoint == null) return false;

    _cancelTimer();
    state = state.copyWith(
      status: ReplayStatus.awaitingDecision,
      activePausePoint: pausePoint,
    );
    return true;
  }
}
