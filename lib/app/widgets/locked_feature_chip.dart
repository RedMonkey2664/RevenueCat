import 'package:flutter/material.dart';

import '../theme.dart';
import 'pressable.dart';

/// A console control that looks the part and does nothing.
///
/// DESIGN.md's rule, restated mechanically: a dummy feature must be *visible*,
/// *tappable* and *clearly labelled as unavailable*. It must never be silently
/// missing, and it must never crash or silently no-op — tapping one always
/// produces a visible, honest response.
///
/// The honesty matters beyond taste: MONETIZATION.md says paywall copy must
/// describe these as "more tools coming" rather than implying they are built,
/// and a chip that pretended to work would make that copy a lie.
class LockedFeatureChip extends StatelessWidget {
  const LockedFeatureChip({
    required this.label,
    this.icon,
    this.compact = false,
    super.key,
  });

  final String label;
  final IconData? icon;

  /// Tighter padding for dense rows like the timeframe strip.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$label — not available yet',
      // A 22pt chip is a 22pt hit box unless the target is widened; phones
      // need 44 (design-system touch rule).
      child: Pressable(
        onTap: () => showLockedFeatureSheet(context, label),
        child: TouchTarget(
          child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.sm : AppSpacing.sm + 2,
            vertical: AppSpacing.xs,
          ),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.4),
              border: Border.all(color: AppColors.border),
              borderRadius: AppRadius.chip,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 12, color: AppColors.textFaint),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Text(
                  label,
                  style: AppText.mono(
                    size: compact ? 10 : 11,
                    weight: FontWeight.w700,
                    color: AppColors.textFaint,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.lock_outline,
                  size: 10,
                  color: AppColors.textFaint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The single "coming soon" response every dummy control shares, so the app
/// never has two different stories about what is and is not built.
Future<void> showLockedFeatureSheet(BuildContext context, String label) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceRaised,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
    // Scrollable: the sheet is capped at a fraction of the screen, and this
    // content does not fit a short device or a large accessibility text size.
    isScrollControlled: true,
    builder: (BuildContext context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: AppColors.simulatedBadge,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'NOT BUILT YET',
                  style: AppText.label(color: AppColors.simulatedBadge),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              label,
              style: AppText.mono(size: 18, weight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Market Nerve is a behavioural simulator, not a trading '
              'terminal. This control is part of the console look and is not '
              'wired up.\n\n'
              'The chart, the moving average, RSI, the replay speeds and the '
              'decision scoring are all real.',
              style: AppText.body(size: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.chip,
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.md),
                ),
                child: Text(
                  'GOT IT',
                  style: AppText.mono(
                    size: 13,
                    weight: FontWeight.w700,
                    color: AppColors.accent,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
