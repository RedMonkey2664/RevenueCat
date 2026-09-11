import 'package:flutter/material.dart';

import '../theme.dart';
import 'nerve_avatar.dart';

/// The single visual language for Discipline Score and Discipline Points.
///
/// DESIGN.md requires this to be identical wherever it appears — Simulator
/// debrief, Daily Pivot reveal, Nerve Profile — because it is the thread tying
/// separate features into one behavioural-finance product. Every surface uses
/// these rather than restyling a number locally.
abstract final class DisciplineVisuals {
  static const IconData icon = Icons.shield_moon_outlined;

  /// One colour ramp, used by every score readout in the app.
  ///
  /// The wireframes put a 72 and a 71 in the accent: anything that held its
  /// nerve reads as nominal. Amber is "shaken", red is "panicked".
  static Color colorFor(int? score) {
    if (score == null) return AppColors.textFaint;
    if (score >= 70) return AppColors.accent;
    if (score >= 50) return AppColors.caution;
    return AppColors.down;
  }

  static String verdictFor(int? score) {
    if (score == null) return 'NOT TESTED';
    if (score >= 90) return 'IRON NERVE';
    if (score >= 70) return 'HELD YOUR NERVE';
    if (score >= 50) return 'SHAKEN';
    return 'PANICKED';
  }
}

/// The Debrief's score block (artboard 1e): the Nerve avatar, the score set
/// big, the verdict, and a vertical gauge on the right.
class DisciplineScoreHero extends StatelessWidget {
  const DisciplineScoreHero({required this.score, super.key});

  /// Null means the run contained nothing gradeable — shown as "not tested"
  /// rather than as a zero or a perfect score.
  final int? score;

  @override
  Widget build(BuildContext context) {
    final Color color = DisciplineVisuals.colorFor(score);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'DISCIPLINE SCORE',
          style: AppText.label(size: 11, weight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            const NerveAvatar(size: 104),
            const SizedBox(width: AppSpacing.md + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Text(
                          score?.toString() ?? '—',
                          style: AppText.headline(
                            size: 68,
                            weight: FontWeight.w800,
                            color: color,
                            height: 1,
                          ),
                        ),
                        if (score != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              '/100',
                              style: AppText.body(
                                size: 22,
                                color: AppColors.textFaint,
                                height: 1,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      DisciplineVisuals.verdictFor(score),
                      style: AppText.railLabel(
                        size: 17,
                        weight: FontWeight.w800,
                        color: color,
                        letterSpacing: 17 * 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _VerticalGauge(value: (score ?? 0) / 100, color: color),
          ],
        ),
      ],
    );
  }
}

/// A thin vertical meter — the score as a level, not just a number.
class _VerticalGauge extends StatelessWidget {
  const _VerticalGauge({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 10,
      height: 110,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.borderStrong.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0)),
            duration: AppMotion.slow * 2,
            curve: AppMotion.curve,
            builder: (BuildContext context, double v, Widget? _) =>
                FractionallySizedBox(
                  heightFactor: v,
                  widthFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
          ),
        ),
      ),
    );
  }
}

/// The compact running-total readout.
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
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(DisciplineVisuals.icon, size: 12, color: AppColors.accent),
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
