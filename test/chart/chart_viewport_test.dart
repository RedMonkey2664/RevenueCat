import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:market_nerve/core/market/candle.dart';
import 'package:market_nerve/features/chart/model/chart_types.dart';
import 'package:market_nerve/features/chart/model/chart_viewport.dart';

List<Candle> series(int n, {double start = 100}) => <Candle>[
      for (int i = 0; i < n; i++)
        Candle(
          date: DateTime.utc(2024).add(Duration(days: i)),
          open: start + i,
          high: start + i + 2,
          low: start + i - 2,
          close: start + i + 1,
        ),
    ];

void main() {
  group('ChartViewport', () {
    test('opens on the most recent bars', () {
      final ChartViewport v = ChartViewport.initial(500);
      expect(v.barsVisible, 90);
      expect(v.firstIndex, 410);
      expect(v.lastIndex, 500);
    });

    test('a series shorter than the preferred window is shown whole', () {
      final ChartViewport v = ChartViewport.initial(30);
      expect(v.barsVisible, 30);
      expect(v.firstIndex, 0);
    });

    test('zooming holds the focal bar in place', () {
      const ChartViewport v =
          ChartViewport(firstIndex: 100, barsVisible: 100);

      // Focal point at the middle of the plot is bar 150.
      final ChartViewport zoomed = v.zoomedBy(0.5, 0.5, 1000);

      expect(zoomed.barsVisible, 50);
      expect(
        zoomed.firstIndex + zoomed.barsVisible * 0.5,
        closeTo(150, 0.001),
        reason: 'the bar under the finger must not move',
      );
    });

    test('zoom is clamped at both extremes', () {
      const ChartViewport v = ChartViewport(firstIndex: 0, barsVisible: 100);
      expect(v.zoomedBy(0.001, 0.5, 1000).barsVisible,
          ChartViewport.minBarsVisible);
      expect(v.zoomedBy(1000, 0.5, 100000).barsVisible,
          ChartViewport.maxBarsVisible);
    });

    test('panning cannot push the series off screen', () {
      const ChartViewport v = ChartViewport(firstIndex: 0, barsVisible: 50);

      final ChartViewport hardLeft = v.pannedBy(-100000, 500);
      expect(hardLeft.firstIndex, greaterThanOrEqualTo(-v.barsVisible));

      final ChartViewport hardRight = v.pannedBy(100000, 500);
      expect(
        hardRight.firstIndex,
        lessThanOrEqualTo(500 - 50 + ChartViewport.rightPadBars),
      );
    });

    test('visibleRange is clipped to the series', () {
      const ChartViewport v = ChartViewport(firstIndex: -10, barsVisible: 50);
      final ({int first, int last}) r = v.visibleRange(20);
      expect(r.first, 0);
      expect(r.last, 19);
    });
  });

  group('PriceAxis', () {
    test('linear is the identity', () {
      const PriceAxis a =
          PriceAxis(scale: PriceScale.linear, basePrice: 100);
      expect(a.toAxis(250), 250);
      expect(a.toPrice(250), 250);
    });

    test('percent rebases against basePrice and round-trips', () {
      const PriceAxis a =
          PriceAxis(scale: PriceScale.percent, basePrice: 200);
      expect(a.toAxis(200), 0);
      expect(a.toAxis(250), closeTo(25, 1e-9));
      expect(a.toAxis(100), closeTo(-50, 1e-9));
      expect(a.toPrice(a.toAxis(137)), closeTo(137, 1e-9));
    });

    test('log round-trips and survives a non-positive price', () {
      const PriceAxis a =
          PriceAxis(scale: PriceScale.logarithmic, basePrice: 1);
      expect(a.toPrice(a.toAxis(4321)), closeTo(4321, 1e-6));
      // A malformed feed must not throw mid-paint.
      expect(a.toAxis(0), lessThan(-1));
      expect(a.toAxis(-5), lessThan(-1));
    });
  });

  group('ChartGeometry', () {
    const PriceAxis axis =
        PriceAxis(scale: PriceScale.linear, basePrice: 100);

    ChartGeometry geometry({
      double firstIndex = 0,
      double barsVisible = 10,
      double min = 0,
      double max = 100,
      int barCount = 10,
    }) {
      return ChartGeometry(
        plot: const Rect.fromLTWH(0, 0, 300, 200),
        viewport: ChartViewport(
          firstIndex: firstIndex,
          barsVisible: barsVisible,
        ),
        axis: axis,
        axisMin: min,
        axisMax: max,
        barCount: barCount,
      );
    }

    test('x and index are inverses', () {
      final ChartGeometry g = geometry();
      for (final double i in <double>[0, 3.5, 9]) {
        expect(g.indexForX(g.xForIndex(i)), closeTo(i, 1e-9));
      }
    });

    test('y and price are inverses', () {
      final ChartGeometry g = geometry();
      for (final double p in <double>[0, 42.5, 100]) {
        expect(g.priceForY(g.yForPrice(p)), closeTo(p, 1e-9));
      }
    });

    test('the axis maximum sits at the top of the plot', () {
      final ChartGeometry g = geometry();
      expect(g.yForPrice(100), closeTo(0, 1e-9));
      expect(g.yForPrice(0), closeTo(200, 1e-9));
    });

    test('barIndexAt returns null off the series', () {
      final ChartGeometry g = geometry(barCount: 10);
      expect(g.barIndexAt(g.xForIndex(4)), 4);
      expect(g.barIndexAt(g.xForIndex(-3)), isNull);
      expect(g.barIndexAt(g.xForIndex(40)), isNull);
    });

    test('a dead-flat window still gets a non-zero axis span', () {
      final List<Candle> flat = <Candle>[
        for (int i = 0; i < 5; i++)
          Candle(
            date: DateTime.utc(2024).add(Duration(days: i)),
            open: 50,
            high: 50,
            low: 50,
            close: 50,
          ),
      ];
      final ({double min, double max})? r = ChartGeometry.autoRange(
        flat,
        const ChartViewport(firstIndex: 0, barsVisible: 5),
        axis,
      );
      expect(r, isNotNull);
      expect(r!.max - r.min, greaterThan(0));
    });

    test('autoRange covers the visible highs and lows with headroom', () {
      final List<Candle> bars = series(10);
      final ({double min, double max})? r = ChartGeometry.autoRange(
        bars,
        const ChartViewport(firstIndex: 0, barsVisible: 10),
        axis,
      );
      expect(r, isNotNull);
      expect(r!.min, lessThan(bars.first.low));
      expect(r.max, greaterThan(bars.last.high));
    });
  });
}
