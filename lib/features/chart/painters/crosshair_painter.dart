import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../simulator/engine/candle_model.dart';
import '../model/chart_labels.dart';
import '../model/chart_layout.dart';
import '../model/chart_types.dart';
import '../model/chart_viewport.dart';

/// The crosshair, on its own layer.
///
/// Separated from [ChartBasePainter] so a finger dragging across the chart
/// repaints two lines and two tags rather than several hundred candles. The
/// widget puts a [RepaintBoundary] between them.
class CrosshairPainter extends CustomPainter {
  const CrosshairPainter({
    required this.bars,
    required this.interval,
    required this.layout,
    required this.priceGeometry,
    required this.paneGeometries,
    required this.labels,
    required this.position,
    required this.barIndex,
  });

  final List<Candle> bars;
  final BarInterval interval;
  final ChartLayout layout;
  final ChartGeometry priceGeometry;
  final List<ChartGeometry> paneGeometries;
  final ChartLabels labels;

  /// Null when the crosshair is down.
  final Offset? position;

  /// Bar the crosshair has snapped to.
  final int? barIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset? p = position;
    final int? index = barIndex;
    if (p == null || index == null || index >= bars.length) return;

    // Snap x to the bar centre — a crosshair that floats between bars makes
    // the readout ambiguous about which bar it is describing.
    final double x = priceGeometry.xForIndex(index.toDouble());
    final double contentBottom = layout.timeAxis.top;

    final Paint line = Paint()
      ..color = AppColors.textSecondary.withValues(alpha: 0.6)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    canvas.drawPath(
      _dash(Path()..moveTo(x, 0)..lineTo(x, contentBottom)),
      line,
    );

    // The horizontal arm only makes sense inside the pane the finger is in;
    // spanning it across a volume pane would read as a price level there.
    final int? paneIndex = layout.paneIndexAt(p.dy);
    if (paneIndex != null) {
      final ChartGeometry g =
          paneIndex == 0 ? priceGeometry : paneGeometries[paneIndex - 1];
      final double y = p.dy.clamp(g.plot.top, g.plot.bottom);

      canvas.drawPath(
        _dash(Path()..moveTo(g.plot.left, y)..lineTo(g.plot.right, y)),
        line,
      );

      _tag(
        canvas,
        rect: Rect.fromLTWH(
          g.plot.right + 2,
          y - 8,
          layout.gutterWidth - 4,
          16,
        ),
        text: paneIndex == 0
            ? labels.price(g.priceForY(y))
            : _paneValue(g, y),
      );
    }

    _tag(
      canvas,
      rect: Rect.fromCenter(
        center: Offset(x, layout.timeAxis.center.dy),
        width: 78,
        height: layout.timeAxisHeight,
      ),
      text: labels.timeDetailed(bars[index].date, index, interval),
      clampToWidth: layout.price.width,
    );
  }

  String _paneValue(ChartGeometry g, double y) {
    final double v = g.axisForY(y);
    return v.abs() >= 1000 ? formatVolume(v) : formatPrice(v);
  }

  void _tag(
    Canvas canvas, {
    required Rect rect,
    required String text,
    double? clampToWidth,
  }) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: AppText.mono(
          size: 9,
          weight: FontWeight.w700,
          color: AppColors.background,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    Rect box = Rect.fromLTWH(
      rect.left,
      rect.top,
      math.max(rect.width, tp.width + 10),
      rect.height,
    );

    if (clampToWidth != null) {
      // Keep the time tag on screen at either end of the axis.
      final double left = box.left.clamp(0.0, math.max(0, clampToWidth - box.width));
      box = Rect.fromLTWH(left, box.top, box.width, box.height);
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(2)),
      Paint()..color = AppColors.textSecondary,
    );
    tp.paint(
      canvas,
      Offset(box.center.dx - tp.width / 2, box.center.dy - tp.height / 2),
    );
  }

  static Path _dash(Path source, {double dash = 3, double gap = 3}) {
    final Path out = Path();
    for (final PathMetric m in source.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        final double next = math.min(d + dash, m.length);
        out.addPath(m.extractPath(d, next), Offset.zero);
        d = next + gap;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(CrosshairPainter old) =>
      old.position != position ||
      old.barIndex != barIndex ||
      old.bars != bars ||
      old.priceGeometry.plot != priceGeometry.plot;
}
