import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../app/widgets/nerve_avatar.dart';
import '../model/nerve_profile.dart';
import 'nerve_radar.dart';

/// The shareable profile card. Rendered client-side through a
/// RepaintBoundary and handed to `share_plus`, the same way Time Machine's
/// result card is (CLAUDE.md) — no server image generation.
///
/// It carries the SIMULATED framing in its footer: a card that leaves the app
/// must still say what it is.
class NerveShareCard extends StatelessWidget {
  const NerveShareCard({required this.profile, super.key});

  final NerveProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 330,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'MY NERVE PROFILE',
            style: AppText.railLabel(
              size: 13,
              weight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 13 * 0.3,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const NerveAvatar(size: 76, glow: false),
          const SizedBox(height: AppSpacing.md),
          Text(
            profile.archetype.title,
            textAlign: TextAlign.center,
            style: AppText.headline(size: 26, letterSpacing: 26 * 0.06),
          ),
          const SizedBox(height: AppSpacing.sm),
          NerveRadar(values: profile.radar, size: 220),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                '${profile.overall ?? '—'}',
                style: AppText.headline(size: 44, color: AppColors.accent),
              ),
              Text(
                '/100',
                style: AppText.mono(size: 18, color: AppColors.textFaint),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Based on ${profile.runsScored} crash simulation'
            '${profile.runsScored == 1 ? '' : 's'}',
            style: AppText.body(size: 13, color: AppColors.textFaint),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'MARKET NERVE · SIMULATED · NOT FINANCIAL ADVICE',
            textAlign: TextAlign.center,
            style: AppText.label(size: 8.5, color: AppColors.simulatedBadge),
          ),
        ],
      ),
    );
  }
}
