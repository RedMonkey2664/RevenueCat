import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_nerve/data/sample/dev_sample_level.dart';
import 'package:market_nerve/features/simulator/engine/candle_model.dart';
import 'package:market_nerve/features/simulator/engine/level_model.dart';
import 'package:market_nerve/features/simulator/level/widgets/chart_view.dart';

/// Reads the chart's real axis bounds instead of trusting the eye.
///
/// A y-range that does not span every plotted candle silently crops candles —
/// and with `FlClipData.all()` they vanish rather than overflow, so the bug
/// looks like a gap in the series rather than an error.
void main() {
  CandlestickChartData dataFrom(WidgetTester tester) {
    final CandlestickChart chart = tester.widget<CandlestickChart>(
      find.byType(CandlestickChart),
    );
    return chart.data;
  }

  Future<void> pumpChart(
    WidgetTester tester,
    List<Candle> candles,
    double baseline,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: ChartView(
              candles: candles,
              baselinePrice: baseline,
              blindMode: true,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('y-range spans every plotted candle through the crash', (
    WidgetTester tester,
  ) async {
    final SimulationLevel level = DevSampleLevel.build();
    final double baseline = level.candles.first.close;

    // Day 63: past the crash bottom and into the bounce — the frame where a
    // cropped range would swallow the deepest candles.
    final List<Candle> candles = level.candles.sublist(0, 63);
    await pumpChart(tester, candles, baseline);

    final CandlestickChartData data = dataFrom(tester);

    double lowest = double.infinity;
    double highest = double.negativeInfinity;
    for (final CandlestickSpot spot in data.candlestickSpots) {
      if (spot.low < lowest) lowest = spot.low;
      if (spot.high > highest) highest = spot.high;
    }

    expect(
      data.candlestickSpots,
      hasLength(63),
      reason: 'every revealed candle must be handed to the chart',
    );
    expect(
      data.minY,
      lessThanOrEqualTo(lowest),
      reason: 'minY crops the bottom of the crash',
    );
    expect(
      data.maxY,
      greaterThanOrEqualTo(highest),
      reason: 'maxY crops the top of the run-up',
    );
  });

  testWidgets('x-range spans every plotted candle', (
    WidgetTester tester,
  ) async {
    final SimulationLevel level = DevSampleLevel.build();
    final List<Candle> candles = level.candles.sublist(0, 63);
    await pumpChart(tester, candles, level.candles.first.close);

    final CandlestickChartData data = dataFrom(tester);
    final double lastX = data.candlestickSpots.last.x;

    expect(data.minX, lessThanOrEqualTo(data.candlestickSpots.first.x));
    expect(
      data.maxX,
      greaterThanOrEqualTo(lastX),
      reason: 'the newest candle must be inside the plotted x-window',
    );
  });

  testWidgets('older candles scroll off once past the window size', (
    WidgetTester tester,
  ) async {
    final SimulationLevel level = DevSampleLevel.build();
    final List<Candle> candles = level.candles.sublist(0, 100);
    await pumpChart(tester, candles, level.candles.first.close);

    final CandlestickChartData data = dataFrom(tester);
    expect(data.candlestickSpots, hasLength(70));
    expect(data.candlestickSpots.first.x, 30);
    expect(data.candlestickSpots.last.x, 99);
  });
}
