import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../engine/candle_model.dart';
import '../../engine/indicators.dart';

/// RSI(14) in its own band under the price chart.
///
/// It gets a separate panel rather than an overlay because RSI is bounded
/// 0–100 and shares no scale with price. Drawing it over the candles would
/// mean rescaling it into the price range, which is what a lot of toy charts
/// do and what makes the 30/70 lines meaningless.
class RsiPanel extends StatelessWidget {
  const RsiPanel({
    required this.candles,
    this.windowSize = 70,
    super.key,
  });

  final List<Candle> candles;
  final int windowSize;

  static const double height = 74;

  @override
  Widget build(BuildContext context) {
    if (candles.length < 2) return const SizedBox(height: height);

    final int firstVisible =
        candles.length > windowSize ? candles.length - windowSize : 0;

    // Computed over the whole revealed series: Wilder's smoothing is
    // path-dependent, so restarting it at the viewport edge would give a
    // different and wrong value.
    final List<double?> rsi = relativeStrengthIndex(
      <double>[for (final Candle c in candles) c.close],
      14,
    );

    final List<FlSpot> spots = <FlSpot>[
      for (int i = firstVisible; i < candles.length; i++)
        if (rsi[i] != null) FlSpot(i.toDouble(), rsi[i]!),
    ];

    final double maxX = (firstVisible + windowSize - 1).toDouble();

    return SizedBox(
      height: height,
      child: Stack(
        children: <Widget>[
          LineChart(
            duration: Duration.zero,
            LineChartData(
              minX: firstVisible.toDouble(),
              maxX: maxX,
              minY: 0,
              maxY: 100,
              clipData: const FlClipData.all(),
              backgroundColor: Colors.transparent,
              lineTouchData: const LineTouchData(enabled: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: 50,
                getDrawingHorizontalLine: (double value) => const FlLine(
                  color: AppColors.border,
                  strokeWidth: 0.4,
                ),
              ),
              borderData: FlBorderData(
                border: const Border(
                  left: BorderSide(color: AppColors.border),
                  bottom: BorderSide(color: AppColors.border),
                ),
              ),
              // The conventional 30 / 70 bands.
              extraLinesData: ExtraLinesData(
                horizontalLines: <HorizontalLine>[
                  HorizontalLine(
                    y: 70,
                    color: AppColors.down.withValues(alpha: 0.35),
                    strokeWidth: 0.8,
                    dashArray: <int>[4, 3],
                  ),
                  HorizontalLine(
                    y: 30,
                    color: AppColors.up.withValues(alpha: 0.35),
                    strokeWidth: 0.8,
                    dashArray: <int>[4, 3],
                  ),
                ],
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                bottomTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 22),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    interval: 50,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      if (value != 30 && value != 70 && value != 50) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: Text(
                          value.toInt().toString(),
                          style: AppText.mono(
                            size: 8,
                            color: AppColors.textFaint,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: <LineChartBarData>[
                LineChartBarData(
                  spots: spots,
                  isCurved: false,
                  barWidth: 1.2,
                  color: AppColors.accent,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
          Positioned(
            left: 52,
            top: 2,
            child: Text('RSI 14', style: AppText.label()),
          ),
        ],
      ),
    );
  }
}
