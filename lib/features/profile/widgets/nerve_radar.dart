import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../model/nerve_profile.dart';

/// The five-trait radar on the share card.
///
/// Each axis is 0..1 with higher meaning steadier (see
/// [NerveProfile.radar]); the rings are quarters. Axis labels are drawn by
/// the painter so the whole card rasterises as one picture for sharing.
class NerveRadar extends StatelessWidget {
  const NerveRadar({required this.values, this.size = 220, super.key});

  final Map<NerveTrait, double> values;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: <String>[
        for (final NerveTrait t in NerveTrait.values)
          '${t.long.toLowerCase()} ${((values[t] ?? 0) * 100).round()}',
      ].join(', '),
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _RadarPainter(values: values)),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({required this.values});

  final Map<NerveTrait, double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.shortestSide / 2 - 22;
    const List<NerveTrait> traits = NerveTrait.values;

    Offset at(int i, double f) {
      final double a = -math.pi / 2 + i * 2 * math.pi / traits.length;
      return c + Offset(math.cos(a), math.sin(a)) * r * f;
    }

    final Paint grid = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final double f in <double>[0.25, 0.5, 0.75, 1]) {
      final Path ring = Path();
      for (int i = 0; i < traits.length; i++) {
        final Offset p = at(i, f);
        i == 0 ? ring.moveTo(p.dx, p.dy) : ring.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(ring..close(), grid);
    }
    for (int i = 0; i < traits.length; i++) {
      canvas.drawLine(c, at(i, 1), grid);
    }

    final Path shape = Path();
    for (int i = 0; i < traits.length; i++) {
      final Offset p = at(i, (values[traits[i]] ?? 0).clamp(0.05, 1.0));
      i == 0 ? shape.moveTo(p.dx, p.dy) : shape.lineTo(p.dx, p.dy);
    }
    shape.close();
    canvas
      ..drawPath(
        shape,
        Paint()..color = AppColors.accent.withValues(alpha: 0.16),
      )
      ..drawPath(
        shape,
        Paint()
          ..color = AppColors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round,
      );
    for (int i = 0; i < traits.length; i++) {
      canvas.drawCircle(
        at(i, (values[traits[i]] ?? 0).clamp(0.05, 1.0)),
        3.5,
        Paint()..color = AppColors.accent,
      );
    }

    for (int i = 0; i < traits.length; i++) {
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: traits[i].short,
          style: AppText.label(size: 8.5, color: AppColors.textSecondary),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final Offset p = at(i, 1.18);
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.values != values;
}
