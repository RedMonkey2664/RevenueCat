import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_nerve/data/sample/dev_sample_level.dart';
import 'package:market_nerve/features/simulator/engine/candle_model.dart';
import 'package:market_nerve/features/simulator/engine/discipline_score.dart';
import 'package:market_nerve/features/simulator/engine/drawdown_detector.dart';
import 'package:market_nerve/features/simulator/engine/level_model.dart';
import 'package:market_nerve/features/simulator/engine/replay_controller.dart';
import 'package:market_nerve/features/simulator/engine/script_event_model.dart';
import 'package:market_nerve/features/simulator/engine/simulation_mode.dart';

/// Builds a series from explicit closes, so each scoring test states the exact
/// shape it is grading.
List<Candle> _series(List<double> closes) {
  return <Candle>[
    for (int i = 0; i < closes.length; i++)
      Candle(
        date: DateTime(2000).add(Duration(days: i)),
        open: closes[i],
        high: closes[i],
        low: closes[i],
        close: closes[i],
      ),
  ];
}

SimulationLevel _level(
  List<double> closes, {
  List<PausePoint> pausePoints = const <PausePoint>[],
}) {
  return SimulationLevel(
    id: 'test',
    realAssetName: 'Test Asset',
    startingBalance: 100000,
    candles: _series(closes),
    pausePoints: pausePoints,
  );
}

ProviderContainer _containerFor(SimulationLevel level, SimulationMode mode) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      currentLevelProvider.overrideWithValue(level),
      currentModeProvider.overrideWithValue(mode),
    ],
  );
  addTearDown(container.dispose);
  container.listen(replayControllerProvider, (_, _) {});
  return container;
}

