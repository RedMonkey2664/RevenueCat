import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart';

import '../../simulator/engine/candle_model.dart';
import 'chart_types.dart';

/// Which slice of the series is on screen, and how the price axis is scaled.
///
/// Held as fractional bar indices rather than pixels so the view survives a
/// resize, a rotation and a timeframe change without jumping.
@immutable
class ChartViewport {
  const ChartViewport({
    required this.firstIndex,
    required this.barsVisible,
    this.manualRange,
  });

  /// Leftmost bar index, fractional so panning is smooth between bars.
  final double firstIndex;

  /// How many bars fit across the plot width.
  final double barsVisible;

  /// Price-axis range in *axis space* (see [PriceAxis]), or null to autoscale
  /// to the visible bars. Set by dragging the price gutter; cleared by the
  /// autoscale button.
  final ({double min, double max})? manualRange;

  bool get isAutoscaled => manualRange == null;

  double get lastIndex => firstIndex + barsVisible;

  static const double minBarsVisible = 12;
  static const double maxBarsVisible = 1500;

  /// Bars of empty space allowed past the newest bar, so the last candle is
  /// never jammed against the price gutter. TradingView calls this the right
  /// margin; it is also what leaves room for the replay cursor.
  static const double rightPadBars = 6;

  /// A sensible opening view: the most recent [preferred] bars.
  factory ChartViewport.initial(int barCount, {double preferred = 90}) {
    final double visible = barCount <= 0
        ? preferred
        : math.min(preferred, math.max(minBarsVisible, barCount.toDouble()));
    return ChartViewport(
      firstIndex: math.max(0, barCount - visible),
      barsVisible: visible,
    );
  }

  ChartViewport copyWith({
    double? firstIndex,
    double? barsVisible,
    ({double min, double max})? manualRange,
    bool clearManualRange = false,
  }) {
    return ChartViewport(
      firstIndex: firstIndex ?? this.firstIndex,
      barsVisible: barsVisible ?? this.barsVisible,
      manualRange:
          clearManualRange ? null : (manualRange ?? this.manualRange),
    );
  }

  /// Slides the view by [deltaBars], keeping it inside the series.
  ChartViewport pannedBy(double deltaBars, int barCount) =>
      copyWith(firstIndex: firstIndex + deltaBars).clamped(barCount);

  /// Zooms by [factor] (>1 zooms out) about the bar under [focalFraction],
  /// where 0 is the left edge of the plot and 1 the right.
  ///
  /// Anchoring on the focal point is what makes a pinch feel like it is
  /// grabbing the chart rather than the scrollbar.
  ChartViewport zoomedBy(
    double factor,
    double focalFraction,
    int barCount,
  ) {
    final double next =
        (barsVisible * factor).clamp(minBarsVisible, maxBarsVisible);
    final double focalIndex = firstIndex + barsVisible * focalFraction;
    return copyWith(
      firstIndex: focalIndex - next * focalFraction,
      barsVisible: next,
    ).clamped(barCount);
  }

  /// Keeps at least a few bars on screen at either extreme.
  ///
  /// Deliberately permissive: the user may pan a little past both ends, which
  /// is how every real charting tool behaves and what makes the right margin
  /// possible. What it will not allow is scrolling the series entirely out of
  /// view.
  ChartViewport clamped(int barCount) {
    if (barCount <= 0) return this;
    final double minFirst = -barsVisible * 0.5;
    final double maxFirst = barCount - barsVisible + rightPadBars;
    return copyWith(
      firstIndex: firstIndex.clamp(
        minFirst,
        math.max(minFirst, maxFirst),
      ),
    );
  }

  /// The integer bar indices actually on screen, clipped to the series.
  ({int first, int last}) visibleRange(int barCount) {
    final int first = firstIndex.floor().clamp(0, math.max(0, barCount - 1));
    final int last =
        lastIndex.ceil().clamp(0, math.max(0, barCount - 1));
    return (first: first, last: last);
  }
}

/// Maps prices to the value actually plotted on the y-axis.
///
/// Three modes share one interface so the painters never branch on scale —
/// they plot axis values and let this convert at the edges.
@immutable
class PriceAxis {
  const PriceAxis({required this.scale, required this.basePrice});

  final PriceScale scale;

