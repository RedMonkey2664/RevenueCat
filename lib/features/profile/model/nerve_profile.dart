import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/services/run_history_service.dart';

/// The five traits on the profile's radar, in the order the share card draws
/// them clockwise from the top.
enum NerveTrait {
  panic('PANIC', 'PANIC THRESHOLD'),
  speed('SPEED', 'DECISION SPEED'),
  learning('LEARN', 'LEARNING'),
  dipBuying('DIP BUY', 'DIP BUYING'),
  sensitivity('SENS', 'CRASH SPEED SENSITIVITY');

  const NerveTrait(this.short, this.long);

  final String short;
  final String long;
}

/// Who the numbers say you are. Rules are in [NerveProfile._archetypeFor].
enum NerveArchetype {
  dipHunter(
    'THE DIP HUNTER',
    'A falling market reads to you as a sale. You add while the tape is '
        'still dropping — the discipline you are building is telling a dip '
        'from a trend.',
  ),
  ironHand(
    'THE IRON HAND',
    'You almost never sell into a fall. Drawdowns that would shake a '
        'position loose pass straight through you.',
  ),
  deepHolder(
    'THE DEEP HOLDER',
    'You hold deep into a crash before breaking. Slow declines don\'t faze '
        'you, but sudden drops test your nerve.',
  ),
  lateBreaker(
    'THE DEEP HOLDER',
    'You hold deep into a crash before breaking. When you do sell, it is '
        'late in the fall — often close to the low.',
  ),
  earlyExit(
    'THE EARLY EXIT',
    'You get out at the first real crack. It feels safe, and it tends to '
        'lock in the loss before the rebound arrives.',
  ),
  measuredHand(
    'THE MEASURED HAND',
    'You sell some falls and sit through others. Your breaking point sits '
        'in the middle of the drop.',
  );

  const NerveArchetype(this.title, this.description);

  final String title;
  final String description;
}

/// A behavioural read of the player, computed from their own runs.
///
/// Every figure is derived from [RunRecord]s — measured drawdowns, measured
/// decision times, the Discipline credit each moment earned. There is no
/// comparison with other players anywhere in here, because the app has no
/// data about other players to compare with; copy built on this profile must
/// not imply otherwise.
@immutable
class NerveProfile {
  const NerveProfile._({
    required this.levelsPlayed,
    required this.runsScored,
    required this.decisions,
    required this.overall,
    required this.startingOverall,
    required this.panicThreshold,
    required this.earlyPanicThreshold,
    required this.panicRate,
    required this.fastPanicRate,
    required this.slowPanicRate,
    required this.medianSeconds,
    required this.dipRate,
    required this.learningDelta,
    required this.archetype,
    required this.radar,
  });

  factory NerveProfile.from(List<RunRecord> runs) {
    final List<RunRecord> scored = runs
        .where((RunRecord r) => r.score != null)
        .toList();
    final List<DecisionSample> samples = <DecisionSample>[
      for (final RunRecord r in runs) ...r.samples,
    ];

    final int? overall = _mean(scored.map((RunRecord r) => r.score!));
    final int? starting = scored.length >= 4
        ? _mean(scored.take(3).map((RunRecord r) => r.score!))
        : null;

    final double? threshold = _panicThreshold(runs);
    final double? earlyThreshold = runs.length > 3
        ? _panicThreshold(runs.take(3).toList())
        : null;

    final double panicRate = samples.isEmpty
        ? 0
        : samples.where((DecisionSample s) => s.isSell).length / samples.length;

    // Fast vs slow falls, split at 1.5% a day. A crash that loses 20% in a
    // week and a grind that loses 20% in two months are different tests.
    const double fastCut = 0.015;
    final List<DecisionSample> fast = samples
        .where((DecisionSample s) => s.crashSpeed >= fastCut)
        .toList();
    final List<DecisionSample> slow = samples
        .where((DecisionSample s) => s.crashSpeed < fastCut)
        .toList();
    double? rate(List<DecisionSample> xs) => xs.isEmpty
        ? null
        : xs.where((DecisionSample s) => s.isSell).length / xs.length;

    final List<double> seconds = <double>[
      for (final DecisionSample s in samples)
        if (s.seconds != null) s.seconds!,
    ]..sort();
    final double? median = seconds.isEmpty
        ? null
        : seconds[seconds.length ~/ 2];

    final double dipRate = samples.isEmpty
        ? 0
        : samples.where((DecisionSample s) => s.isBuy).length / samples.length;

    final double? learning = scored.length >= 4
        ? (_mean(
                    scored
                        .skip(scored.length - 3)
                        .map((RunRecord r) => r.score!),
                  )! -
                  _mean(scored.take(3).map((RunRecord r) => r.score!))!)
              .toDouble()
        : null;

    final double? fastRate = rate(fast);
    final double? slowRate = rate(slow);

    final Map<NerveTrait, double> radar = <NerveTrait, double>{
      NerveTrait.panic: samples.isEmpty
          ? 0.5
          : 0.5 * (1 - panicRate) +
                0.5 *
                    (threshold == null ? 1 : (threshold / 0.5).clamp(0.0, 1.0)),
      NerveTrait.speed: median == null
          ? 0.5
          : (1 - (median - 2) / 28).clamp(0.05, 1.0),
      NerveTrait.learning: learning == null
          ? 0.5
          : (0.5 + learning / 40).clamp(0.05, 1.0),
      NerveTrait.dipBuying: (dipRate / 0.6).clamp(0.05, 1.0),
      NerveTrait.sensitivity: fastRate == null || slowRate == null
          ? 0.5
          : (1 - (fastRate - slowRate).clamp(0.0, 1.0)).clamp(0.05, 1.0),
    };

    return NerveProfile._(
      levelsPlayed: runs.map((RunRecord r) => r.levelId).toSet().length,
      runsScored: scored.length,
      decisions: samples.length,
      overall: overall,
      startingOverall: starting,
      panicThreshold: threshold,
      earlyPanicThreshold: earlyThreshold,
      panicRate: panicRate,
      fastPanicRate: fastRate,
      slowPanicRate: slowRate,
      medianSeconds: median,
      dipRate: dipRate,
      learningDelta: learning,
      archetype: _archetypeFor(
        panicRate: panicRate,
        dipRate: dipRate,
        threshold: threshold,
        fastRate: fastRate,
        slowRate: slowRate,
      ),
      radar: radar,
    );
  }

