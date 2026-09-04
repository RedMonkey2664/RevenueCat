import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../app/widgets/discipline_badge.dart';
import '../../core/services/progress_service.dart';

/// Profile — the cross-pillar stat sheet (DESIGN.md screen 9).
///
/// It exists to make the three pillars read as one product: the same
/// Discipline visual language as the Simulator debrief and (once built) the
/// Daily Pivot reveal, over one shared total.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ProgressState progress = ref.watch(progressProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'PROFILE',
          style: AppText.label(color: AppColors.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      DisciplineVisuals.icon,
                      size: 14,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'TOTAL DISCIPLINE POINTS',
                      style: AppText.label(color: AppColors.accent),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  progress.totalDisciplinePoints.toString(),
                  style: AppText.mono(
                    size: 52,
                    weight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
                Text(
                  'Your best score on each level, plus Daily Pivot bonuses.',
                  style: AppText.body(size: 11, color: AppColors.textFaint),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: _Stat(
                  label: 'LEVELS CLEARED',
                  value: progress.clearedCount.toString(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Stat(
                  label: 'PIVOT STREAK',
                  value: '—',
                  // Honest: the Daily Pivot is Phase 6 and writes this.
                  note: 'Daily Pivot not built yet',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('CLEARED LEVELS', style: AppText.label()),
          const SizedBox(height: AppSpacing.sm),
          if (progress.levels.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Nothing cleared yet. Every level you finish is revealed and '
                'scored here.',
                style: AppText.body(size: 12, color: AppColors.textSecondary),
              ),
            )
          else
            for (final LevelProgress p in progress.levels.values)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _LevelRow(progress: p),
              ),
          const SizedBox(height: AppSpacing.xl),
          // MONETIZATION.md item 5: Restore Purchases must be reachable from
          // Profile as well as the Paywall — App Store review checks for it.
          OutlinedButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.surfaceRaised,
                content: Text(
                  'Purchases arrive with RevenueCat in Phase 8.',
                  style: AppText.body(size: 12),
                ),
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              shape: const RoundedRectangleBorder(),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            ),
            child: Text(
              'RESTORE PURCHASES',
              style: AppText.mono(
                size: 12,
                weight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const _NoRealMoneyNote(),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.note});

  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: AppText.label()),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: AppText.mono(size: 28, weight: FontWeight.w700)),
          if (note != null)
            Text(
              note!,
              style: AppText.body(size: 10, color: AppColors.textFaint),
            ),
        ],
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({required this.progress});

  final LevelProgress progress;

  @override
  Widget build(BuildContext context) {
    final Color color = DisciplineVisuals.colorFor(progress.bestScore);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  progress.levelId,
                  style: AppText.mono(size: 13, weight: FontWeight.w600),
                ),
                Text(
                  '${progress.timesPlayed} run'
                  '${progress.timesPlayed == 1 ? '' : 's'} · '
                  '${progress.modesPlayed.join(', ')}',
                  style: AppText.body(size: 11, color: AppColors.textFaint),
                ),
              ],
            ),
          ),
          Text(
            progress.bestScore?.toString() ?? '—',
            style: AppText.mono(
              size: 22,
              weight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// The framing rule applied to the Profile: points are never currency
/// (CLAUDE.md, DAILY_PIVOT.md, DESIGN.md).
class _NoRealMoneyNote extends StatelessWidget {
  const _NoRealMoneyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.simulatedBadge.withValues(alpha: 0.08),
        border: Border.all(
          color: AppColors.simulatedBadge.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        'Discipline Points are an in-app score only. They are not money, '
        'cannot be withdrawn, exchanged or cashed out, and have no value '
        'outside this app.',
        style: AppText.body(size: 11, color: AppColors.simulatedBadge),
      ),
    );
  }
}
