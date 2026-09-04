import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:market_nerve/features/simulator/campaign/level_repository.dart'
    show AssetClass;
import 'package:market_nerve/features/simulator/engine/candle_model.dart';
import 'package:market_nerve/features/simulator/engine/endless_generator.dart';
import 'package:market_nerve/features/simulator/engine/level_model.dart';
import 'package:market_nerve/features/simulator/engine/pause_ladder.dart';
import 'package:market_nerve/features/simulator/engine/script_event_model.dart';

List<Candle> _series(List<double> closes) {
  return <Candle>[
    for (int i = 0; i < closes.length; i++)
      Candle(
        date: DateTime.utc(2020).add(Duration(days: i)),
        open: closes[i],
        high: closes[i] * 1.01,
        low: closes[i] * 0.99,
        close: closes[i],
      ),
  ];
}

/// A long series with repeated rises and falls, so windows are varied.
List<Candle> _wavy(int length) {
  final List<double> closes = <double>[];
  double price = 100;
  for (int i = 0; i < length; i++) {
    // Deterministic saw-tooth: 40 up, 30 down, repeat. No RNG, no flake.
    final int phase = i % 70;
    price *= phase < 40 ? 1.012 : 0.982;
    closes.add(price);
  }
  return _series(closes);
}

HistoryPool _pool(List<Candle> candles) => HistoryPool(
      assetClass: AssetClass.crypto,
      assetName: 'Test Asset',
      source: 'test',
      candles: candles,
    );