  /// Distinct levels behind the profile before it says anything about you.
  /// Fewer than this and one bad run would define the whole read.
  static const int unlockLevels = 5;

  final int levelsPlayed;
  final int runsScored;
  final int decisions;

  /// Mean Discipline Score across scored runs.
  final int? overall;

  /// Mean of the first three scored runs, once there is a fourth to compare.
  final int? startingOverall;

  /// Mean drawdown at the first sell, across runs that had one. Null when
  /// the player has never sold into a fall.
  final double? panicThreshold;

  /// The same, over the first three runs only.
  final double? earlyPanicThreshold;

  /// Share of tested moments that were a sell.
  final double panicRate;

  final double? fastPanicRate;
  final double? slowPanicRate;

  /// Median seconds on the halted tape.
  final double? medianSeconds;

  /// Share of tested moments that were a buy.
  final double dipRate;

  /// Last three scored runs minus the first three, in score points.
  final double? learningDelta;

  final NerveArchetype archetype;

  /// Each trait scaled 0..1 for the radar. Higher is steadier.
  final Map<NerveTrait, double> radar;

  bool get isUnlocked => levelsPlayed >= unlockLevels;

  int get levelsToUnlock => math.max(0, unlockLevels - levelsPlayed);

  /// The trait that moved most with the latest run, for the "Updated after…"
  /// banner. Null when there is no earlier profile or nothing really moved.
  static NerveTrait? shiftedBy(List<RunRecord> runs) {
    if (runs.length < 2) return null;
    final NerveProfile before = NerveProfile.from(
      runs.sublist(0, runs.length - 1),
    );
    final NerveProfile after = NerveProfile.from(runs);
    NerveTrait? best;
    double delta = 0.03;
    for (final NerveTrait t in NerveTrait.values) {
      final double d = (after.radar[t]! - before.radar[t]!).abs();
      if (d > delta) {
        delta = d;
        best = t;
      }
    }
    return best;
  }

  static int? _mean(Iterable<int> xs) {
    if (xs.isEmpty) return null;
    return (xs.reduce((int a, int b) => a + b) / xs.length).round();
  }

  static double? _panicThreshold(List<RunRecord> runs) {
    final List<double> firsts = <double>[
      for (final RunRecord r in runs)
        for (final DecisionSample s
            in r.samples.where((DecisionSample s) => s.isSell).take(1))
          s.drawdown,
    ];
    if (firsts.isEmpty) return null;
    return firsts.reduce((double a, double b) => a + b) / firsts.length;
  }

  static NerveArchetype _archetypeFor({
    required double panicRate,
    required double dipRate,
    required double? threshold,
    required double? fastRate,
    required double? slowRate,
  }) {
    if (panicRate <= 0.1 && dipRate >= 0.4) return NerveArchetype.dipHunter;
    if (panicRate <= 0.1) return NerveArchetype.ironHand;
    if (threshold != null && threshold >= 0.22) {
      final bool speedSensitive =
          fastRate != null && slowRate != null && fastRate - slowRate > 0.15;
      return speedSensitive
          ? NerveArchetype.deepHolder
          : NerveArchetype.lateBreaker;
    }
    if (threshold != null && threshold < 0.12) return NerveArchetype.earlyExit;
    return NerveArchetype.measuredHand;
  }
}