void main() {
  group('DrawdownDetector', () {
    test('ignores wobbles shallower than the threshold', () {
      final List<DrawdownEpisode> episodes = DrawdownDetector.detect(
        _series(<double>[100, 98, 96, 99, 101]),
      );
      expect(episodes, isEmpty);
    });

    test('finds a peak-to-trough decline and its recovery', () {
      final List<DrawdownEpisode> episodes = DrawdownDetector.detect(
        _series(<double>[100, 110, 90, 80, 95, 115]),
      );

      expect(episodes, hasLength(1));
      final DrawdownEpisode e = episodes.single;
      expect(e.peakIndex, 1);
      expect(e.troughIndex, 3);
      expect(e.depth, closeTo(0.2727, 0.001));
      expect(e.recoveryIndex, 5);
      expect(e.recovered, isTrue);
    });

    test('keeps a decline that never recovered', () {
      final List<DrawdownEpisode> episodes = DrawdownDetector.detect(
        _series(<double>[100, 120, 100, 85]),
      );

      expect(episodes, hasLength(1));
      expect(episodes.single.recovered, isFalse);
      expect(episodes.single.troughIndex, 3);
    });

    test('separates two declines rather than merging them', () {
      final List<DrawdownEpisode> episodes = DrawdownDetector.detect(
        _series(<double>[100, 80, 105, 85, 110]),
      );
      expect(episodes, hasLength(2));
      expect(episodes.first.peakIndex, 0);
      expect(episodes.last.peakIndex, 2);
    });
  });

  group('Discipline Score — beginner', () {
    RecordedDecision decision(DecisionAction chose, DecisionAction optimal) {
      return RecordedDecision(
        pausePoint: PausePoint(
          triggerIndex: 3,
          flashTreatment: FlashTreatment.redFlashHard,
          optimalAction: optimal,
          revealHeadline: 'x',
        ),
        chosen: chose,
        portfolioValueAtDecision: 100000,
      );
    }

    test('matching the optimal action scores full marks', () {
      final DisciplineScore s = DisciplineScore.forBeginner(<RecordedDecision>[
        decision(DecisionAction.hold, DecisionAction.hold),
      ]);
      expect(s.score, 100);
      expect(s.panicCount, 0);
    });

    test('selling when holding was right scores zero', () {
      final DisciplineScore s = DisciplineScore.forBeginner(<RecordedDecision>[
        decision(DecisionAction.sell, DecisionAction.hold),
      ]);
      expect(s.score, 0);
      expect(s.panicCount, 1);
    });

    test('hold vs buy-the-dip is partial credit, not zero', () {
      final DisciplineScore s = DisciplineScore.forBeginner(<RecordedDecision>[
        decision(DecisionAction.hold, DecisionAction.buyDip),
      ]);
      expect(s.score, 60);
      expect(s.panicCount, 0, reason: 'holding is never a panic');
    });

    test('a missed exit beats a panic sell', () {
      final DisciplineScore missedExit =
          DisciplineScore.forBeginner(<RecordedDecision>[
        decision(DecisionAction.hold, DecisionAction.sell),
      ]);
      final DisciplineScore panic =
          DisciplineScore.forBeginner(<RecordedDecision>[
        decision(DecisionAction.sell, DecisionAction.hold),
      ]);
      expect(missedExit.score, greaterThan(panic.score!));
    });

    test('an ungraded run reports no score rather than a flattering one', () {
      final DisciplineScore s =
          DisciplineScore.forBeginner(const <RecordedDecision>[]);
      expect(s.score, isNull);
      expect(s.wasTested, isFalse);
    });
  });

  group('Discipline Score — advanced', () {
    final List<DrawdownEpisode> episodes = DrawdownDetector.detect(
      _series(<double>[100, 120, 90, 80, 130]),
    );

    Trade trade(int index, {required bool isBuy, required double units}) {
      return Trade(
        candleIndex: index,
        isBuy: isBuy,
        fraction: 1,
        price: 100,
        unitsDelta: isBuy ? units : -units,
      );
    }

    test('holding through the decline scores full marks', () {
      final DisciplineScore s = DisciplineScore.forAdvanced(
        trades: const <Trade>[],
        episodes: episodes,
        startingUnits: 100,
      );
      expect(s.score, 100);
      expect(s.momentsTested, 1);
    });

    test('liquidating during the decline scores zero', () {
      final DisciplineScore s = DisciplineScore.forAdvanced(
        trades: <Trade>[trade(2, isBuy: false, units: 100)],
        episodes: episodes,
        startingUnits: 100,
      );
      expect(s.score, 0);
      expect(s.panicCount, 1);
    });

    test('the penalty scales with how much was cut', () {
      final DisciplineScore quarter = DisciplineScore.forAdvanced(
        trades: <Trade>[trade(2, isBuy: false, units: 25)],
        episodes: episodes,
        startingUnits: 100,
      );
      final DisciplineScore half = DisciplineScore.forAdvanced(
        trades: <Trade>[trade(2, isBuy: false, units: 50)],
        episodes: episodes,
        startingUnits: 100,
      );

      expect(quarter.score, 75);
      expect(half.score, 50);
      expect(
        quarter.panicCount,
        1,
        reason: 'a partial cut is still a sell into a fall',
      );
    });

    test('buying into the decline scores full marks', () {
      final DisciplineScore s = DisciplineScore.forAdvanced(
        trades: <Trade>[trade(3, isBuy: true, units: 10)],
        episodes: episodes,
        startingUnits: 100,
      );
      expect(s.score, 100);
      expect(s.panicCount, 0);
    });

    test('selling after the recovery is not graded as a panic', () {
      final DisciplineScore s = DisciplineScore.forAdvanced(
        trades: <Trade>[trade(4, isBuy: false, units: 10)],
        episodes: episodes,
        startingUnits: 100,
      );
      expect(
        s.score,
        100,
        reason: 'trading outside a drawdown is preference, not discipline',
      );
    });

    test('an episode entered already in cash is skipped, not graded', () {
      final DisciplineScore s = DisciplineScore.forAdvanced(
        // Sold out entirely before the peak at index 1.
        trades: <Trade>[trade(0, isBuy: false, units: 100)],
        episodes: episodes,
        startingUnits: 100,
      );
      expect(s.wasTested, isFalse);
      expect(s.score, isNull);
    });

    test('a window with no real drawdown reports no score', () {
      final DisciplineScore s = DisciplineScore.forAdvanced(
        trades: const <Trade>[],
        episodes: const <DrawdownEpisode>[],
        startingUnits: 100,
      );
      expect(s.score, isNull);
      expect(s.wasTested, isFalse);
    });
  });

  group('Advanced mode playback', () {
    test('never halts, even on a scripted pause point', () {
      final SimulationLevel level = _level(
        <double>[100, 110, 90, 80, 130],
        pausePoints: <PausePoint>[
          const PausePoint(
            triggerIndex: 2,
            flashTreatment: FlashTreatment.redFlashHard,
            optimalAction: DecisionAction.hold,
            revealHeadline: 'x',
          ),
        ],
      );
      final ProviderContainer c = _containerFor(level, SimulationMode.advanced);
      final ReplayController controller =
          c.read(replayControllerProvider.notifier)
            ..scrubTo(2)
            ..play();

      expect(c.read(replayControllerProvider).status, ReplayStatus.playing);
      expect(c.read(replayControllerProvider).activePausePoint, isNull);
      controller.pause();
    });

    test('buy and sell move the position at any candle', () {
      final SimulationLevel level = _level(<double>[100, 110, 90, 80, 130]);
      final ProviderContainer c = _containerFor(level, SimulationMode.advanced);
      final ReplayController controller =
          c.read(replayControllerProvider.notifier);

      final double startUnits = c.read(replayControllerProvider).portfolio.units;

      controller.buy(1);
      final ReplayState afterBuy = c.read(replayControllerProvider);
      expect(afterBuy.portfolio.units, greaterThan(startUnits));
      expect(afterBuy.portfolio.cash, closeTo(0, 0.001));
      expect(afterBuy.trades, hasLength(1));
      expect(afterBuy.trades.single.isBuy, isTrue);

      controller.sell(0.5);
      final ReplayState afterSell = c.read(replayControllerProvider);
      expect(
        afterSell.portfolio.units,
        closeTo(afterBuy.portfolio.units / 2, 0.001),
      );
      expect(afterSell.trades, hasLength(2));
      expect(afterSell.trades.last.unitsDelta, lessThan(0));
    });

    test('an impossible trade leaves no phantom entry in the log', () {
      final SimulationLevel level = _level(<double>[100, 110, 90]);
      final ProviderContainer c = _containerFor(level, SimulationMode.advanced);
      final ReplayController controller =
          c.read(replayControllerProvider.notifier)
            ..buy(1)
            ..buy(1);

      expect(
        c.read(replayControllerProvider).trades,
        hasLength(1),
        reason: 'a buy with no cash must not be recorded',
      );

      controller
        ..sell(1)
        ..sell(1);
      expect(
        c.read(replayControllerProvider).trades,
        hasLength(2),
        reason: 'a sell with no position must not be recorded',
      );
    });

    test('beginner mode refuses free trades', () {
      final SimulationLevel level = _level(<double>[100, 110, 90]);
      final ProviderContainer c = _containerFor(level, SimulationMode.beginner);
      c.read(replayControllerProvider.notifier).buy(1);

      expect(c.read(replayControllerProvider).trades, isEmpty);
    });
  });

  group('Dev sample level', () {
    test('carries the beginner moment count Somi asked for', () {
      final SimulationLevel level = DevSampleLevel.build();
      expect(level.pausePoints, hasLength(DevSampleLevel.momentCount));
      expect(DevSampleLevel.momentCount, greaterThan(10));
    });

    test('moments are ordered and never bunched together', () {
      final SimulationLevel level = DevSampleLevel.build();
      for (int i = 1; i < level.pausePoints.length; i++) {
        final int gap = level.pausePoints[i].triggerIndex -
            level.pausePoints[i - 1].triggerIndex;
        expect(gap, greaterThan(0), reason: 'pause points must be sorted');
        expect(gap, greaterThanOrEqualTo(7));
      }
    });

    test('has a gradeable drawdown for advanced mode', () {
      final SimulationLevel level = DevSampleLevel.build();
      expect(DrawdownDetector.detect(level.candles), isNotEmpty);
    });
  });
}
