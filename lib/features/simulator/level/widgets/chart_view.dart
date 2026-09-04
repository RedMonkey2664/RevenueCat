import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../engine/candle_model.dart';
import '../../engine/indicators.dart';

/// The Simulator's candlestick chart.
///
/// Real chrome only (DESIGN.md): candlesticks on one timeframe, plus the
/// replay cursor. Everything else on the console — other chart types,
/// timeframes, indicators, drawing tools — is dummy chrome added in Phase 7.
///
/// Blind mode (ENGINE.md §3) is enforced here, not merely styled: when
/// [blindMode] is on, the y-axis is rebased to an index of 100 at the level's
/// first close and the x-axis counts simulation days. No absolute price and no
/// real date reaches the screen, so the asset cannot be inferred from the axes.
class ChartView extends StatelessWidget {
  const ChartView({
    required this.candles,
    required this.baselinePrice,
    required this.blindMode,
    this.showSma = false,
    this.windowSize = 70,
    super.key,
  });

  /// Candles revealed so far. The chart never draws the future.
  final List<Candle> candles;

  /// The level's first close, used as the 100 index base in blind mode.
  final double baselinePrice;

  final bool blindMode;

  /// Draws the SMA(20) overlay. Real, per DESIGN.md's real/dummy map.
  final bool showSma;

  /// How many candles stay on screen; older ones scroll off the left.
  final int windowSize;

  double _scale(double price) =>
      blindMode ? price / baselinePrice * 100 : price;

