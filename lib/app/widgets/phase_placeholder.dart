import 'package:flutter/material.dart';

import '../theme.dart';

/// An honest "not built yet" panel for tabs whose phase has not started.
///
/// Distinct from DESIGN.md's dummy/locked chrome: dummy chrome is a shipped,
/// deliberately inert feature the user is meant to see. This is scaffolding
/// that must be gone by launch — every use is a build-order marker, so it
/// names the ROADMAP.md phase that replaces it.
class PhasePlaceholder extends StatelessWidget {
  const PhasePlaceholder({
    required this.pillar,
    required this.phase,
    required this.summary,
    super.key,
  });

  final String pillar;

  /// e.g. 'Phase 5'.
  final String phase;

  final String summary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(pillar.toUpperCase(), style: AppText.label()),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Not built yet',
              style: AppText.mono(size: 20, weight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              summary,
              textAlign: TextAlign.center,
              style: AppText.body(size: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                'ROADMAP · ${phase.toUpperCase()}',
                style: AppText.label(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
