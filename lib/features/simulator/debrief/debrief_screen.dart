import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/formatting.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/discipline_badge.dart';
import '../../../app/widgets/simulated_badge.dart';
import '../../../core/services/progress_service.dart';
import '../engine/discipline_score.dart';
import '../engine/replay_controller.dart';
import '../engine/script_event_model.dart';
import '../engine/simulation_mode.dart';

/// End of run: Discipline Score, simulated P&L, and the blind-mode reveal.
///
/// This is the only screen allowed to name the asset and the real dates
/// (ENGINE.md §3). Everything shown here is either measured from the run or
/// read from the level's authored `reveal_headline` — nothing is invented.
class DebriefScreen extends ConsumerStatefulWidget {
  const DebriefScreen({required this.state, super.key});

  final ReplayState state;

  @override
  ConsumerState<DebriefScreen> createState() => _DebriefScreenState();
}

class _DebriefScreenState extends ConsumerState<DebriefScreen> {
  @override
  void initState() {
    super.initState();
    // Recorded once, on arrival — the Debrief is the only place a run is
    // considered finished. The synthetic sample never touches real progress.
    if (!widget.state.level.isSyntheticSample) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _record());
    }
  }

  void _record() {
    final ReplayState state = widget.state;
    unawaited(
      ref.read(progressProvider.notifier).recordRun(
            levelId: state.level.id,
            score: state.disciplineScore.score,
            pnl: state.portfolio.valueAt(state.level.candles.last.close) -
                state.level.startingBalance,
            mode: state.mode,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ReplayState state = widget.state;
    final DisciplineScore score = state.disciplineScore;
    final double finalValue = state.portfolio.valueAt(
      state.level.candles.last.close,
    );
    final double pnl = finalValue - state.level.startingBalance;

    return Scaffold(
      appBar: AppBar(
        title: Text('DEBRIEF', style: AppText.label()),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          if (state.level.isSyntheticSample) ...<Widget>[
            const SyntheticDataBadge(),
            const SizedBox(height: AppSpacing.md),
          ],
          _ScoreAndPnl(score: score, pnl: pnl, finalValue: finalValue),
          const SizedBox(height: AppSpacing.lg),
          _RevealCard(state: state),
          const SizedBox(height: AppSpacing.lg),
          Text(
            score.mode.isBeginner ? 'YOUR CALLS' : 'YOUR NERVE, TESTED',
            style: AppText.label(),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!score.wasTested)
            _EmptyBreakdown(mode: score.mode)
          else
            for (final ScoredMoment m in score.moments) ...<Widget>[
              _MomentRow(moment: m),
              const SizedBox(height: AppSpacing.sm),
            ],
          if (score.mode.isBeginner) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text('WHAT ACTUALLY HAPPENED', style: AppText.label()),
            const SizedBox(height: AppSpacing.sm),
            for (final RecordedDecision d in state.decisions) ...<Widget>[
              _HeadlineCard(decision: d),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
          const SizedBox(height: AppSpacing.lg),
          _Takeaway(score: score),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.background,
              shape: const RoundedRectangleBorder(),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            ),
            child: Text(
              'DONE',
              style: AppText.mono(
                size: 14,
                weight: FontWeight.w700,
                color: AppColors.background,
                letterSpacing: 1.4,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _ScoreAndPnl extends StatelessWidget {
  const _ScoreAndPnl({
    required this.score,
    required this.pnl,
    required this.finalValue,
  });

  final DisciplineScore score;
  final double pnl;
  final double finalValue;

  @override
  Widget build(BuildContext context) {
    final Color pnlColor = pnl >= 0 ? AppColors.up : AppColors.down;
    final String sign = pnl >= 0 ? '+' : '-';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Shared widget, not a local restyle: DESIGN.md requires the
          // Discipline visual language to be identical in the Simulator
          // debrief, the Daily Pivot reveal and the Profile.
          Expanded(
            child: DisciplineScoreDial(
              score: score.score,
              momentsTested: score.momentsTested,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text('SIMULATED P&L', style: AppText.label()),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$sign${formatRupees(pnl.abs())}',
                style: AppText.mono(
                  size: 22,
                  weight: FontWeight.w700,
                  color: pnlColor,
                ),
              ),
              Text(
                'ended ${formatRupees(finalValue)}',
                style: AppText.body(
                  size: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The blind-mode reveal.
class _RevealCard extends StatelessWidget {
  const _RevealCard({required this.state});

  final ReplayState state;

  @override
  Widget build(BuildContext context) {
    final DateTime from = state.level.candles.first.date;
    final DateTime to = state.level.candles.last.date;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
        borderRadius: AppRadius.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'YOU WERE TRADING',
            style: AppText.label(color: AppColors.accent),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            state.level.realAssetName,
            style: AppText.mono(size: 18, weight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            // Real dates, finally — blind mode is over.
            '${from.dateLabel} → ${to.dateLabel}',
            style: AppText.mono(size: 12, color: AppColors.textSecondary),
          ),
          // The event itself, finally. Held back until now on purpose: naming
          // it earlier would turn every replay into a memory test rather than
          // a test of nerve (ENGINE.md §3).
          if ((state.level.description ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Container(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.md),
            Text('WHAT THIS WAS', style: AppText.label()),
            const SizedBox(height: AppSpacing.xs),
            Text(
              state.level.description!,
              style: AppText.body(
                size: 13,
                color: AppColors.textPrimary,
                height: 1.55,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            'Played in ${state.mode.label} mode.',
            style: AppText.body(size: 12, color: AppColors.textFaint),
          ),
        ],
      ),
    );
  }
}

class _MomentRow extends StatelessWidget {
  const _MomentRow({required this.moment});

  final ScoredMoment moment;

  @override
  Widget build(BuildContext context) {
    final Color color = moment.isPanic
        ? AppColors.down
        : moment.isFullCredit
            ? AppColors.up
            : AppColors.flashSoft;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(width: 3, height: 34, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  moment.label,
                  style: AppText.mono(size: 12, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  moment.detail,
                  style: AppText.body(
                    size: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${(moment.credit * 100).round()}',
            style: AppText.mono(
              size: 14,
              weight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown to a run that contained nothing gradeable — an honest blank rather
/// than a flattering default score.
class _EmptyBreakdown extends StatelessWidget {
  const _EmptyBreakdown({required this.mode});

  final SimulationMode mode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        mode.isBeginner
            ? 'You did not reach a decision point in this run, so there is '
                'nothing to score.'
            : 'This window never fell far enough to test your nerve, so there '
                'is nothing to score. Discipline is only measurable in a '
                'drawdown.',
        style: AppText.body(size: 12, color: AppColors.textSecondary),
      ),
    );
  }
}

/// The authored historical context, revealed only now.
class _HeadlineCard extends StatelessWidget {
  const _HeadlineCard({required this.decision});

  final RecordedDecision decision;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'DAY ${decision.pausePoint.triggerIndex + 1}',
            style: AppText.label(),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            decision.pausePoint.revealHeadline,
            style: AppText.body(size: 13),
          ),
        ],
      ),
    );
  }
}

class _Takeaway extends StatelessWidget {
  const _Takeaway({required this.score});

  final DisciplineScore score;

  String get _text {
    if (!score.wasTested) {
      return 'Play a window with a real drawdown in it to get a score worth '
          'having.';
    }
    if (score.panicCount == 0) {
      return 'You never cut a position while it was falling. That single '
          'habit is what the Discipline Score is measuring — and it is the '
          'one most people fail.';
    }
    if (score.panicCount == 1) {
      return 'You sold into a fall once. That is the reflex this app exists '
          'to make visible: the loss became permanent the moment you took it.';
    }
    return 'You sold into a fall ${score.panicCount} times. Each one turned a '
        'paper loss into a real one — look at what the price did afterwards.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.07),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('TAKEAWAY', style: AppText.label(color: AppColors.accent)),
          const SizedBox(height: AppSpacing.xs),
          Text(_text, style: AppText.body(size: 13)),
        ],
      ),
    );
  }
}

extension on DateTime {
  String get dateLabel {
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '$day ${months[month - 1]} $year';
  }
}
