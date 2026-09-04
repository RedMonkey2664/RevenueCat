import 'package:flutter/material.dart';

import 'theme.dart';

/// Constrains the app to phone width on a larger viewport.
///
/// Market Nerve targets iOS and Android phones only (CLAUDE.md). On a desktop
/// browser — which is how the app gets play-tested — an unconstrained layout
/// stretches a 3-column level grid across 1900pt, giving 630pt-wide tiles that
/// look broken. Rather than making every screen responsive for a form factor
/// the product does not ship on, the app renders inside a phone-sized frame.
///
/// This is inert on a real device: below [maxWidth] the child is returned
/// untouched.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({required this.child, super.key});

  /// Slightly wider than the largest common phone (Pro Max ≈ 430pt).
  static const double maxWidth = 430;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    if (mq.size.width <= maxWidth) return child;

    final Size framed = Size(maxWidth, mq.size.height);

    return ColoredBox(
      color: const Color(0xFF06090D),
      child: Center(
        child: Container(
          width: maxWidth,
          height: framed.height,
          decoration: const BoxDecoration(
            color: AppColors.background,
            border: Border.symmetric(
              vertical: BorderSide(color: AppColors.border),
            ),
          ),
          // The app must believe it is on a phone, or MediaQuery-driven
          // layout would still read the desktop width.
          child: MediaQuery(
            data: mq.copyWith(size: framed),
            child: child,
          ),
        ),
      ),
    );
  }
}
