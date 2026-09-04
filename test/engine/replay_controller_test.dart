import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_nerve/features/simulator/engine/candle_model.dart';
import 'package:market_nerve/features/simulator/engine/level_model.dart';
import 'package:market_nerve/features/simulator/engine/portfolio.dart';
import 'package:market_nerve/features/simulator/engine/replay_controller.dart';
import 'package:market_nerve/features/simulator/engine/script_event_model.dart';
import 'package:market_nerve/features/simulator/engine/simulation_mode.dart';

/// A flat 20-candle series at ₹100, so any portfolio movement in a test comes
/// from the decision under test rather than from price drift.
List<Candle> _flatCandles({int count = 20, double price = 100}) {
  return <Candle>[
    for (int i = 0; i < count; i++)
      Candle(
        date: DateTime(2000).add(Duration(days: i)),
        open: price,
        high: price,
        low: price,
        close: price,
      ),
  ];
}

SimulationLevel _levelWithPausesAt(
  List<int> indices, {
  List<Candle>? candles,
  DecisionAction optimal = DecisionAction.hold,
}) {
  return SimulationLevel(
    id: 'test_level',
    realAssetName: 'Test Asset',
    startingBalance: 100000,
    candles: candles ?? _flatCandles(),
    pausePoints: <PausePoint>[
      for (final int i in indices)
        PausePoint(
          triggerIndex: i,
          flashTreatment: FlashTreatment.redFlashHard,
          optimalAction: optimal,
          revealHeadline: 'headline for $i',
        ),
    ],
  );
}

ProviderContainer _containerFor(SimulationLevel level) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      currentLevelProvider.overrideWithValue(level),
      // These tests cover the guided flow; advanced mode has its own suite.
      currentModeProvider.overrideWithValue(SimulationMode.beginner),
    ],
  );
  addTearDown(container.dispose);
  // The provider is autoDispose; without a listener it is torn down between
  // reads and the replay timer dies with it. The level screen supplies this
  // listener by watching the provider, so tests must too.
  container.listen(replayControllerProvider, (_, _) {});
  return container;
}

