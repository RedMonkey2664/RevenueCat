import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../simulator/engine/candle_model.dart';
import '../model/chart_drawing.dart';
import '../model/chart_indicator.dart';
import '../model/chart_labels.dart';
import '../model/chart_layout.dart';
import '../model/chart_types.dart';
import '../model/chart_viewport.dart';

/// Paints everything that changes only when the data or the viewport changes:
/// grid, price series, indicators, drawings, axes.
///
/// The crosshair lives in a separate painter over a [RepaintBoundary] so
/// dragging a finger across the chart does not re-rasterise the candles on
/// every frame.
class ChartBasePainter extends CustomPainter {
  const ChartBasePainter({
    required this.rawBars,
    required this.drawBars,
    required this.chartType,
    required this.interval,
    required this.layout,
    required this.priceGeometry,
    required this.paneGeometries,
    required this.indicators,
    required this.labels,
    required this.drawings,
    this.pendingDrawing,
    this.selectedDrawingId,
    this.replayCursorIndex,
    this.showLastPriceLine = true,
  });

  /// The real series — drawings and the last-price tag resolve against this,
  /// never against a Heikin-Ashi transform.
  final List<Candle> rawBars;

  /// What the price pane actually draws (raw, or Heikin-Ashi).
  final List<Candle> drawBars;

  final ChartType chartType;
  final BarInterval interval;
  final ChartLayout layout;
  final ChartGeometry priceGeometry;
  final List<ChartGeometry> paneGeometries;
  final ComputedIndicators indicators;
  final ChartLabels labels;
  final List<ChartDrawing> drawings;

  /// The drawing being dragged out right now, not yet committed.
  final ChartDrawing? pendingDrawing;

  final String? selectedDrawingId;

  /// Simulator only: the accent band marking "now" in a replay.
  final int? replayCursorIndex;

  final bool showLastPriceLine;

  @override
  void paint(Canvas canvas, Size size) {
    if (drawBars.isEmpty) return;

    final List<double> priceTicks = _priceTicks();
    final List<int> timeTicks = _timeTicks();

    _paintPricePane(canvas, priceTicks, timeTicks);

    for (int i = 0; i < paneGeometries.length; i++) {
      _paintIndicatorPane(canvas, indicators.panes[i], paneGeometries[i],
          timeTicks);
    }

    _paintPriceGutter(canvas, priceTicks);
    _paintTimeAxis(canvas, timeTicks);
  }

  // ---------------------------------------------------------------- price

  void _paintPricePane(
    Canvas canvas,
    List<double> priceTicks,
    List<int> timeTicks,
  ) {
    final Rect plot = priceGeometry.plot;
    canvas.save();
    canvas.clipRect(plot);

    _paintGrid(canvas, priceGeometry, priceTicks, timeTicks);
    _paintBands(canvas);

    if (chartType.isPathStyle) {
      _paintPricePath(canvas);
    } else {
      _paintCandles(canvas);
    }

    _paintOverlayLines(canvas);
    _paintReplayCursor(canvas);
    _paintDrawings(canvas);

    canvas.restore();

    // Outside the clip so the tag may sit in the gutter.
    if (showLastPriceLine) _paintLastPriceLine(canvas);
  }

  void _paintGrid(
    Canvas canvas,
    ChartGeometry g,
    List<double> priceTicks,
    List<int> timeTicks,
  ) {
    final Paint grid = Paint()
      ..color = AppColors.border.withValues(alpha: 0.55)
      ..strokeWidth = 0.5;

    for (final double t in priceTicks) {
      final double y = g.yForAxis(g.axis.toAxis(t));
      if (y < g.plot.top || y > g.plot.bottom) continue;
      canvas.drawLine(
        Offset(g.plot.left, y),
        Offset(g.plot.right, y),
        grid,
      );
    }

    for (final int i in timeTicks) {
      final double x = g.xForIndex(i.toDouble());
      canvas.drawLine(
        Offset(x, g.plot.top),
        Offset(x, g.plot.bottom),
        grid,
      );
    }
  }

