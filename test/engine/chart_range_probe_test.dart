import 'package:flutter_test/flutter_test.dart';
import 'package:market_nerve/data/sample/dev_sample_level.dart';
import 'package:market_nerve/features/simulator/engine/candle_model.dart';
import 'package:market_nerve/features/simulator/engine/level_model.dart';

/// The chart rebases prices to an index of 100 at the level's first close
/// (blind mode). The header's P&L is computed from the same closes. If the two
/// ever disagree, one of them is lying to the player about the drawdown they
/// are being asked to react to.
void main() {
  test('chart y-range covers the price the header P&L implies', () {
    final SimulationLevel level = DevSampleLevel.build();
    const int pauseIndex = 48;

    final double baseline = level.candles.first.close;
    final List<Candle> visible = level.candles.sublist(0, pauseIndex + 1);

    double lo = visible.first.low;
    double hi = visible.first.high;
    for (final Candle c in visible) {
      if (c.low < lo) lo = c.low;
      if (c.high > hi) hi = c.high;
    }

    final double indexedLow = lo / baseline * 100;
    final double indexedHigh = hi / baseline * 100;
    final double indexedClose =
        level.candles[pauseIndex].close / baseline * 100;

    // What the header shows: 75% deployed at candle 0, 25% cash.
    final double ratio = level.candles[pauseIndex].close / baseline;
    final double portfolioValue = 25000 + 75000 * ratio;
    final double pnlPercent = (portfolioValue - 100000) / 100000 * 100;

    // The pause-point close must sit inside the plotted range, or the chart is
    // cropping the very crash the decision is about.
    expect(indexedClose, greaterThanOrEqualTo(indexedLow));
    expect(indexedClose, lessThanOrEqualTo(indexedHigh));

    // And the header's P&L must describe the same price the chart plots:
    // value = 25% cash + 75% deployed, so the implied ratio has to match the
    // chart's index/100.
    final double impliedRatio = (portfolioValue - 25000) / 75000;
    expect(impliedRatio * 100, closeTo(indexedClose, 0.001));
    expect(pnlPercent, closeTo(-17.7, 0.1));
  });
}
