import 'package:flutter_test/flutter_test.dart';
import 'package:histox/core/services/run_history_service.dart';
import 'package:histox/features/profile/model/nerve_profile.dart';

DecisionSample _s(
  String action,
  double dd, {
  double speed = 0.005,
  double? sec,
}) => DecisionSample(
  action: action,
  drawdown: dd,
  crashSpeed: speed,
  credit: action == 'sell' ? 0 : 1,
  seconds: sec,
);

RunRecord _run(String id, int? score, List<DecisionSample> samples) =>
    RunRecord(
      levelId: id,
      title: id,
      mode: 'beginner',
      score: score,
      playedAt: DateTime.utc(2026, 9, 1),
      samples: samples,
    );

void main() {
  test('stays in the building state until five distinct levels', () {
    final NerveProfile p = NerveProfile.from(<RunRecord>[
      _run('a', 60, <DecisionSample>[_s('hold', 0.2)]),
      _run('a', 70, <DecisionSample>[_s('hold', 0.2)]),
      _run('b', 70, <DecisionSample>[_s('hold', 0.2)]),
    ]);
    expect(p.levelsPlayed, 2, reason: 'replays of one level count once');
    expect(p.isUnlocked, isFalse);
    expect(p.levelsToUnlock, 3);
  });

  test(
    'panic threshold is the mean drawdown at the first sell of each run',
    () {
      final NerveProfile p = NerveProfile.from(<RunRecord>[
        _run('a', 40, <DecisionSample>[_s('sell', 0.20), _s('sell', 0.40)]),
        _run('b', 50, <DecisionSample>[_s('hold', 0.10), _s('sell', 0.30)]),
        _run('c', 90, <DecisionSample>[_s('hold', 0.25)]),
      ]);
      expect(p.panicThreshold, closeTo(0.25, 1e-9));
    },
  );

  test('never selling reads as no threshold, not a zero', () {
    final NerveProfile p = NerveProfile.from(<RunRecord>[
      _run('a', 100, <DecisionSample>[_s('hold', 0.3), _s('hold', 0.2)]),
    ]);
    expect(p.panicThreshold, isNull);
    expect(p.archetype, NerveArchetype.ironHand);
  });

  test('a deep seller who breaks in fast crashes is the Deep Holder', () {
    final NerveProfile p = NerveProfile.from(<RunRecord>[
      for (final String id in <String>['a', 'b', 'c', 'd', 'e'])
        _run(id, 70, <DecisionSample>[
          _s('hold', 0.2, speed: 0.004),
          _s('sell', 0.3, speed: 0.04),
        ]),
    ]);
    expect(p.isUnlocked, isTrue);
    expect(p.archetype, NerveArchetype.deepHolder);
    expect(p.fastPanicRate, 1);
    expect(p.slowPanicRate, 0);
  });

  test('overall and "up from" come from the scored runs only', () {
    final NerveProfile p = NerveProfile.from(<RunRecord>[
      _run('a', 40, const <DecisionSample>[]),
      _run('b', 50, const <DecisionSample>[]),
      _run('c', 60, const <DecisionSample>[]),
      _run('d', null, const <DecisionSample>[]),
      _run('e', 90, const <DecisionSample>[]),
    ]);
    expect(p.overall, 60);
    expect(p.startingOverall, 50);
    expect(p.learningDelta, closeTo((50 + 60 + 90) / 3 - 50, 1));
  });

  test('radar values stay in range', () {
    final NerveProfile p = NerveProfile.from(<RunRecord>[
      _run('a', 10, <DecisionSample>[_s('sell', 0.01, sec: 60)]),
    ]);
    for (final double v in p.radar.values) {
      expect(v, inInclusiveRange(0, 1));
    }
  });

  test('median decision time ignores unmeasured samples', () {
    final NerveProfile p = NerveProfile.from(<RunRecord>[
      _run('a', 80, <DecisionSample>[
        _s('hold', 0.2, sec: 4),
        _s('hold', 0.2, sec: 8),
        _s('hold', 0.2, sec: 6),
        _s('hold', 0.2),
      ]),
    ]);
    expect(p.medianSeconds, 6);
  });
}