  void _paintCandles(Canvas canvas) {
    final ({int first, int last}) range =
        priceGeometry.viewport.visibleRange(drawBars.length);

    final Path upBodies = Path();
    final Path downBodies = Path();
    final Path upWicks = Path();
    final Path downWicks = Path();

    final double bodyW = priceGeometry.bodyWidth;
    // Below roughly two pixels a body is indistinguishable from its wick, so
    // the whole bar collapses to a single line — which is what a real
    // terminal does when you zoom out far enough.
    final bool bodiesVisible = bodyW >= 1.6;

    for (int i = range.first; i <= range.last; i++) {
      final Candle c = drawBars[i];
      final double x = priceGeometry.xForIndex(i.toDouble());
      final double yHigh = priceGeometry.yForPrice(c.high);
      final double yLow = priceGeometry.yForPrice(c.low);
      final double yOpen = priceGeometry.yForPrice(c.open);
      final double yClose = priceGeometry.yForPrice(c.close);

      final Path wicks = c.isUp ? upWicks : downWicks;
      wicks
        ..moveTo(x, yHigh)
        ..lineTo(x, yLow);

      if (!bodiesVisible) continue;

      final double top = math.min(yOpen, yClose);
      final double bottom = math.max(yOpen, yClose);
      final Path bodies = c.isUp ? upBodies : downBodies;
      bodies.addRect(
        Rect.fromLTRB(
          x - bodyW / 2,
          top,
          x + bodyW / 2,
          // A doji would otherwise vanish entirely.
          math.max(bottom, top + 1),
        ),
      );
    }

    final Paint upStroke = Paint()
      ..color = AppColors.up
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final Paint downStroke = Paint()
      ..color = AppColors.down
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas
      ..drawPath(upWicks, upStroke)
      ..drawPath(downWicks, downStroke)
      ..drawPath(upBodies, Paint()..color = AppColors.up)
      ..drawPath(downBodies, Paint()..color = AppColors.down);
  }