void main() {
  group('PauseLadder', () {
    test('asks again as price steps further down', () {
      // A steady 60% decline: one drawdown episode, but many moments.
      final List<double> closes = <double>[100];
      for (int i = 0; i < 60; i++) {
        closes.add(closes.last * 0.985);
      }
      final List<Candle> candles = _series(closes);

      final List<LadderRung> rungs = PauseLadder.build(candles, 0.10);
      expect(
        rungs.length,
        greaterThan(1),
        reason: 'a sustained fall must produce more than one moment — this is '
            'exactly what a single-drawdown rule could not do',
      );

      // Each rung is strictly deeper than the last.
      for (int i = 1; i < rungs.length; i++) {
        expect(rungs[i].fromPeak, greaterThan(rungs[i - 1].fromPeak));
      }
    });

    test('ignores shallow noise above the floor', () {
      final List<Candle> flat = _series(
        List<double>.generate(80, (int i) => 100 + (i.isEven ? 1 : -1)),
      );
      expect(PauseLadder.build(flat, 0.05), isEmpty);
    });

    test('a new high resets the ladder so a second leg down asks again', () {
      final List<double> closes = <double>[];
      double p = 100;
      for (int i = 0; i < 30; i++) {
        closes.add(p *= 0.97); // leg one down
      }
      for (int i = 0; i < 40; i++) {
        closes.add(p *= 1.04); // recovery to a new high
      }
      for (int i = 0; i < 30; i++) {
        closes.add(p *= 0.97); // leg two down
      }

      final List<LadderRung> rungs = PauseLadder.build(_series(closes), 0.10);
      final int firstLeg =
          rungs.where((LadderRung r) => r.index < 30).length;
      final int secondLeg =
          rungs.where((LadderRung r) => r.index > 70).length;

      expect(firstLeg, greaterThan(0));
      expect(secondLeg, greaterThan(0), reason: 'the second fall must be seen');
    });

    test('targets roughly the requested number of moments', () {
      final (List<LadderRung> rungs, _) =
          PauseLadder.forTarget(_wavy(400), 12);
      expect(rungs.length, inInclusiveRange(8, 16));
    });

    group('verdicts come from what happened next', () {
      test('a strong rebound reads as buy the dip', () {
        final List<double> closes = <double>[
          ...List<double>.filled(5, 100),
          50,
          ...List<double>.filled(40, 90),
        ];
        final LadderVerdict v = PauseLadder.verdictAt(_series(closes), 5);
        expect(v.action, DecisionAction.buyDip);
        expect(v.ambiguous, isFalse);
      });

      test('a further collapse reads as a defensible sell', () {
        final List<double> closes = <double>[
          ...List<double>.filled(5, 100),
          80,
          ...List<double>.filled(40, 20),
        ];
        final LadderVerdict v = PauseLadder.verdictAt(_series(closes), 5);
        expect(v.action, DecisionAction.sell);
      });

      test('a flat drift is hold, and admits it is ambiguous', () {
        final List<double> closes = <double>[
          ...List<double>.filled(5, 100),
          80,
          ...List<double>.filled(40, 78),
        ];
        final LadderVerdict v = PauseLadder.verdictAt(_series(closes), 5);
        expect(v.action, DecisionAction.hold);
        expect(v.ambiguous, isTrue);
      });

      test('too little lookahead is ambiguous, never a confident claim', () {
        final List<double> closes = <double>[
          ...List<double>.filled(20, 100),
          50,
          ...List<double>.filled(5, 200),
        ];
        final LadderVerdict v = PauseLadder.verdictAt(_series(closes), 20);
        expect(
          v.ambiguous,
          isTrue,
          reason: 'five candles cannot prove buying the dip was right',
        );
      });
    });
  });

  group('EndlessGenerator', () {
    test('produces a window the engine cannot tell from a campaign level', () {
      final SimulationLevel level =
          EndlessGenerator(pool: _pool(_wavy(1200)), random: Random(7))
              .generate();

      expect(level.candles.length, EndlessGenerator.windowLength);
      expect(level.startingBalance, 100000);
      expect(level.pausePoints, isNotEmpty);
      expect(level.realAssetName, 'Test Asset');
      expect(level.isSyntheticSample, isFalse);
    });

    test('every pause point indexes a real candle', () {
      final SimulationLevel level =
          EndlessGenerator(pool: _pool(_wavy(1200)), random: Random(3))
              .generate();

      for (final PausePoint p in level.pausePoints) {
        expect(p.triggerIndex, inInclusiveRange(0, level.candles.length - 1));
        expect(p.revealHeadline, isNotEmpty);
      }
    });

    test('skips windows with nothing worth deciding about', () {
      // A pool that only ever rises: the generator should still terminate
      // rather than loop forever hunting for a drawdown.
      final List<Candle> rising = _series(
        List<double>.generate(600, (int i) => 100 * (1 + i * 0.004)),
      );
      final SimulationLevel level =
          EndlessGenerator(pool: _pool(rising), random: Random(1)).generate();

      expect(level.candles.length, EndlessGenerator.windowLength);
    });

    test('different seeds give different windows', () {
      final HistoryPool pool = _pool(_wavy(1500));
      final String a =
          EndlessGenerator(pool: pool, random: Random(1)).generate().id;
      final String b =
          EndlessGenerator(pool: pool, random: Random(99)).generate().id;
      expect(a, isNot(b));
    });

    test('refuses a pool too short to draw a window from', () {
      expect(
        () => EndlessGenerator(pool: _pool(_wavy(40))).generate(),
        throwsStateError,
      );
    });
  });

  group('the bundled crypto pool', () {
    test('loads and can generate a playable run', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const HistoryPoolRepository repo = HistoryPoolRepository();

      final List<AssetClass> markets = await repo.availableMarkets();
      expect(
        markets,
        contains(AssetClass.crypto),
        reason: 'the crypto pool is bundled',
      );

      final HistoryPool pool = await repo.load(AssetClass.crypto);
      expect(pool.candles.length, greaterThan(1000));
      expect(pool.source, contains('Binance'));

      // Candles must be ordered, or the replay walks backwards through time.
      for (int i = 1; i < pool.candles.length; i++) {
        expect(
          pool.candles[i].date.isAfter(pool.candles[i - 1].date),
          isTrue,
          reason: 'pool candle $i is out of order',
        );
      }

      final SimulationLevel level =
          EndlessGenerator(pool: pool, random: Random(42)).generate();
      expect(level.candles.length, EndlessGenerator.windowLength);
      expect(level.pausePoints, isNotEmpty);
    });
  });
}
