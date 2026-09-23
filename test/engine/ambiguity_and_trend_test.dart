import 'package:flutter_test/flutter_test.dart';
import 'package:histox/core/services/run_history_service.dart';
import 'package:histox/features/simulator/debrief/behaviour_trend.dart';
import 'package:histox/core/market/candle.dart';
import 'package:histox/features/simulator/engine/discipline_score.dart';
import 'package:histox/features/simulator/engine/script_event_model.dart';

RecordedDecision _decision({
  required DecisionAction chose,
  required DecisionAction optimal,
  bool ambiguous = false,
  int index = 3,
}) {
  return RecordedDecision(
    pausePoint: PausePoint(
      triggerIndex: index,
      flashTreatment: FlashTreatment.redFlashHard,
      optimalAction: optimal,
      revealHeadline: 'x',
      isAmbiguous: ambiguous,
    ),
    chosen: chose,
    portfolioValueAtDecision: 100000,
  );
}

RunRecord _run(List<DecisionSample> samples) => RunRecord(
  levelId: 'l',
  title: 't',
  mode: 'beginner',
  score: 50,
  playedAt: DateTime(2026),
  samples: samples,
);

DecisionSample _sample(String action, {double drawdown = 0.2}) =>
    DecisionSample(
      action: action,
      drawdown: drawdown,
      crashSpeed: 0.01,
      credit: action == 'sell' ? 0 : 1,
    );

void main() {
  group('a moment the data cannot call is not scored', () {
    test('selling at an ambiguous pause point is not counted as a panic', () {
      final DisciplineScore score = DisciplineScore.forBeginner(<
        RecordedDecision
      >[
        _decision(
          chose: DecisionAction.sell,
          optimal: DecisionAction.hold,
          ambiguous: true,
        ),
      ]);

      // The moment is shown, but it proves nothing either way.
      expect(score.moments, hasLength(1));
      expect(score.moments.single.graded, isFalse);
      expect(score.panicCount, 0);
      expect(score.momentsTested, 0);
      expect(score.wasTested, isFalse);
      expect(score.score, isNull);
    });

    test('an ambiguous moment does not drag down a scored run', () {
      final DisciplineScore score = DisciplineScore.forBeginner(<
        RecordedDecision
      >[
        _decision(chose: DecisionAction.hold, optimal: DecisionAction.hold),
        _decision(
          chose: DecisionAction.sell,
          optimal: DecisionAction.hold,
          ambiguous: true,
        ),
      ]);

      // One graded moment at full credit; the ungraded one is reported only.
      expect(score.score, 100);
      expect(score.momentsTested, 1);
      expect(score.ungradedCount, 1);
      expect(score.moments, hasLength(2));
    });

    test('a clear panic still scores zero', () {
      final DisciplineScore score = DisciplineScore.forBeginner(<
        RecordedDecision
      >[_decision(chose: DecisionAction.sell, optimal: DecisionAction.hold)]);

      expect(score.score, 0);
      expect(score.panicCount, 1);
    });

    test('the ambiguous flag is read from the level script', () {
      Map<String, dynamic> json(bool ambiguous) => <String, dynamic>{
        'trigger_date': '1987-10-15',
        'flash_treatment': 'amber_flash_soft',
        'optimal_action': 'hold',
        'reveal_headline': 'x',
        'derived': <String, dynamic>{'ambiguous': ambiguous},
      };
      final List<Candle> candles = <Candle>[
        Candle(
          date: DateTime.utc(1987, 10, 15),
          open: 1,
          high: 1,
          low: 1,
          close: 1,
        ),
      ];

      expect(PausePoint.fromJson(json(true), candles).isAmbiguous, isTrue);
      expect(PausePoint.fromJson(json(false), candles).isAmbiguous, isFalse);
    });
  });

  group('the pattern panel only speaks when the history supports it', () {
    test('one prior run is an anecdote, not a trend', () {
      final BehaviourTrend t = BehaviourTrend.compare(
        priorHistory: <RunRecord>[
          _run(<DecisionSample>[_sample('sell'), _sample('hold')]),
        ],
        runTests: 2,
        runSells: 1,
      );

      expect(t.hasHistory, isFalse);
      expect(t.change, isNull);
      expect(t.depthNote, isNull);
      // It still reports this run, and says why it cannot compare yet.
      expect(t.line, contains('sold into 1 of 2 falls'));
      expect(t.line, contains('Play a few more'));
    });

    test('an improvement is reported against the earlier runs', () {
      final BehaviourTrend t = BehaviourTrend.compare(
        priorHistory: <RunRecord>[
          _run(<DecisionSample>[_sample('sell'), _sample('sell')]),
          _run(<DecisionSample>[_sample('sell'), _sample('hold')]),
        ],
        runTests: 4,
        runSells: 0,
      );

      expect(t.hasHistory, isTrue);
      expect(t.priorSells, 3);
      expect(t.priorTests, 4);
      expect(t.line, contains('sold into 3 of 4 falls (75%)'));
      expect(t.change, contains('lower than before'));
    });

    test('a small swing is called in line rather than progress', () {
      final BehaviourTrend t = BehaviourTrend.compare(
        priorHistory: <RunRecord>[
          _run(<DecisionSample>[_sample('sell'), _sample('hold')]),
          _run(<DecisionSample>[_sample('sell'), _sample('hold')]),
        ],
        runTests: 2,
        runSells: 1,
      );

      expect(t.change, contains('in line'));
    });

    test('the depth note averages only the sells that were recorded', () {
      final BehaviourTrend t = BehaviourTrend.compare(
        priorHistory: <RunRecord>[
          _run(<DecisionSample>[
            _sample('sell', drawdown: 0.10),
            _sample('hold', drawdown: 0.50),
          ]),
          _run(<DecisionSample>[_sample('sell', drawdown: 0.30)]),
        ],
        runTests: 2,
        runSells: 0,
      );

      // 10% and 30%, not the 50% hold.
      expect(t.depthNote, contains('20%'));
    });

    test('a run that tested nothing says nothing', () {
      final BehaviourTrend t = BehaviourTrend.compare(
        priorHistory: <RunRecord>[
          _run(<DecisionSample>[_sample('sell')]),
          _run(<DecisionSample>[_sample('sell')]),
        ],
        runTests: 0,
        runSells: 0,
      );

      expect(t.line, isNull);
      expect(t.change, isNull);
    });
  });
}
