import 'package:meta/meta.dart';

import 'candle_model.dart';
import 'script_event_model.dart';

/// Builds decision moments from a price series, mechanically.
///
/// Used by two callers that must never disagree:
///   • `tool/import_binance_level.dart`, authoring campaign scripts offline
///   • `endless_generator.dart`, generating a window at runtime
///
/// Keeping one implementation is the point. A campaign level and an Endless
/// window that scored the same crash differently would make the Discipline
/// Score meaningless across modes.
///
/// WHY A LADDER, NOT ONE DRAWDOWN — ENGINE.md §6 originally called for
/// flagging a window's single largest peak-to-trough drawdown. That yields
/// exactly one moment in a sustained decline (price never makes a new high,
/// so the whole fall is one episode), and beginner mode needs a set count of
/// moments, usually more than ten. So instead the series is asked again each
/// time it falls a further [step] below the last time it asked. A new high
/// resets the ladder, so a second leg down starts asking again.
abstract final class PauseLadder {
  /// Ignore noise above this — a 3% dip is not a test of nerve.
  static const double defaultMinFromPeak = 0.08;

  /// Below this many remaining candles, "what happened next" is too thin to
  /// assert, and the moment is marked ambiguous instead.
  static const int minLookahead = 20;

  /// One rung: an index into the series and the peak it is measured from.
  static List<LadderRung> build(
    List<Candle> candles,
    double step, {
    double minFromPeak = defaultMinFromPeak,
  }) {
    final List<LadderRung> out = <LadderRung>[];
    if (candles.length < 2) return out;

    double peak = candles.first.close;
    int peakIndex = 0;
    double? lastTrigger;

    for (int i = 1; i < candles.length; i++) {
      final double close = candles[i].close;
      if (close > peak) {
        peak = close;
        peakIndex = i;
        lastTrigger = null;
        continue;
      }

      final double fromPeak = 1 - close / peak;
      if (fromPeak < minFromPeak) continue;
      if (lastTrigger != null && close > lastTrigger * (1 - step)) continue;

      out.add(LadderRung(index: i, peakIndex: peakIndex, fromPeak: fromPeak));
      lastTrigger = close;
    }

    return out;
  }

  /// Picks the step size whose ladder lands closest to [target] moments.
  static (List<LadderRung>, double) forTarget(
    List<Candle> candles,
    int target, {
    double minFromPeak = defaultMinFromPeak,
  }) {
    List<LadderRung> best = build(candles, 0.10, minFromPeak: minFromPeak);
    double bestStep = 0.10;
    int bestDelta = (best.length - target).abs();

    for (double step = 0.03; step <= 0.30; step += 0.005) {
      final List<LadderRung> found =
          build(candles, step, minFromPeak: minFromPeak);
      final int delta = (found.length - target).abs();
      if (delta < bestDelta) {
        best = found;
        bestStep = step;
        bestDelta = delta;
      }
    }

    return (best, bestStep);
  }

  /// What the series did *after* a moment — the whole basis for
  /// `optimal_action`. Never a judgement about what a trader should have felt.
  ///
  ///   • rebounded 25%+ above here    -> buy_dip
  ///   • ended at or above here       -> hold
  ///   • fell a further 25%+          -> sell
  ///   • otherwise                    -> hold, flagged ambiguous
  static LadderVerdict verdictAt(List<Candle> candles, int index) {
    final double here = candles[index].close;
    final List<Candle> after = candles.sublist(index + 1);

    if (after.length < minLookahead) {
      return LadderVerdict(
        action: DecisionAction.hold,
        rationale: 'Only ${after.length} trading days remain in this window — '
            'too few to say what followed.',
        ambiguous: true,
      );
    }

    double futureMax = after.first.close;
    double futureMin = after.first.close;
    for (final Candle c in after) {
      if (c.close > futureMax) futureMax = c.close;
      if (c.close < futureMin) futureMin = c.close;
    }
    final double endClose = after.last.close;

    if (futureMax >= here * 1.25) {
      return LadderVerdict(
        action: DecisionAction.buyDip,
        rationale: 'Price rebounded '
            '${((futureMax / here - 1) * 100).toStringAsFixed(0)}% above this '
            'level later in the window.',
        ambiguous: false,
      );
    }
    if (endClose >= here) {
      return LadderVerdict(
        action: DecisionAction.hold,
        rationale: 'Price ended the window '
            '${((endClose / here - 1) * 100).toStringAsFixed(0)}% above this '
            'level.',
        ambiguous: false,
      );
    }
    if (futureMin <= here * 0.75) {
      return LadderVerdict(
        action: DecisionAction.sell,
        rationale: 'Price fell a further '
            '${((1 - futureMin / here) * 100).toStringAsFixed(0)}% below this '
            'level before the window ended.',
        ambiguous: false,
      );
    }
    return LadderVerdict(
      action: DecisionAction.hold,
      rationale: 'Price drifted to '
          '${((endClose / here - 1) * 100).toStringAsFixed(0)}% from this '
          'level without a clear recovery or a further collapse.',
      ambiguous: true,
    );
  }

  /// Turns a series into ready-to-play pause points.
  static List<PausePoint> pausePointsFor(
    List<Candle> candles, {
    int target = 12,
  }) {
    final (List<LadderRung> rungs, _) = forTarget(candles, target);

    return <PausePoint>[
      for (final LadderRung rung in rungs)
        PausePoint(
          triggerIndex: rung.index,
          flashTreatment: rung.fromPeak >= 0.20
              ? FlashTreatment.redFlashHard
              : FlashTreatment.amberFlashSoft,
          optimalAction: verdictAt(candles, rung.index).action,
          revealHeadline: _headline(candles, rung),
        ),
    ];
  }

  static String _headline(List<Candle> candles, LadderRung rung) {
    final LadderVerdict v = verdictAt(candles, rung.index);
    final Candle here = candles[rung.index];
    final Candle peak = candles[rung.peakIndex];
    final String pct = (rung.fromPeak * 100).toStringAsFixed(0);

    return 'Down $pct% from the high of '
        '${peak.close.toStringAsFixed(2)}, trading at '
        '${here.close.toStringAsFixed(2)}. ${v.rationale}'
        '${v.ambiguous ? ' The data does not support a clean "right" answer '
            'here.' : ''}';
  }
}

@immutable
class LadderRung {
  const LadderRung({
    required this.index,
    required this.peakIndex,
    required this.fromPeak,
  });

  final int index;
  final int peakIndex;

  /// Fraction below the running peak, e.g. 0.42 for −42%.
  final double fromPeak;
}

@immutable
class LadderVerdict {
  const LadderVerdict({
    required this.action,
    required this.rationale,
    required this.ambiguous,
  });

  final DecisionAction action;
  final String rationale;

  /// True when the series does not clearly support any single answer. The
  /// reveal says so rather than pretending otherwise.
  final bool ambiguous;
}
