import 'package:flutter/material.dart';

import '../theme.dart';

/// The single visual language for Discipline Score and Discipline Points.
///
/// DESIGN.md requires this to be identical wherever it appears — Simulator
/// debrief, Daily Pivot reveal, Profile — because it is the thread tying three
/// otherwise separate features into one behavioural-finance product. Every
/// surface uses these widgets rather than restyling a number locally.
abstract final class DisciplineVisuals {
  static const IconData icon = Icons.shield_moon_outlined;

  /// One colour ramp, used by every score readout in the app.
  static Color colorFor(int? score) {
    if (score == null) return AppColors.textFaint;
    if (score >= 80) return AppColors.up;
    if (score >= 50) return AppColors.simulatedBadge;
    return AppColors.down;
  }

  static String verdictFor(int? score) {
    if (score == null) return 'NOT TESTED';
    if (score >= 90) return 'IRON NERVE';
    if (score >= 80) return 'DISCIPLINED';
    if (score >= 50) return 'SHAKEN';
    return 'PANICKED';
  }
}

/// The large score readout used at Debrief.
class DisciplineScoreDial extends StatelessWidget {
  const DisciplineScoreDial({
    required this.score,
    required this.momentsTested,
    super.key,
  });

  /// Null means the run contained nothing gradeable — shown as "not tested"
  /// rather than as a zero or a perfect score.
  final int? score;

  final int momentsTested;

  @override
  Widget build(BuildContext context) {
    final Color color = DisciplineVisuals.colorFor(score);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Both rows shrink rather than overflow: the dial is laid out beside
        // the P&L on the Debrief, so on a 375pt phone it gets roughly half the
        // width -- 26pt and 30pt short respectively before this.
        Row(
          children: <Widget>[
            Icon(DisciplineVisuals.icon, size: 14, color: color),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                'DISCIPLINE SCORE',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.label(color: color),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                score?.toString() ?? '—',
                style: AppText.mono(
                  size: 52,
                  weight: FontWeight.w700,
                  color: color,
                ),
              ),
              if (score != null)
                Text(
                  ' / 100',
                  style: AppText.mono(size: 16, color: AppColors.textFaint),
                ),
            ],
          ),
        ),
        Text(
          DisciplineVisuals.verdictFor(score),
          style: AppText.label(color: color),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          momentsTested == 0
              ? 'No significant drawdown in this window to test you.'
              : '$momentsTested moment${momentsTested == 1 ? '' : 's'} graded',
          style: AppText.body(size: 11, color: AppColors.textFaint),
        ),
      ],
    );
  }
}

/// The compact running-total readout (Profile, headers).
class DisciplinePointsChip extends StatelessWidget {
  const DisciplinePointsChip({required this.points, super.key});

  final int points;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            DisciplineVisuals.icon,
            size: 12,
            color: AppColors.accent,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$points DP',
            style: AppText.mono(
              size: 12,
              weight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}