  /// Reference close for [PriceScale.percent]. Ignored otherwise.
  final double basePrice;

  /// Price → axis value.
  double toAxis(double price) {
    switch (scale) {
      case PriceScale.linear:
        return price;
      case PriceScale.percent:
        if (basePrice <= 0) return 0;
        return (price / basePrice - 1) * 100;
      case PriceScale.logarithmic:
        // A non-positive price has no logarithm. Real series never contain
        // one, but a synthetic or malformed feed might, and silently plotting
        // it at the axis floor beats throwing mid-paint.
        return price <= 0 ? _logFloor : math.log(price);
    }
  }

  /// Axis value → price, for gutter labels and crosshair readouts.
  double toPrice(double axisValue) {
    switch (scale) {
      case PriceScale.linear:
        return axisValue;
      case PriceScale.percent:
        return basePrice * (1 + axisValue / 100);
      case PriceScale.logarithmic:
        return math.exp(axisValue);
    }
  }

  static const double _logFloor = -30;
}

/// Everything a painter needs to turn a bar index and a price into a point.
///
/// Constructed once per paint and handed to every pane so the price pane, the
/// indicator panes and the crosshair cannot drift out of alignment — the bug
/// the old two-stacked-fl_charts SMA overlay had to work around by hand.
@immutable
class ChartGeometry {
  const ChartGeometry({
    required this.plot,
    required this.viewport,
    required this.axis,
    required this.axisMin,
    required this.axisMax,
    required this.barCount,
  });

  /// The plot rectangle, excluding the price gutter and time axis.
  final Rect plot;

  final ChartViewport viewport;
  final PriceAxis axis;

  /// Axis-space bounds actually drawn.
  final double axisMin;
  final double axisMax;

  final int barCount;

  double get barWidth => plot.width / viewport.barsVisible;

  /// Candle body width, leaving a gap between bars until they get too tight
  /// to have one.
  double get bodyWidth => math.max(1, barWidth * 0.68);

  /// Centre x of bar [index].
  double xForIndex(double index) =>
      plot.left + (index - viewport.firstIndex + 0.5) * barWidth;

  /// Fractional bar index under [x].
  double indexForX(double x) =>
      viewport.firstIndex + (x - plot.left) / barWidth - 0.5;

  /// Nearest real bar index under [x], or null when [x] is off the series.
  int? barIndexAt(double x) {
    if (barCount == 0) return null;
    final int i = indexForX(x).round();
    if (i < 0 || i >= barCount) return null;
    return i;
  }

  double yForAxis(double axisValue) {
    final double span = axisMax - axisMin;
    if (span <= 0) return plot.center.dy;
    return plot.bottom - (axisValue - axisMin) / span * plot.height;
  }

  double yForPrice(double price) => yForAxis(axis.toAxis(price));

  double axisForY(double y) {
    final double span = axisMax - axisMin;
    return axisMin + (plot.bottom - y) / plot.height * span;
  }

  double priceForY(double y) => axis.toPrice(axisForY(y));

  Offset pointFor(double index, double price) =>
      Offset(xForIndex(index), yForPrice(price));

  /// Autoscaled axis bounds over the visible slice of [bars], with headroom.
  ///
  /// Returns null when nothing is visible, which happens legitimately while
  /// the user pans past the end of the series.
  static ({double min, double max})? autoRange(
    List<Candle> bars,
    ChartViewport viewport,
    PriceAxis axis, {
    double padFraction = 0.08,
  }) {
    final ({int first, int last}) range = viewport.visibleRange(bars.length);
    if (bars.isEmpty || range.last < range.first) return null;

    double min = double.infinity;
    double max = double.negativeInfinity;
    for (int i = range.first; i <= range.last; i++) {
      final double lo = axis.toAxis(bars[i].low);
      final double hi = axis.toAxis(bars[i].high);
      if (lo < min) min = lo;
      if (hi > max) max = hi;
    }
    if (!min.isFinite || !max.isFinite) return null;

    // A dead-flat window would otherwise collapse to a zero-height axis.
    if (max - min < 1e-9) {
      final double pad = max.abs() < 1e-9 ? 1 : max.abs() * 0.01;
      return (min: min - pad, max: max + pad);
    }

    final double pad = (max - min) * padFraction;
    return (min: min - pad, max: max + pad);
  }
}
