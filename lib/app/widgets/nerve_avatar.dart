import 'package:flutter/material.dart';

import '../theme.dart';

/// The Nerve mascot: a cat's head with two lit eyes, inside a ringed disc.
///
/// It appears wherever the app talks about *you* rather than the market — the
/// Debrief's score and the Nerve Profile — so the behavioural read has a face.
/// Drawn rather than bundled as an image so it stays crisp at every size and
/// takes the theme's accent.
class NerveAvatar extends StatelessWidget {
  const NerveAvatar({this.size = 96, this.glow = true, super.key});

  final double size;

  /// A soft halo behind the disc. Off on small inline uses.
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Nerve avatar',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _NervePainter(glow: glow)),
      ),
    );
  }
}

class _NervePainter extends CustomPainter {
  const _NervePainter({required this.glow});

  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide;
    final Offset c = size.center(Offset.zero);
    final double r = s / 2;

    if (glow) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              AppColors.accent.withValues(alpha: 0.14),
              AppColors.accent.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    // The disc: a dark navy face under a brand-orange ring.
    canvas.drawCircle(
      c,
      r * 0.92,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.3),
          colors: const <Color>[Color(0xFF18222D), Color(0xFF0B1118)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r * 0.92,
      Paint()
        ..color = AppColors.accent.withValues(alpha: 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.018,
    );

    // The head: a rounded oval, slightly low in the disc.
    final Offset head = c.translate(0, s * 0.05);
    final Rect headRect = Rect.fromCenter(
      center: head,
      width: s * 0.42,
      height: s * 0.34,
    );
    final Paint outline = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.014
      ..strokeJoin = StrokeJoin.round;
    final Paint face = Paint()..color = const Color(0xFF0A1016);

    // Ears: two triangles standing on the head's upper edge.
    for (final double side in <double>[-1, 1]) {
      final Path ear = Path()
        ..moveTo(head.dx + side * s * 0.16, headRect.top + s * 0.06)
        ..lineTo(head.dx + side * s * 0.12, headRect.top - s * 0.13)
        ..lineTo(head.dx + side * s * 0.04, headRect.top + s * 0.01)
        ..close();
      canvas
        ..drawPath(ear, face)
        ..drawPath(ear, outline);
    }

    canvas
      ..drawOval(headRect, face)
      ..drawOval(headRect, outline);

    // Eyes: lit cyan, each with a highlight — the only bright thing in it.
    for (final double side in <double>[-1, 1]) {
      final Offset eye = head.translate(side * s * 0.075, -s * 0.02);
      canvas
        ..drawCircle(
          eye,
          s * 0.058,
          Paint()
            ..color = AppColors.data.withValues(alpha: 0.35)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.02),
        )
        ..drawCircle(eye, s * 0.045, Paint()..color = AppColors.data)
        ..drawCircle(
          eye.translate(-s * 0.014, -s * 0.014),
          s * 0.014,
          Paint()..color = Colors.white.withValues(alpha: 0.9),
        );
    }
  }

  @override
  bool shouldRepaint(_NervePainter old) => old.glow != glow;
}