void main() {
  group('ReplayController', () {
    test('starts idle at the first candle with a deployed position', () {
      final ProviderContainer container =
          _containerFor(_levelWithPausesAt(<int>[]));
      final ReplayState state = container.read(replayControllerProvider);

      expect(state.status, ReplayStatus.idle);
      expect(state.currentIndex, 0);
      expect(state.dayNumber, 1);
      expect(state.isRevealed, isFalse);
      expect(state.portfolioValue, closeTo(100000, 0.001));
      expect(state.portfolio.units, greaterThan(0));
      expect(state.portfolio.cash, greaterThan(0));
    });

    test('never exposes candles beyond the current index', () {
      final ProviderContainer container =
          _containerFor(_levelWithPausesAt(<int>[]));
      expect(container.read(replayControllerProvider).visibleCandles, hasLength(1));

      container.read(replayControllerProvider.notifier).scrubTo(9);
      expect(
        container.read(replayControllerProvider).visibleCandles,
        hasLength(10),
      );
    });

    test('halts on a pause point and refuses to resume until a decision', () {
      final ProviderContainer container =
          _containerFor(_levelWithPausesAt(<int>[5]));
      final ReplayController controller =
          container.read(replayControllerProvider.notifier);

      controller
        ..scrubTo(4)
        ..play();

      // scrubTo(4) then play() steps to 5 on the next tick; drive it directly
      // by starting play from the pause index instead of waiting on a timer.
      controller.scrubTo(5);
      controller.play();

      final ReplayState state = container.read(replayControllerProvider);
      expect(state.status, ReplayStatus.awaitingDecision);
      expect(state.activePausePoint?.triggerIndex, 5);

      controller.play();
      expect(
        container.read(replayControllerProvider).status,
        ReplayStatus.awaitingDecision,
        reason: 'play() must not step past an unanswered pause point',
      );
    });

    test('records a decision and does not re-fire the same pause point', () {
      final ProviderContainer container =
          _containerFor(_levelWithPausesAt(<int>[5]));
      final ReplayController controller =
          container.read(replayControllerProvider.notifier);

      controller
        ..scrubTo(5)
        ..play()
        ..submitDecision(DecisionAction.sell);

      final ReplayState afterDecision =
          container.read(replayControllerProvider);
      expect(afterDecision.decisions, hasLength(1));
      expect(afterDecision.decisions.single.chosen, DecisionAction.sell);
      expect(afterDecision.activePausePoint, isNull);
      expect(afterDecision.status, ReplayStatus.playing);

      controller
        ..scrubTo(5)
        ..play();
      expect(
        container.read(replayControllerProvider).status,
        ReplayStatus.playing,
        reason: 'a resolved pause point must not halt playback again',
      );
    });

    test('plays through to the end and finishes', () async {
      final ProviderContainer container = _containerFor(
        _levelWithPausesAt(<int>[], candles: _flatCandles(count: 6)),
      );
      container.read(replayControllerProvider.notifier)
        ..setSpeed(ReplaySpeed.x4)
        ..play();

      await Future<void>.delayed(
        ReplaySpeed.x4.tickInterval * 10,
      );

      final ReplayState state = container.read(replayControllerProvider);
      expect(state.status, ReplayStatus.finished);
      expect(state.currentIndex, 5);
      expect(state.dayNumber, state.totalDays);
    });

    test('reveal() is the only way blind mode lifts', () {
      final ProviderContainer container =
          _containerFor(_levelWithPausesAt(<int>[]));
      final ReplayController controller =
          container.read(replayControllerProvider.notifier);

      expect(container.read(replayControllerProvider).isRevealed, isFalse);
      controller.play();
      expect(container.read(replayControllerProvider).isRevealed, isFalse);

      controller.reveal();
      expect(container.read(replayControllerProvider).isRevealed, isTrue);
    });
  });

  group('Portfolio', () {
    const double start = 100000;
    const double entry = 100;

    test('opens at the documented deployed/cash split', () {
      final Portfolio p =
          Portfolio.opening(startingBalance: start, entryPrice: entry);

      expect(p.cash, closeTo(start * (1 - Portfolio.initialDeployedFraction), 0.001));
      expect(p.units, closeTo(start * Portfolio.initialDeployedFraction / entry, 0.001));
      expect(p.valueAt(entry), closeTo(start, 0.001));
      expect(p.pnlAt(entry), closeTo(0, 0.001));
    });

    test('hold changes nothing; the drawdown is felt in full', () {
      final Portfolio p =
          Portfolio.opening(startingBalance: start, entryPrice: entry)
              .apply(DecisionAction.hold, 50);

      // 75% deployed, halved, plus the 25% cash reserve.
      expect(p.valueAt(50), closeTo(62500, 0.001));
      expect(p.pnlPercentAt(50), closeTo(-37.5, 0.001));
    });

    test('sell all locks the loss in: later recovery does nothing', () {
      final Portfolio sold =
          Portfolio.opening(startingBalance: start, entryPrice: entry)
              .apply(DecisionAction.sell, 50);

      expect(sold.isFlat, isTrue);
      expect(sold.valueAt(50), closeTo(62500, 0.001));
      expect(
        sold.valueAt(200),
        closeTo(62500, 0.001),
        reason: 'a flat portfolio must not benefit from the rebound',
      );
    });

    test('buy the dip deploys the reserve and amplifies the recovery', () {
      final Portfolio bought =
          Portfolio.opening(startingBalance: start, entryPrice: entry)
              .apply(DecisionAction.buyDip, 50);

      expect(bought.cash, 0);
      // 750 units held + 25,000 cash at ₹50 = 500 more units.
      expect(bought.units, closeTo(1250, 0.001));
      expect(bought.valueAt(50), closeTo(62500, 0.001));
      expect(
        bought.valueAt(100),
        closeTo(125000, 0.001),
        reason: 'buying the dip must beat holding once price returns to entry',
      );
    });

    test('buy the dip with no cash degrades to a hold rather than failing', () {
      final Portfolio noCash =
          Portfolio.opening(startingBalance: start, entryPrice: entry)
              .apply(DecisionAction.buyDip, 50)
              .apply(DecisionAction.buyDip, 40);

      expect(noCash.units, closeTo(1250, 0.001));
      expect(noCash.cash, 0);
    });
  });

  group('PausePoint.fromJson', () {
    test('resolves trigger_date to a candle index', () {
      final List<Candle> candles = _flatCandles(count: 10);
      final PausePoint p = PausePoint.fromJson(
        <String, dynamic>{
          'trigger_date': '2000-01-04',
          'flash_treatment': 'red_flash_hard',
          'optimal_action': 'buy_dip',
          'reveal_headline': 'x',
        },
        candles,
      );

      expect(p.triggerIndex, 3);
      expect(p.optimalAction, DecisionAction.buyDip);
    });

    test('throws on a trigger_date the level data does not contain', () {
      expect(
        () => PausePoint.fromJson(
          <String, dynamic>{
            'trigger_date': '1999-12-31',
            'flash_treatment': 'red_flash_hard',
            'optimal_action': 'hold',
            'reveal_headline': 'x',
          },
          _flatCandles(count: 10),
        ),
        throwsFormatException,
      );
    });
  });
}
