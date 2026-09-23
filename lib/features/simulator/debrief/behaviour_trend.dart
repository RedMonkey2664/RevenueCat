import 'package:flutter/foundation.dart';

import '../../../core/services/run_history_service.dart';
import '../engine/discipline_score.dart';
import '../engine/replay_controller.dart';
import '../engine/script_event_model.dart';

/// What this run did, next to what the runs before it did.
///
/// The Debrief could only ever describe the run just finished, so the one
/// question a behavioural simulator exists to answer — *am I changing?* — had
/// no answer anywhere the player would see it while the run was still fresh.
///
/// Every number here is counted from stored runs ([RunHistoryService]) and
/// from this run's own decisions. Nothing is inferred about the player, and
/// with too little history the trend says so rather than inventing one.
@immutable
class BehaviourTrend {
  const BehaviourTrend({
    required this.priorRuns,
    required this.priorTests,
    required this.priorSells,
    required this.runTests,
    required this.runSells,
    required this.typicalSellDepth,
  });

  /// Runs recorded before this one that tested the player at all.
  final int priorRuns;

  /// Moments across those runs where price was falling under them.
  final int priorTests;

  /// How many of those they sold into.
  final int priorSells;

  final int runTests;
  final int runSells;

  /// Mean fall from the peak, 0..1, at the moments they sold in earlier runs.
  /// Null when they have not sold into a fall before.
  final double? typicalSellDepth;

  /// True once there is enough history to say anything at all. Two prior runs
  /// is the floor: one run is an anecdote, and a "trend" drawn from it would
  /// be the fake personalisation this is meant to avoid.
  bool get hasHistory => priorRuns >= 2 && priorTests > 0;

  double get priorSellRate => priorTests == 0 ? 0 : priorSells / priorTests;

  double get runSellRate => runTests == 0 ? 0 : runSells / runTests;

  /// The headline, or null when this run tested nothing.
  String? get line {
    if (runTests == 0) return null;
    final String thisRun =
        'In this run you sold into $runSells of $runTests '
        '${runTests == 1 ? 'fall' : 'falls'}.';
    if (!hasHistory) {
      return '$thisRun Play a few more and this panel will compare your runs '
          'with each other.';
    }
    final String before =
        'Across your previous $priorRuns runs you sold into $priorSells of '
        '$priorTests falls (${_pct(priorSellRate)}).';
    return '$before $thisRun';
  }

  /// One neutral sentence naming the direction of change, or null when there
  /// is nothing dependable to compare.
  String? get change {
    if (!hasHistory || runTests == 0) return null;
    final double delta = runSellRate - priorSellRate;
    // A single decision on a short run swings the rate a long way, so small
    // moves are reported as "in line" rather than dressed up as progress.
    if (delta.abs() < 0.15) {
      return 'That is in line with how you have played before '
          '(${_pct(runSellRate)} this run).';
    }
    return delta < 0
        ? 'That is lower than before (${_pct(runSellRate)} this run).'
        : 'That is higher than before (${_pct(runSellRate)} this run).';
  }

  /// Where their selling tends to happen, when the history shows a pattern.
  String? get depthNote {
    if (!hasHistory || typicalSellDepth == null || priorSells < 2) return null;
    return 'Your earlier sells came after an average fall of '
        '${(typicalSellDepth! * 100).round()}% from the peak.';
  }

  static String _pct(double v) => '${(v * 100).round()}%';

  /// Counts this run from its own decisions, and the ones before it from the
  /// stored samples.
  ///
  /// [priorHistory] must be the history as it stood *before* this run was
  /// recorded, or the run would be compared with itself.
  factory BehaviourTrend.from({
    required List<RunRecord> priorHistory,
    required ReplayState state,
  }) {
    // This run, counted the same way: a sell is a sell whether or not the
    // moment could be graded, because the panel reports behaviour, not score.
    final int runTests;
    final int runSells;
    if (state.mode.isBeginner) {
      runTests = state.decisions.length;
      runSells = state.decisions
          .where((RecordedDecision d) => d.chosen.isPanicResponse)
          .length;
    } else {
      final List<ScoredMoment> moments = state.disciplineScore.moments;
      runTests = moments.length;
      runSells = moments.where((ScoredMoment m) => m.isPanic).length;
    }

    return BehaviourTrend.compare(
      priorHistory: priorHistory,
      runTests: runTests,
      runSells: runSells,
    );
  }

  /// The same comparison with this run already counted, so the aggregation
  /// can be exercised without standing up a whole replay.
  factory BehaviourTrend.compare({
    required List<RunRecord> priorHistory,
    required int runTests,
    required int runSells,
  }) {
    int priorTests = 0;
    int priorSells = 0;
    int runsThatTested = 0;
    double sellDepthTotal = 0;
    int sellDepthCount = 0;

    for (final RunRecord r in priorHistory) {
      if (r.samples.isEmpty) continue;
      runsThatTested++;
      priorTests += r.samples.length;
      for (final DecisionSample s in r.samples) {
        if (!s.isSell) continue;
        priorSells++;
        sellDepthTotal += s.drawdown;
        sellDepthCount++;
      }
    }

    return BehaviourTrend(
      priorRuns: runsThatTested,
      priorTests: priorTests,
      priorSells: priorSells,
      runTests: runTests,
      runSells: runSells,
      typicalSellDepth:
          sellDepthCount == 0 ? null : sellDepthTotal / sellDepthCount,
    );
  }
}
