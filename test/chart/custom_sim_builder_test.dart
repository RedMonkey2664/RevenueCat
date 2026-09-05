import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:market_nerve/core/market/bar_interval.dart';
import 'package:market_nerve/core/market/candle.dart';
import 'package:market_nerve/core/market/instrument.dart';
import 'package:market_nerve/features/simulator/custom/custom_sim_builder.dart';
import 'package:market_nerve/features/simulator/engine/level_model.dart';

const Instrument nifty = Instrument(
  id: 'yahoo:^NSEI',
  symbol: '^NSEI',
  name: 'NIFTY 50',
  region: MarketRegion.indiaEquity,
  displaySymbol: 'NIFTY',
  isIndex: true,
);

/// A series that actually falls, so the pause ladder has something to find.
List<Candle> crashing(int n) {
  final List<Candle> out = <Candle>[];
  double price = 1000;
  for (int i = 0; i < n; i++) {
    // Rise for the first fifth, then a sustained decline with wobble.
    price *= i < n / 5 ? 1.004 : (0.985 + 0.01 * math.sin(i / 3));
    out.add(
      Candle(
        date: DateTime.utc(2024).add(Duration(days: i)),
        open: price * 0.999,
        high: price * 1.01,
        low: price * 0.99,
        close: price,
      ),
    );
  }
  return out;
}

void main() {
  final DateTime from = DateTime.utc(2024);
  final DateTime to = DateTime.utc(2024, 6, 30);

  group('CustomSimBuilder', () {
    test('produces a level the engine cannot tell from a campaign one', () {
      final SimulationLevel level = CustomSimBuilder.build(
        instrument: nifty,
        candles: crashing(180),
        interval: BarInterval.d1,
        from: from,
        to: to,
      );

      expect(level.candles, hasLength(180));
      expect(level.startingBalance, CustomSimBuilder.startingBalance);
      expect(level.realAssetName, 'NIFTY 50');
      expect(level.pausePoints, isNotEmpty);
      expect(level.isSyntheticSample, isFalse,
          reason: 'the prices are real, only the trading is simulated');
    });

    test('skips blind mode, because the player chose the instrument', () {
      final SimulationLevel level = CustomSimBuilder.build(
        instrument: nifty,
        candles: crashing(180),
        interval: BarInterval.d1,
        from: from,
        to: to,
      );
      expect(level.revealFromStart, isTrue);
    });

    test('pause points stay ordered and inside the series', () {
      final SimulationLevel level = CustomSimBuilder.build(
        instrument: nifty,
        candles: crashing(200),
        interval: BarInterval.d1,
        from: from,
        to: to,
      );

      int previous = -1;
      for (final dynamic p in level.pausePoints) {
        final int index = p.triggerIndex as int;
        expect(index, greaterThan(previous));
        expect(index, inInclusiveRange(0, level.candles.length - 1));
        previous = index;
      }
    });

    test('scales the moment count to the window length', () {
      final SimulationLevel short = CustomSimBuilder.build(
        instrument: nifty,
        candles: crashing(60),
        interval: BarInterval.d1,
        from: from,
        to: to,
      );
      final SimulationLevel long = CustomSimBuilder.build(
        instrument: nifty,
        candles: crashing(400),
        interval: BarInterval.d1,
        from: from,
        to: to,
      );

      // A three-week window must not be asked twelve times.
      expect(
        short.pausePoints.length,
        lessThanOrEqualTo(long.pausePoints.length),
      );
      expect(long.pausePoints.length, lessThanOrEqualTo(14));
    });

    test('refuses a window too short to play, with a usable message', () {
      expect(
        () => CustomSimBuilder.build(
          instrument: nifty,
          candles: crashing(10),
          interval: BarInterval.d1,
          from: from,
          to: to,
        ),
        throwsA(
          isA<CustomSimException>().having(
            (CustomSimException e) => e.message,
            'message',
            allOf(contains('10 bars'), contains('longer')),
          ),
        ),
      );
    });

    test('the id encodes instrument, timeframe and range', () {
      final SimulationLevel level = CustomSimBuilder.build(
        instrument: nifty,
        candles: crashing(180),
        interval: BarInterval.h1,
        from: from,
        to: to,
      );
      expect(level.id, contains('yahoo:^NSEI'));
      expect(level.id, contains('1H'));
      expect(level.id, contains('2024-01-01'));
      expect(level.id, contains('2024-06-30'));
    });
  });
}
