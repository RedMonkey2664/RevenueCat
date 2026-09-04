import 'package:flutter/foundation.dart';

import 'drawdown_detector.dart';
import 'script_event_model.dart';
import 'simulation_mode.dart';

/// Credit awarded for one graded moment, 0..1.
abstract final class _Credit {
  /// The player did exactly what the data supports.
  static const double exact = 1;

  /// Hold vs Buy-the-Dip mix-up. ENGINE.md §4: both are non-panic responses,
  /// so they sit closer to each other than either does to selling.
  static const double nonPanicMismatch = 0.6;

  /// Stayed in (or added) when the defensible move was to get out. A missed
  /// exit, but not the panic the app exists to discourage.
  static const double missedExit = 0.3;

  /// Sold into the fall. The behaviour the whole product is built around
  /// discouraging.
  static const double panic = 0;
}

/// One graded moment, shown as a row in the Debrief breakdown.
@immutable
class ScoredMoment {
  const ScoredMoment({
    required this.label,
    required this.detail,
    required this.credit,
    this.soldIntoDecline = false,
    this.candleIndex,
  });

  /// Short title, e.g. "Day 49" or "Drawdown 1".
  final String label;

  /// Plain-language description of what the player did and how it scored.
  final String detail;

  /// 0..1.
  final double credit;

  /// Whether the player reduced exposure while price was falling.
  ///
  /// Kept separate from [credit] because advanced mode's penalty is
  /// proportional: trimming 20% scores 80, which is not full credit but is
  /// still a sell into a fall.
  final bool soldIntoDecline;

  final int? candleIndex;

  bool get isFullCredit => credit >= _Credit.exact;

  bool get isPanic => soldIntoDecline;
}

/// A run's Discipline Score.
///
/// Normalised to 0-100 and shown at Debrief next to the simulated P&L
/// (ENGINE.md §4) — the score is behavioural, the P&L is the consequence.
@immutable
class DisciplineScore {
  const DisciplineScore({
    required this.score,
    required this.moments,
    required this.mode,
  });

  /// 0-100. Null when the run contained nothing to grade — an honest "not
  /// tested" beats awarding a perfect score for an untested run.
  final int? score;

  final List<ScoredMoment> moments;
  final SimulationMode mode;

  int get momentsTested => moments.length;

  bool get wasTested => moments.isNotEmpty;

  int get panicCount => moments.where((ScoredMoment m) => m.isPanic).length;

  static DisciplineScore _from(
    List<ScoredMoment> moments,
    SimulationMode mode,
  ) {
    if (moments.isEmpty) {
      return DisciplineScore(score: null, moments: moments, mode: mode);
    }
    final double total =
        moments.fold<double>(0, (double a, ScoredMoment m) => a + m.credit);
    return DisciplineScore(
      score: (total / moments.length * 100).round(),
      moments: List<ScoredMoment>.unmodifiable(moments),
      mode: mode,
    );
  }

  /// Beginner mode: compare each decision to the pause point's
  /// `optimal_action`, per ENGINE.md §4.
  factory DisciplineScore.forBeginner(List<RecordedDecision> decisions) {
    final List<ScoredMoment> moments = <ScoredMoment>[];

    for (final RecordedDecision d in decisions) {
      final DecisionAction chose = d.chosen;
      final DecisionAction best = d.pausePoint.optimalAction;

      final double credit;
      final String detail;
      bool soldIntoDecline = false;
      if (chose == best) {
        credit = _Credit.exact;
        detail = 'You chose ${chose.label}, which is what the data supports.';
      } else if (!chose.isPanicResponse && !best.isPanicResponse) {
        credit = _Credit.nonPanicMismatch;
        detail =
            'You chose ${chose.label} where ${best.label} read better — but '
            'you did not panic, and that is most of the battle.';
      } else if (chose.isPanicResponse) {
        credit = _Credit.panic;
        detail =
            'You sold into the fall. ${best.label} was the defensible move '
            'here.';
        soldIntoDecline = true;
      } else {
        credit = _Credit.missedExit;
        detail =
            'You chose ${chose.label} where selling was defensible. A missed '
            'exit, not a panic.';
      }

      moments.add(
        ScoredMoment(
          label: 'Day ${d.pausePoint.triggerIndex + 1}',
          detail: detail,
          credit: credit,
          soldIntoDecline: soldIntoDecline,
          candleIndex: d.pausePoint.triggerIndex,
        ),
      );
    }

    return _from(moments, SimulationMode.beginner);
  }