  void _paintPricePath(Canvas canvas) {
    final ({int first, int last}) range =
        priceGeometry.viewport.visibleRange(drawBars.length);

    final Path line = Path();
    bool started = false;
    for (int i = range.first; i <= range.last; i++) {
      final Offset p = Offset(
        priceGeometry.xForIndex(i.toDouble()),
        priceGeometry.yForPrice(drawBars[i].close),
      );
      if (!started) {
        line.moveTo(p.dx, p.dy);
        started = true;
      } else {
        line.lineTo(p.dx, p.dy);
      }
    }
    if (!started) return;

    if (chartType == ChartType.area) {
      final Path fill = Path.from(line)
        ..lineTo(
          priceGeometry.xForIndex(range.last.toDouble()),
          priceGeometry.plot.bottom,
        )
        ..lineTo(
          priceGeometry.xForIndex(range.first.toDouble()),
          priceGeometry.plot.bottom,
        )
        ..close();

      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              AppColors.accent.withValues(alpha: 0.28),
              AppColors.accent.withValues(alpha: 0.0),
            ],
          ).createShader(priceGeometry.plot),
      );
    }

    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.accent
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintBands(Canvas canvas) {
    for (final IndicatorBand band in indicators.bands) {
      final ({int first, int last}) range =
          priceGeometry.viewport.visibleRange(drawBars.length);

      final Path path = Path();
      bool started = false;
      for (int i = range.first; i <= range.last; i++) {
        final double? v = band.upper[i];
        if (v == null) continue;
        final Offset p = Offset(
          priceGeometry.xForIndex(i.toDouble()),
          priceGeometry.yForPrice(v),
        );
        started ? path.lineTo(p.dx, p.dy) : path.moveTo(p.dx, p.dy);
        started = true;
      }
      if (!started) continue;

      for (int i = range.last; i >= range.first; i--) {
        final double? v = band.lower[i];
        if (v == null) continue;
        path.lineTo(
          priceGeometry.xForIndex(i.toDouble()),
          priceGeometry.yForPrice(v),
        );
      }
      path.close();

      canvas.drawPath(path, Paint()..color = band.color);
    }
  }

  void _paintOverlayLines(Canvas canvas) {
    for (final IndicatorLine line in indicators.overlayLines) {
      _paintSeries(
        canvas,
        geometry: priceGeometry,
        values: line.values,
        color: line.color,
        width: line.width,
        dashed: line.dashed,
        inPriceSpace: true,
      );
    }
  }

  /// Draws one aligned value series, breaking the path wherever the data is
  /// null so a gap is never bridged by a straight line that implies values
  /// nobody computed.
  void _paintSeries(
    Canvas canvas, {
    required ChartGeometry geometry,
    required List<double?> values,
    required Color color,
    required double width,
    required bool inPriceSpace,
    bool dashed = false,
  }) {
    final ({int first, int last}) range =
        geometry.viewport.visibleRange(values.length);

    final Path path = Path();
    bool open = false;
    for (int i = range.first; i <= range.last; i++) {
      final double? v = values[i];
      if (v == null) {
        open = false;
        continue;
      }
      final double y =
          inPriceSpace ? geometry.yForPrice(v) : geometry.yForAxis(v);
      final double x = geometry.xForIndex(i.toDouble());
      if (open) {
        path.lineTo(x, y);
      } else {
        path.moveTo(x, y);
        open = true;
      }
    }

    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(dashed ? _dash(path) : path, paint);
  }

  void _paintReplayCursor(Canvas canvas) {
    final int? cursor = replayCursorIndex;
    if (cursor == null) return;

    final double x = priceGeometry.xForIndex(cursor + 0.5);
    final Rect band = Rect.fromLTRB(
      x,
      priceGeometry.plot.top,
      x + math.max(2, priceGeometry.barWidth * 0.5),
      priceGeometry.plot.bottom,
    );
    canvas.drawRect(
      band,
      Paint()..color = AppColors.accent.withValues(alpha: 0.22),
    );
  }

  void _paintLastPriceLine(Canvas canvas) {
    final int last = replayCursorIndex ?? rawBars.length - 1;
    if (last < 0 || last >= rawBars.length) return;

    final Candle c = rawBars[last];
    final double y = priceGeometry.yForPrice(c.close);
    if (y < priceGeometry.plot.top || y > priceGeometry.plot.bottom) return;

    final Color color = c.isUp ? AppColors.up : AppColors.down;

    canvas.drawPath(
      _dash(
        Path()
          ..moveTo(priceGeometry.plot.left, y)
          ..lineTo(priceGeometry.plot.right, y),
      ),
      Paint()
        ..color = color.withValues(alpha: 0.55)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke,
    );

    _paintGutterTag(
      canvas,
      y: y,
      text: labels.price(c.close),
      background: color,
      foreground: AppColors.background,
    );
  }

  // ------------------------------------------------------------ sub-panes

  void _paintIndicatorPane(
    Canvas canvas,
    IndicatorPane pane,
    ChartGeometry g,
    List<int> timeTicks,
  ) {
    canvas.save();
    canvas.clipRect(g.plot);

    final Paint grid = Paint()
      ..color = AppColors.border.withValues(alpha: 0.4)
      ..strokeWidth = 0.5;
    for (final int i in timeTicks) {
      final double x = g.xForIndex(i.toDouble());
      canvas.drawLine(
        Offset(x, g.plot.top),
        Offset(x, g.plot.bottom),
        grid,
      );
    }

    for (final IndicatorGuide guide in pane.guides) {
      final double y = g.yForAxis(guide.value);
      canvas.drawPath(
        _dash(
          Path()
            ..moveTo(g.plot.left, y)
            ..lineTo(g.plot.right, y),
        ),
        Paint()
          ..color = AppColors.borderStrong
          ..strokeWidth = 0.6
          ..style = PaintingStyle.stroke,
      );
    }

    if (pane.zeroLine) {
      final double y = g.yForAxis(0);
      canvas.drawLine(
        Offset(g.plot.left, y),
        Offset(g.plot.right, y),
        Paint()
          ..color = AppColors.borderStrong
          ..strokeWidth = 0.6,
      );
    }

    final List<double?>? histogram = pane.histogram;
    if (histogram != null) {
      final ({int first, int last}) range =
          g.viewport.visibleRange(histogram.length);
      final double w = math.max(1, g.barWidth * 0.6);
      final double baseline =
          g.yForAxis(pane.zeroLine ? 0 : math.max(0, g.axisMin));

      for (int i = range.first; i <= range.last; i++) {
        final double? v = histogram[i];
        if (v == null) continue;
        final double x = g.xForIndex(i.toDouble());
        final double y = g.yForAxis(v);
        final Color color = pane.histogramColors != null &&
                i < pane.histogramColors!.length
            ? pane.histogramColors![i]
            : AppColors.accent.withValues(alpha: 0.5);
        canvas.drawRect(
          Rect.fromLTRB(
            x - w / 2,
            math.min(y, baseline),
            x + w / 2,
            math.max(y, baseline),
          ),
          Paint()..color = color,
        );
      }
    }

    for (final IndicatorLine line in pane.lines) {
      _paintSeries(
        canvas,
        geometry: g,
        values: line.values,
        color: line.color,
        width: line.width,
        dashed: line.dashed,
        inPriceSpace: false,
      );
    }

    canvas.restore();

    // Pane border and title, drawn outside the clip.
    canvas.drawLine(
      Offset(g.plot.left, g.plot.top),
      Offset(g.plot.right, g.plot.top),
      Paint()
        ..color = AppColors.border
        ..strokeWidth = 0.5,
    );

    _text(
      canvas,
      pane.label,
      Offset(g.plot.left + 6, g.plot.top + 4),
      AppText.label(color: AppColors.textFaint, size: 9),
    );

    for (final IndicatorGuide guide in pane.guides) {
      _text(
        canvas,
        guide.label,
        Offset(g.plot.right + 6, g.yForAxis(guide.value) - 6),
        AppText.mono(size: 9, color: AppColors.textFaint),
      );
    }

    if (pane.guides.isEmpty) {
      _text(
        canvas,
        pane.spec.kind == IndicatorKind.volume
            ? formatVolume(g.axisMax)
            : formatPrice(g.axisMax),
        Offset(g.plot.right + 6, g.plot.top + 2),
        AppText.mono(size: 9, color: AppColors.textFaint),
      );
    }
  }

  // ---------------------------------------------------------------- axes

  /// Gridline positions, always returned as prices.
  ///
  /// Which space the "nice" numbers are chosen in depends on the scale:
  ///
  ///   • percent — nice values in AXIS space, so the lines land on −10%, −20%
  ///     and so on. Choosing them in price space would put them at arbitrary
  ///     percentages.
  ///   • linear and log — nice values in PRICE space. On a log axis they then
  ///     land unevenly on screen, which is exactly what a log scale should
  ///     look like; picking evenly spaced axis values there would produce
  ///     gridlines at 4.61 and 4.83.
  List<double> _priceTicks() {
    final PriceAxis axis = priceGeometry.axis;

    if (axis.scale == PriceScale.percent) {
      return <double>[
        for (final double v
            in niceTicks(priceGeometry.axisMin, priceGeometry.axisMax))
          axis.toPrice(v),
      ];
    }

    final double lo = axis.toPrice(priceGeometry.axisMin);
    final double hi = axis.toPrice(priceGeometry.axisMax);
    return niceTicks(math.min(lo, hi), math.max(lo, hi));
  }

  List<int> _timeTicks() {
    if (drawBars.isEmpty) return const <int>[];

    final ({int first, int last}) range =
        priceGeometry.viewport.visibleRange(drawBars.length);

    // One label per ~78px keeps them from colliding at any zoom level.
    final double perLabel = 78;
    final int stride = math.max(
      1,
      (perLabel / math.max(0.001, priceGeometry.barWidth)).ceil(),
    );

    final List<int> out = <int>[];
    for (int i = range.first; i <= range.last; i += stride) {
      out.add(i);
    }
    return out;
  }

  void _paintPriceGutter(Canvas canvas, List<double> ticks) {
    canvas.drawLine(
      Offset(priceGeometry.plot.right, 0),
      Offset(priceGeometry.plot.right, layout.size.height),
      Paint()
        ..color = AppColors.border
        ..strokeWidth = 0.5,
    );

    for (final double price in ticks) {
      final double y = priceGeometry.yForPrice(price);
      if (y < priceGeometry.plot.top + 8 ||
          y > priceGeometry.plot.bottom - 8) {
        continue;
      }
      _text(
        canvas,
        labels.price(price),
        Offset(priceGeometry.plot.right + 6, y - 6),
        AppText.mono(size: 9, color: AppColors.textFaint),
      );
    }
  }

  void _paintTimeAxis(Canvas canvas, List<int> ticks) {
    final Rect axis = layout.timeAxis;
    canvas.drawLine(
      Offset(0, axis.top),
      Offset(axis.right, axis.top),
      Paint()
        ..color = AppColors.border
        ..strokeWidth = 0.5,
    );

    for (final int i in ticks) {
      if (i < 0 || i >= drawBars.length) continue;
      final double x = priceGeometry.xForIndex(i.toDouble());
      if (x < 12 || x > axis.right - 12) continue;
      _text(
        canvas,
        labels.time(drawBars[i].date, i, interval),
        Offset(x, axis.top + 5),
        AppText.mono(size: 9, color: AppColors.textFaint),
        centerOn: true,
      );
    }
  }

  void _paintGutterTag(
    Canvas canvas, {
    required double y,
    required String text,
    required Color background,
    required Color foreground,
  }) {
    final TextPainter tp = _layoutText(
      text,
      AppText.mono(size: 9, weight: FontWeight.w700, color: foreground),
    );
    final Rect box = Rect.fromLTWH(
      priceGeometry.plot.right + 2,
      y - 8,
      math.min(tp.width + 8, layout.gutterWidth - 4),
      16,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(2)),
      Paint()..color = background,
    );
    tp.paint(canvas, Offset(box.left + 4, box.top + 3));
  }

  // ------------------------------------------------------------- drawings

  void _paintDrawings(Canvas canvas) {
    for (final ChartDrawing d in drawings) {
      _paintDrawing(canvas, d, selected: d.id == selectedDrawingId);
    }
    final ChartDrawing? pending = pendingDrawing;
    if (pending != null) _paintDrawing(canvas, pending, selected: true);
  }

  void _paintDrawing(
    Canvas canvas,
    ChartDrawing d, {
    required bool selected,
  }) {
    final Color color =
        selected ? AppColors.accent : AppColors.textSecondary;
    final Paint stroke = Paint()
      ..color = color
      ..strokeWidth = selected ? 1.8 : 1.4
      ..style = PaintingStyle.stroke;

    final double x1 =
        priceGeometry.xForIndex(DrawingAnchor.indexForTime(rawBars, d.time1));
    final double y1 = priceGeometry.yForPrice(d.price1);

    if (d.tool == ChartTool.horizontalLine) {
      canvas.drawLine(
        Offset(priceGeometry.plot.left, y1),
        Offset(priceGeometry.plot.right, y1),
        stroke,
      );
      _text(
        canvas,
        labels.price(d.price1),
        Offset(priceGeometry.plot.left + 6, y1 - 13),
        AppText.mono(size: 9, color: color),
      );
      if (selected) _handle(canvas, Offset(priceGeometry.plot.left + 14, y1));
      return;
    }

    if (!d.isTwoPoint) return;

    final double x2 =
        priceGeometry.xForIndex(DrawingAnchor.indexForTime(rawBars, d.time2!));
    final double y2 = priceGeometry.yForPrice(d.price2!);

    switch (d.tool) {
      case ChartTool.trendline:
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), stroke);
      case ChartTool.rectangle:
        final Rect r = Rect.fromPoints(Offset(x1, y1), Offset(x2, y2));
        canvas
          ..drawRect(r, Paint()..color = color.withValues(alpha: 0.10))
          ..drawRect(r, stroke);
      case ChartTool.horizontalLine:
      case ChartTool.cursor:
        break;
    }

    if (selected) {
      _handle(canvas, Offset(x1, y1));
      _handle(canvas, Offset(x2, y2));
    }
  }

  void _handle(Canvas canvas, Offset at) {
    canvas
      ..drawCircle(at, 4, Paint()..color = AppColors.background)
      ..drawCircle(
        at,
        4,
        Paint()
          ..color = AppColors.accent
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
  }

  // --------------------------------------------------------------- helpers

  static Path _dash(
    Path source, {
    double dash = 4,
    double gap = 4,
  }) {
    final Path out = Path();
    for (final PathMetric metric in source.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double next = math.min(distance + dash, metric.length);
        out.addPath(metric.extractPath(distance, next), Offset.zero);
        distance = next + gap;
      }
    }
    return out;
  }

  static TextPainter _layoutText(String text, TextStyle style) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at,
    TextStyle style, {
    bool centerOn = false,
  }) {
    final TextPainter tp = _layoutText(text, style);
    tp.paint(canvas, centerOn ? Offset(at.dx - tp.width / 2, at.dy) : at);
  }

  @override
  bool shouldRepaint(ChartBasePainter old) {
    return old.rawBars != rawBars ||
        old.drawBars != drawBars ||
        old.chartType != chartType ||
        old.interval != interval ||
        old.priceGeometry.plot != priceGeometry.plot ||
        old.priceGeometry.viewport.firstIndex !=
            priceGeometry.viewport.firstIndex ||
        old.priceGeometry.viewport.barsVisible !=
            priceGeometry.viewport.barsVisible ||
        old.priceGeometry.axisMin != priceGeometry.axisMin ||
        old.priceGeometry.axisMax != priceGeometry.axisMax ||
        old.indicators != indicators ||
        old.labels != labels ||
        old.drawings != drawings ||
        old.pendingDrawing != pendingDrawing ||
        old.selectedDrawingId != selectedDrawingId ||
        old.replayCursorIndex != replayCursorIndex ||
        old.paneGeometries.length != paneGeometries.length;
  }
}
