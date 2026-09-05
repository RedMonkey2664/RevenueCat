import 'package:flutter_test/flutter_test.dart';
import 'package:market_nerve/core/market/bar_interval.dart';
import 'package:market_nerve/core/market/candle.dart';
import 'package:market_nerve/features/chart/model/chart_series.dart';

Candle bar(String iso, double o, double h, double l, double c, [double? v]) =>
    Candle(
      date: DateTime.parse(iso),
      open: o,
      high: h,
      low: l,
      close: c,
      volume: v,
    );

void main() {
  group('BarInterval.canAggregateTo', () {
    test('every finer intraday interval tiles every coarser one', () {
      expect(BarInterval.m1.canAggregateTo(BarInterval.m5), isTrue);
      expect(BarInterval.m5.canAggregateTo(BarInterval.h1), isTrue);
      expect(BarInterval.m30.canAggregateTo(BarInterval.h4), isTrue);
      expect(BarInterval.h1.canAggregateTo(BarInterval.h4), isTrue);
    });

    test('daily is never folded up from intraday', () {
      // An intraday series is not guaranteed to cover a whole session, so a
      // "daily" bar built from it could silently omit the open or the close.
      for (final BarInterval i in <BarInterval>[
        BarInterval.m1,
        BarInterval.m15,
        BarInterval.h1,
        BarInterval.h4,
      ]) {
        expect(
          i.canAggregateTo(BarInterval.d1),
          isFalse,
          reason: '${i.label} must not fold into 1D',
        );
      }
    });

    test('weekly and monthly come only from calendar buckets', () {
      expect(BarInterval.d1.canAggregateTo(BarInterval.w1), isTrue);
      expect(BarInterval.d1.canAggregateTo(BarInterval.mo1), isTrue);
      expect(BarInterval.w1.canAggregateTo(BarInterval.mo1), isTrue);
      expect(BarInterval.h1.canAggregateTo(BarInterval.w1), isFalse);
    });

    test('never folds downward or sideways into a finer interval', () {
      expect(BarInterval.d1.canAggregateTo(BarInterval.h1), isFalse);
      expect(BarInterval.w1.canAggregateTo(BarInterval.d1), isFalse);
      expect(BarInterval.d1.canAggregateTo(BarInterval.d1), isTrue);
    });
  });

  group('bucketStart', () {
    test('weeks start on Monday', () {
      // 2024-03-14 is a Thursday.
      expect(
        BarInterval.w1.bucketStart(DateTime.utc(2024, 3, 14)),
        DateTime.utc(2024, 3, 11),
      );
      // A Monday is its own bucket start.
      expect(
        BarInterval.w1.bucketStart(DateTime.utc(2024, 3, 11)),
        DateTime.utc(2024, 3, 11),
      );
      // A Sunday belongs to the week that began six days earlier.
      expect(
        BarInterval.w1.bucketStart(DateTime.utc(2024, 3, 17)),
        DateTime.utc(2024, 3, 11),
      );
    });

    test('months start on the 1st', () {
      expect(
        BarInterval.mo1.bucketStart(DateTime.utc(2024, 3, 29)),
        DateTime.utc(2024, 3),
      );
    });

    test('intraday buckets floor against the day, not the epoch', () {
      expect(
        BarInterval.h4.bucketStart(DateTime.utc(2024, 3, 14, 13, 42)),
        DateTime.utc(2024, 3, 14, 12),
      );
      expect(
        BarInterval.m15.bucketStart(DateTime.utc(2024, 3, 14, 9, 47)),
        DateTime.utc(2024, 3, 14, 9, 45),
      );
    });
  });

  group('ChartSeries.aggregate', () {
    test('folds a trading week into one weekly bar', () {
      // Mon-Fri, 11-15 March 2024.
      final List<Candle> daily = <Candle>[
        bar('2024-03-11', 100, 110, 95, 105, 10),
        bar('2024-03-12', 105, 120, 100, 118, 20),
        bar('2024-03-13', 118, 119, 90, 92, 30),
        bar('2024-03-14', 92, 101, 91, 99, 40),
        bar('2024-03-15', 99, 104, 98, 103, 50),
      ];

      final List<Candle> weekly = ChartSeries.aggregate(
        daily,
        from: BarInterval.d1,
        to: BarInterval.w1,
      );

      expect(weekly, hasLength(1));
      expect(weekly.single.date, DateTime.utc(2024, 3, 11));
      expect(weekly.single.open, 100, reason: 'first open');
      expect(weekly.single.high, 120, reason: 'highest high');
      expect(weekly.single.low, 90, reason: 'lowest low');
      expect(weekly.single.close, 103, reason: 'last close');
      expect(weekly.single.volume, 150, reason: 'summed volume');
    });

    test('splits across a week boundary', () {
      final List<Candle> daily = <Candle>[
        bar('2024-03-14', 92, 101, 91, 99),
        bar('2024-03-15', 99, 104, 98, 103),
        // The following Monday starts a new bucket.
        bar('2024-03-18', 103, 108, 102, 107),
      ];

      final List<Candle> weekly = ChartSeries.aggregate(
        daily,
        from: BarInterval.d1,
        to: BarInterval.w1,
      );

      expect(weekly, hasLength(2));
      expect(weekly.first.close, 103);
      expect(weekly.last.open, 103);
      expect(weekly.last.date, DateTime.utc(2024, 3, 18));
    });

    test('returns the input unchanged for a matching interval', () {
      final List<Candle> daily = <Candle>[bar('2024-03-11', 1, 2, 0.5, 1.5)];
      expect(
        ChartSeries.aggregate(daily, from: BarInterval.d1, to: BarInterval.d1),
        same(daily),
      );
    });

    test('throws rather than silently mis-bucketing an illegal fold', () {
      expect(
        () => ChartSeries.aggregate(
          <Candle>[bar('2024-03-11', 1, 2, 0.5, 1.5)],
          from: BarInterval.h1,
          to: BarInterval.d1,
        ),
        throwsArgumentError,
      );
    });

    test('leaves volume null when no bar carries any', () {
      // The equity importer writes no volume, and a summed 0 would read as
      // "nothing traded" rather than "not published".
      final List<Candle> daily = <Candle>[
        bar('2024-03-11', 100, 110, 95, 105),
        bar('2024-03-12', 105, 120, 100, 118),
      ];
      final List<Candle> weekly = ChartSeries.aggregate(
        daily,
        from: BarInterval.d1,
        to: BarInterval.w1,
      );
      expect(weekly.single.volume, isNull);
    });
  });

  group('ChartSeries.heikinAshi', () {
    test('first bar seeds haOpen from the raw open and close', () {
      final List<Candle> ha = ChartSeries.heikinAshi(<Candle>[
        bar('2024-03-11', 100, 110, 90, 106),
      ]);
      expect(ha.single.open, (100 + 106) / 2);
      expect(ha.single.close, (100 + 110 + 90 + 106) / 4);
    });

    test('high and low always contain the derived body', () {
      final List<Candle> raw = <Candle>[
        bar('2024-03-11', 100, 110, 90, 106),
        bar('2024-03-12', 106, 112, 104, 109),
        bar('2024-03-13', 109, 111, 80, 85),
      ];
      for (final Candle c in ChartSeries.heikinAshi(raw)) {
        expect(c.high, greaterThanOrEqualTo(c.open));
        expect(c.high, greaterThanOrEqualTo(c.close));
        expect(c.low, lessThanOrEqualTo(c.open));
        expect(c.low, lessThanOrEqualTo(c.close));
      }
    });

    test('preserves length and dates', () {
      final List<Candle> raw = <Candle>[
        bar('2024-03-11', 100, 110, 90, 106),
        bar('2024-03-12', 106, 112, 104, 109),
      ];
      final List<Candle> ha = ChartSeries.heikinAshi(raw);
      expect(ha, hasLength(raw.length));
      expect(ha.map((Candle c) => c.date), raw.map((Candle c) => c.date));
    });
  });
}