  /// Advanced mode: free trading has no scripted `optimal_action`, so grading
  /// it against one would mean inventing history — which CLAUDE.md forbids.
  ///
  /// Instead the score asks the *same* behavioural question at moments the
  /// price series identifies for itself (see [DrawdownDetector]): during each
  /// significant peak-to-trough decline, did the player cut exposure?
  ///
  /// - Reduced exposure while it fell  → credit falls in proportion to the
  ///   share of the position cut, so a 25% trim and a full liquidation are
  ///   not treated as the same mistake
  /// - Held through it                 → full credit
  /// - Increased exposure              → full credit (non-panic, per §4)
  ///
  /// An episode the player entered already in cash is skipped rather than
  /// graded: it never tested their nerve either way.
  ///
  /// Trades outside a drawdown are not graded. Buying and selling in a rising
  /// market is trading preference, not discipline, and the app has no basis
  /// for calling it right or wrong.
  factory DisciplineScore.forAdvanced({
    required List<Trade> trades,
    required List<DrawdownEpisode> episodes,
    required double startingUnits,
  }) {
    final List<ScoredMoment> moments = <ScoredMoment>[];

    for (final DrawdownEpisode e in episodes) {
      // Position held when the decline began, reconstructed from the trade
      // log. Selling is only meaningful relative to what there was to sell.
      double unitsAtPeak = startingUnits;
      for (final Trade t in trades) {
        if (t.candleIndex < e.peakIndex) unitsAtPeak += t.unitsDelta;
      }

      // Already in cash before the fall started: this episode never tested
      // the player's nerve, so grading it either way would be noise.
      if (unitsAtPeak <= 1e-9) continue;

      double sold = 0;
      double bought = 0;
      for (final Trade t in trades) {
        if (t.candleIndex >= e.peakIndex && t.candleIndex <= e.troughIndex) {
          if (t.unitsDelta < 0) {
            sold += -t.unitsDelta;
          } else {
            bought += t.unitsDelta;
          }
        }
      }

      final double netUnits = bought - sold;
      final String depth = '${e.depthPercent.toStringAsFixed(0)}%';
      final String window = 'Day ${e.peakIndex + 1}–${e.troughIndex + 1}';

      final double credit;
      final String detail;
      bool soldIntoDecline = false;
      if (netUnits < -1e-9) {
        soldIntoDecline = true;
        // Proportional, not all-or-nothing: trimming a quarter is not the
        // same mistake as liquidating, and a score that cannot tell them
        // apart teaches nothing.
        final double cutShare = (sold - bought) / unitsAtPeak;
        credit = (1 - cutShare).clamp(0.0, 1.0);
        detail = 'Price fell $depth and you cut '
            '${(cutShare * 100).round()}% of your position while it was '
            'falling.';
      } else if (netUnits > 1e-9) {
        credit = _Credit.exact;
        detail = 'Price fell $depth and you added to your position.';
      } else {
        credit = _Credit.exact;
        detail = 'Price fell $depth and you held your position.';
      }

      moments.add(
        ScoredMoment(
          label: '$window · −$depth',
          detail: detail,
          credit: credit,
          soldIntoDecline: soldIntoDecline,
          candleIndex: e.troughIndex,
        ),
      );
    }

    return _from(moments, SimulationMode.advanced);
  }
}