  @override
  Widget build(BuildContext context) {
    if (candles.isEmpty) {
      return const SizedBox.expand();
    }

    // fl_chart lays its axis labels out in a Flex sized to the chart. On a
    // short chart — the Debrief's review pane, or the play chart with the RSI
    // panel open — four labels do not fit and fl_chart itself overflows. Label
    // density therefore has to follow the height it is actually given.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          _build(context, constraints.maxHeight),
    );
  }

  Widget _build(BuildContext context, double availableHeight) {
    final int divisions = availableHeight >= 260
        ? 4
        : availableHeight >= 170
            ? 3
            : 2;

    // Below this the axis labels alone are taller than the plot, and
    // fl_chart's own title Flex overflows. Dropping them keeps the candles
    // readable instead of hiding them behind a broken axis.
    final bool showAxisLabels = availableHeight >= 120;
    final double leftReserved = showAxisLabels ? 48 : 0;
    final double bottomReserved = showAxisLabels ? 22 : 0;

    final int firstVisible =
        candles.length > windowSize ? candles.length - windowSize : 0;
    final List<Candle> visible = candles.sublist(firstVisible);

    final List<CandlestickSpot> spots = <CandlestickSpot>[
      for (int i = 0; i < visible.length; i++)
        CandlestickSpot(
          x: (firstVisible + i).toDouble(),
          open: _scale(visible[i].open),
          high: _scale(visible[i].high),
          low: _scale(visible[i].low),
          close: _scale(visible[i].close),
        ),
    ];

    double minY = spots.first.low;
    double maxY = spots.first.high;
    for (final CandlestickSpot spot in spots) {
      minY = spot.low < minY ? spot.low : minY;
      maxY = spot.high > maxY ? spot.high : maxY;
    }
    final double padding = ((maxY - minY) * 0.08).clamp(0.01, double.infinity);
    minY -= padding;
    maxY += padding;

    // The window grows with the run rather than reserving all 70 slots from
    // candle one, which left the first minute of play as a few candles
    // huddled against a mostly empty pane. It still stops growing at
    // windowSize, after which older candles scroll off instead.
    const int minWindow = 26;
    final int activeWindow = candles.length <= minWindow
        ? minWindow
        : (candles.length < windowSize ? candles.length + 4 : windowSize);
    final double maxX = (firstVisible + activeWindow - 1).toDouble();
    final double lastX = (candles.length - 1).toDouble();

    // The SMA is computed over the FULL revealed history, not just the
    // on-screen window: a moving average restarted at the left edge of the
    // viewport would be a different, wrong line.
    final List<double?> sma = showSma
        ? simpleMovingAverage(
            <double>[for (final Candle c in candles) _scale(c.close)],
            20,
          )
        : const <double?>[];

    final List<FlSpot> smaSpots = <FlSpot>[
      if (showSma)
        for (int i = firstVisible; i < candles.length; i++)
          if (sma[i] != null) FlSpot(i.toDouble(), sma[i]!),
    ];

    final Widget candlestick = CandlestickChart(
      // No entry animation: at 4x a tween per candle turns fast-forward into
      // mush. The replay's motion comes from new candles, not from lerping.
      duration: Duration.zero,
      CandlestickChartData(
        candlestickSpots: spots,
        minX: firstVisible.toDouble(),
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        backgroundColor: Colors.transparent,
        candlestickTouchData: CandlestickTouchData(enabled: false),
        candlestickPainter: DefaultCandlestickPainter(
          candlestickStyleProvider: (CandlestickSpot spot, int index) {
            final Color color =
                spot.close >= spot.open ? AppColors.up : AppColors.down;
            return CandlestickStyle(
              lineColor: color,
              lineWidth: 1,
              bodyStrokeColor: color,
              bodyStrokeWidth: 0,
              bodyFillColor: color,
              bodyWidth: _bodyWidthFor(windowSize),
              bodyRadius: 0,
            );
          },
        ),
        rangeAnnotations: RangeAnnotations(
          verticalRangeAnnotations: <VerticalRangeAnnotation>[
            // The replay cursor: the accent colour's one job on this screen.
            // It sits just AHEAD of the newest candle rather than on top of
            // it — fl_chart paints range annotations over the candles, and a
            // band centred on the last bar hid the one bar the player is
            // reacting to.
            VerticalRangeAnnotation(
              x1: lastX + 0.25,
              x2: lastX + 0.75,
              color: AppColors.accent.withValues(alpha: 0.22),
            ),
          ],
        ),
        gridData: FlGridData(
          drawVerticalLine: true,
          horizontalInterval: (maxY - minY) / divisions,
          verticalInterval: (activeWindow / 5).floorToDouble(),
          getDrawingHorizontalLine: (double value) => const FlLine(
            color: AppColors.border,
            strokeWidth: 0.4,
          ),
          getDrawingVerticalLine: (double value) => const FlLine(
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
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: showAxisLabels,
              reservedSize: leftReserved,
              interval: (maxY - minY) / divisions,
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value <= meta.min || value >= meta.max) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: Text(
                    value.toStringAsFixed(blindMode ? 1 : 0),
                    textAlign: TextAlign.right,
                    style: AppText.mono(
                      size: 9,
                      color: AppColors.textFaint,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: showAxisLabels,
              reservedSize: bottomReserved,
              interval: (activeWindow / 5).floorToDouble(),
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value < 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    // Relative day counter only — never a real date.
                    'D${value.toInt() + 1}',
                    style: AppText.mono(size: 9, color: AppColors.textFaint),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    if (!showSma) return candlestick;

    return Stack(
      children: <Widget>[
        candlestick,
        _smaOverlay(
          spots: smaSpots,
          minX: firstVisible.toDouble(),
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          leftReserved: leftReserved,
          bottomReserved: bottomReserved,
        ),
      ],
    );
  }

  /// The SMA rides on a second chart stacked over the candles, because
  /// fl_chart's candlestick chart cannot host line series itself. Both charts
  /// are given identical bounds AND identical reserved title sizes, so their
  /// plot areas line up exactly — without that the line would sit a few
  /// pixels off the candles it describes.
  Widget _smaOverlay({
    required List<FlSpot> spots,
    required double minX,
    required double maxX,
    required double minY,
    required double maxY,
    required double leftReserved,
    required double bottomReserved,
  }) {
    return LineChart(
      duration: Duration.zero,
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        backgroundColor: Colors.transparent,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          // Same reserved sizes as the candlestick chart, drawing nothing.
          // If these drift apart the average sits off the candles it
          // describes, so they are passed in rather than duplicated.
          // Reserve the same gutters, but draw NOTHING in them. Without an
          // empty getTitlesWidget fl_chart renders its own default numeric
          // labels, which stacked a second, differently-styled and
          // differently-spaced axis on top of the candlestick chart's.
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: leftReserved > 0,
              reservedSize: leftReserved,
              getTitlesWidget: _noTitle,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: bottomReserved > 0,
              reservedSize: bottomReserved,
              getTitlesWidget: _noTitle,
            ),
          ),
        ),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: spots,
            isCurved: false,
            barWidth: 1.4,
            color: AppColors.simulatedBadge,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  static Widget _noTitle(double value, TitleMeta meta) =>
      const SizedBox.shrink();

  static double _bodyWidthFor(int windowSize) {
    if (windowSize <= 40) return 6;
    if (windowSize <= 80) return 4;
    return 3;
  }
}
