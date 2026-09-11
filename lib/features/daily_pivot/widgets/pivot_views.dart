import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/formatting.dart';
import '../../../app/shell_state.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/feed_state.dart';
import '../../../app/widgets/hud.dart';
import '../../../core/services/progress_service.dart';
import '../model/pivot_models.dart';
import '../services/pivot_controller.dart';
import 'pivot_parts.dart';

/// The Daily Pivot's phase views. Each takes the controller's state and
/// draws one artboard; none of them fetch anything themselves.

EdgeInsets get _pad => const EdgeInsets.fromLTRB(
  AppSpacing.md + 4,
  AppSpacing.lg,
  AppSpacing.md + 4,
  AppSpacing.lg,
);

// ------------------------------------------------------------------ 1g: vote

class PivotVoteView extends ConsumerWidget {
  const PivotVoteView({required this.state, super.key});

  final PivotViewState state;

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    PivotChoice choice,
  ) async {
    final double strike = state.strike!;
    final bool? sealed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(
          'SEAL ${choice.label}?',
          style: AppText.railLabel(size: 17, color: AppColors.textPrimary),
        ),
        content: Text(
          '${choice.label} — BTC ${choice == PivotChoice.yes ? 'closes above' : 'closes at or below'} '
          '${formatUsd(strike)} at 17:00 IST.\n\nOne vote a day. Once sealed it '
          'cannot be changed.',
          style: AppText.body(size: 14, color: AppColors.textSecondary),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('SEAL ${choice.label}'),
          ),
        ],
      ),
    );
    if (sealed ?? false) {
      await ref.read(pivotControllerProvider.notifier).vote(choice);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double? strike = state.strike;
    return CustomScrollView(
      slivers: <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: _pad,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _InstrumentHeader(state: state),
                const SizedBox(height: AppSpacing.md + 4),
                PivotTape(bars: state.tape, strike: strike, height: 150),
                const SizedBox(height: AppSpacing.lg),
                if (strike != null)
                  Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        const TextSpan(text: 'WILL BTC CLOSE ABOVE '),
                        TextSpan(
                          text: formatUsd(strike),
                          style: const TextStyle(color: AppColors.accent),
                        ),
                        const TextSpan(text: ' TODAY?'),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: AppText.headline(size: 36, height: 1.12),
                  ),
                const SizedBox(height: AppSpacing.md + 4),
                Text(
                  'RESOLVES AT 17:00 IST CLOSE',
                  textAlign: TextAlign.center,
                  style: AppText.label(size: 12, letterSpacing: 12 * 0.2),
                ),
                const Spacer(),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: PivotVoteButton(
                        choice: PivotChoice.yes,
                        color: AppColors.accent,
                        onTap: strike == null
                            ? null
                            : () => _confirm(context, ref, PivotChoice.yes),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: PivotVoteButton(
                        choice: PivotChoice.no,
                        color: AppColors.down,
                        onTap: strike == null
                            ? null
                            : () => _confirm(context, ref, PivotChoice.no),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg + 4),
                // Legally and visually unambiguous (CLAUDE.md): points only.
                HudPanel(
                  dashed: true,
                  color: AppColors.borderStrong,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md - 2,
                  ),
                  child: Text(
                    'DISCIPLINE POINTS ONLY · NEVER MONEY · NOT WITHDRAWABLE',
                    textAlign: TextAlign.center,
                    style: AppText.label(size: 11, letterSpacing: 11 * 0.18),
                  ),
                ),
                const SizedBox(height: AppSpacing.md + 2),
                Row(
                  children: <Widget>[
                    Text(
                      'ONE VOTE · LOCKS ON SUBMIT',
                      style: AppText.label(
                        size: 10.5,
                        color: AppColors.textFaint,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'STREAK ${state.streak}',
                      style: AppText.label(
                        size: 10.5,
                        color: AppColors.textFaint,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    SegmentBar(
                      filled: state.streak.clamp(0, 4),
                      total: 4,
                      width: 34,
                      height: 9,
                      gap: 3,
                      color: AppColors.textFaint,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InstrumentHeader extends StatelessWidget {
  const _InstrumentHeader({required this.state});

  final PivotViewState state;

  @override
  Widget build(BuildContext context) {
    final double? price = state.live?.price ?? state.strike;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text("TODAY'S INSTRUMENT", style: AppText.label(size: 11)),
              const SizedBox(height: AppSpacing.xs + 2),
              Text(
                'BITCOIN',
                style: AppText.headline(size: 38, letterSpacing: 38 * 0.06),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            if (price == null)
              const FeedLoadingValue(width: 140, height: 36)
            else
              Text(
                formatUsd(price),
                style: AppText.headline(size: 38, color: AppColors.accent),
              ),
            const SizedBox(height: AppSpacing.xs + 2),
            SourceTag.fromAttribution(state.sourceLabel),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- 1h: locked

class PivotLockedView extends ConsumerWidget {
  const PivotLockedView({required this.state, super.key});

  final PivotViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PivotVote vote = state.vote!;
    final Color c = vote.choice == PivotChoice.yes
        ? AppColors.accent
        : AppColors.down;
    final double? live = state.live?.price;
    final double? strike = state.strike;
    final bool? front = state.callInFront;
    final int points = ref.watch(progressProvider).totalDisciplinePoints;
    final int votes = state.tally?.total ?? 0;

    return ListView(
      padding: _pad,
      children: <Widget>[
        Text(
          'YOUR CALL IS IN',
          textAlign: TextAlign.center,
          style: AppText.label(size: 12, letterSpacing: 12 * 0.24),
        ),
        const SizedBox(height: AppSpacing.md + 2),
        Center(
          child: Container(
            width: 200,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg - 2),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.1),
              border: Border.all(color: c, width: 1.3),
            ),
            child: Text(
              vote.choice.label,
              textAlign: TextAlign.center,
              style: AppText.display(
                size: 60,
                color: c,
                letterSpacing: 60 * 0.16,
                height: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md + 2),
        Text(
          'SEALED ${PivotClock.istClock(vote.sealedAt)} · CANNOT BE CHANGED',
          textAlign: TextAlign.center,
          style: AppText.label(size: 11, letterSpacing: 11 * 0.2),
        ),
        const SizedBox(height: AppSpacing.xl),
        HudPanel(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text('RESOLVES IN', style: AppText.label(size: 11)),
                  const Spacer(),
                  Text('17:00 CLOSE', style: AppText.label(size: 11)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              PivotCountdown(
                target: PivotClock.closeUtc(state.dayKey),
                onElapsed: () =>
                    ref.read(pivotControllerProvider.notifier).sync(),
              ),
              const SizedBox(height: AppSpacing.lg),
              PivotDayRail(dayKey: state.dayKey, now: DateTime.now().toUtc()),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md + 4),
        HudPanel(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'WHILE YOU WAIT · LIVE TAPE',
                style: AppText.label(size: 11),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  if (live == null)
                    const FeedLoadingValue(width: 150, height: 34)
                  else
                    Text(
                      formatUsd(live),
                      style: AppText.headline(
                        size: 36,
                        color: AppColors.accent,
                      ),
                    ),
                  const Spacer(),
                  if (live != null && strike != null)
                    Text(
                      '${formatSignedPercent((live / strike - 1) * 100, decimals: 2)} vs strike',
                      style: AppText.body(
                        size: 14,
                        color: live >= strike
                            ? AppColors.accent
                            : AppColors.down,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              SourceTag.fromAttribution(state.sourceLabel),
              const SizedBox(height: AppSpacing.md),
              PivotTape(
                bars: state.tape,
                strike: strike,
                height: 110,
                framed: false,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                front == null
                    ? 'WAITING FOR THE LIVE PRICE.'
                    : front
                    ? 'YOUR CALL IS CURRENTLY IN FRONT.'
                    : 'YOUR CALL IS CURRENTLY BEHIND.',
                style: AppText.label(size: 11, letterSpacing: 11 * 0.18),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md + 4),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: PivotStreakPanel(streak: state.streak)),
              const SizedBox(width: AppSpacing.md + 4),
              Expanded(
                child: PivotPointsPanel(title: 'POINTS', points: points),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md + 4),
        HudPanel(
          color: AppColors.caution.withValues(alpha: 0.5),
          fill: AppColors.caution.withValues(alpha: 0.05),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'CROWD LOCKED AT 17:00',
                      style: AppText.railLabel(
                        size: 18,
                        weight: FontWeight.w600,
                        color: AppColors.caution,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${formatUsd(votes, symbol: false)} VOTE'
                      '${votes == 1 ? '' : 'S'} SO FAR — HIDDEN UNTIL CLOSE',
                      style: AppText.label(
                        size: 10.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (state.tally != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs + 2),
                      Text(
                        state.tally!.source,
                        style: AppText.label(
                          size: 9,
                          color: AppColors.textFaint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.diamond_outlined,
                color: AppColors.caution,
                size: 22,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------- 1i: poll closed

class PivotPollClosedView extends ConsumerWidget {
  const PivotPollClosedView({required this.state, super.key});

  final PivotViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PivotTally? tally = state.tally;
    final PivotChoice you = state.vote!.choice;
    final PivotChoice? majority = tally?.majority;
    final bool readable = tally?.isReadable ?? false;
    final bool withMajority = majority != null && majority == you;

    return ListView(
      padding: _pad,
      children: <Widget>[
        Text(
          'THE CROWD SAYS',
          textAlign: TextAlign.center,
          style: AppText.label(size: 12, letterSpacing: 12 * 0.24),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (readable) ...<Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              _Share(
                value: tally!.yesShare,
                color: AppColors.accent,
                big: true,
              ),
              const Spacer(),
              _Share(
                value: 1 - tally.yesShare,
                color: AppColors.down,
                big: false,
              ),
            ],
          ),
          CrowdSplitBar(tally: tally, you: you),
          Row(
            children: <Widget>[
              Text(
                '${formatUsd(tally.total, symbol: false)} VOTES TODAY',
                style: AppText.label(size: 11),
              ),
              const Spacer(),
              Text('SAMPLE CLOSED 17:00', style: AppText.label(size: 11)),
            ],
          ),
          const SizedBox(height: AppSpacing.xl + 8),
          CornerTickFrame(
            onlyDiagonal: true,
            railColor: AppColors.accent.withValues(alpha: 0.45),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              color: AppColors.accent.withValues(alpha: 0.05),
              child: Column(
                children: <Widget>[
                  Text(
                    withMajority
                        ? 'YOU ARE WITH THE MAJORITY'
                        : 'YOU WENT AGAINST THE CROWD',
                    textAlign: TextAlign.center,
                    style: AppText.railLabel(
                      size: 26,
                      weight: FontWeight.w800,
                      letterSpacing: 26 * 0.14,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    withMajority
                        ? 'Comfortable, but cheap. A correct contrarian call pays '
                              '${PivotScoring.contrarianMultiple}× what this one will.'
                        : 'If you are right, this call pays '
                              '${PivotScoring.contrarianMultiple}× — conviction is '
                              'what the bonus rewards.',
                    textAlign: TextAlign.center,
                    style: AppText.body(
                      size: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else
          _LowVoteSlot(tally: tally),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: <Widget>[
            Expanded(
              child: HudStatCell(
                value: '+${PivotScoring.base}',
                label: 'IF RIGHT',
                mono: true,
                valueSize: 34,
              ),
            ),
            const SizedBox(width: AppSpacing.md + 4),
            Expanded(
              child: HudStatCell(
                value: '+${PivotScoring.contrarianTotal}',
                label: 'IF CONTRARIAN',
                mono: true,
                valueSize: 34,
                // Only lit when it could actually apply to this call.
                valueColor: readable && !withMajority
                    ? AppColors.textPrimary
                    : AppColors.textFaint,
              ),
            ),
            const SizedBox(width: AppSpacing.md + 4),
            const Expanded(
              child: HudStatCell(
                value: '0',
                label: 'IF WRONG',
                mono: true,
                valueSize: 34,
                valueColor: AppColors.down,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        if (state.outcome != null)
          HudButton(
            label: "SEE TODAY'S OUTCOME",
            height: 58,
            fontSize: 17,
            alignStart: true,
            trailing: const Icon(Icons.arrow_forward, color: AppColors.accent),
            onPressed: () =>
                ref.read(pivotControllerProvider.notifier).showOutcome(),
          )
        else if (state.outcomeError != null)
          FeedUnavailableRow(
            title: 'BTC AT 17:00 IST',
            subtitle: 'CLOSING PRICE UNAVAILABLE',
            onRetry: () => ref.read(pivotControllerProvider.notifier).load(),
          )
        else
          Text(
            'READING THE 17:00 PRICE FROM BINANCE…',
            textAlign: TextAlign.center,
            style: AppText.label(size: 11, color: AppColors.textFaint),
          ),
      ],
    );
  }
}

class _Share extends StatelessWidget {
  const _Share({required this.value, required this.color, required this.big});

  final double value;
  final Color color;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final double size = big ? 84 : 56;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(
          '${(value * 100).round()}',
          style: AppText.headline(size: size, color: color, height: 1),
        ),
        Text(
          '%',
          style: AppText.headline(size: size * 0.45, color: color),
        ),
      ],
    );
  }
}

/// The wireframe's low-vote variant, in the crowd's slot: too few votes for
/// a split to mean anything, so none is shown.
class _LowVoteSlot extends StatelessWidget {
  const _LowVoteSlot({required this.tally});

  final PivotTally? tally;

  @override
  Widget build(BuildContext context) {
    final int n = tally?.total ?? 0;
    return HudPanel(
      dashed: true,
      color: AppColors.caution.withValues(alpha: 0.55),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'CROWD SPLIT · HIDDEN BELOW ${PivotScoring.minCrowd} VOTES',
            style: AppText.label(size: 10.5, color: AppColors.caution),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              HatchBox(
                width: 110,
                height: 60,
                color: AppColors.caution.withValues(alpha: 0.3),
                border: AppColors.caution.withValues(alpha: 0.35),
              ),
              const SizedBox(width: AppSpacing.md + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'TOO FEW VOTES YET',
                      style: AppText.railLabel(
                        size: 20,
                        weight: FontWeight.w600,
                        color: AppColors.caution,
                        letterSpacing: 20 * 0.12,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs + 2),
                    Text(
                      '$n of ${PivotScoring.minCrowd} needed',
                      style: AppText.body(
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (tally != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              'SOURCE · ${tally!.source}',
              style: AppText.label(size: 9, color: AppColors.textFaint),
            ),
          ],
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- 1j: resolved

class PivotResolvedView extends ConsumerWidget {
  const PivotResolvedView({required this.state, super.key});

  final PivotViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PivotOutcome outcome = state.outcome!;
    final PivotVote vote = state.vote!;
    final bool right = outcome.winner == vote.choice;
    final PivotAward award = state.award ?? PivotAward.none;
    final Color c = right ? AppColors.accent : AppColors.down;
    final ProgressState progress = ref.watch(progressProvider);
    final PivotTally? tally = state.tally;
    final bool readable = tally?.isReadable ?? false;
    final double sideShare = !readable
        ? 0
        : (vote.choice == PivotChoice.yes
              ? tally!.yesShare
              : 1 - tally!.yesShare);

    return ListView(
      padding: _pad,
      children: <Widget>[
        Text(
          "TODAY'S OUTCOME",
          textAlign: TextAlign.center,
          style: AppText.label(size: 12, letterSpacing: 12 * 0.24),
        ),
        const SizedBox(height: AppSpacing.lg),
        CornerTickFrame(
          onlyDiagonal: true,
          color: c,
          railColor: c.withValues(alpha: 0.5),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xl - 4,
            ),
            color: c.withValues(alpha: 0.06),
            child: Column(
              children: <Widget>[
                Text(
                  right ? 'YOU WERE RIGHT' : 'NOT THIS TIME',
                  textAlign: TextAlign.center,
                  style: AppText.display(
                    size: 50,
                    color: c,
                    letterSpacing: 50 * 0.12,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'BTC CLOSED ${formatUsd(outcome.close)} · '
                  '${formatSignedPercent(outcome.changePercent, decimals: 2)}',
                  textAlign: TextAlign.center,
                  style: AppText.label(
                    size: 12.5,
                    weight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    letterSpacing: 12.5 * 0.14,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs + 2),
                SourceTag.fromAttribution(state.sourceLabel),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        HudPanel(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'POINTS EARNED',
                      style: AppText.label(size: 11),
                    ),
                  ),
                  Text(
                    '+${award.total}',
                    style: AppText.display(
                      size: 52,
                      color: award.total > 0
                          ? AppColors.accent
                          : AppColors.textFaint,
                      height: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              PointsLine(
                label: right
                    ? 'BASE · CORRECT CALL'
                    : 'BASE · NO PENALTY FOR TAKING PART',
                value: '+${award.base}',
                active: right,
              ),
              PointsLine(
                label: readable
                    ? 'CONTRARIAN BONUS · YOU SIDED WITH ${(sideShare * 100).round()}%'
                    : 'CONTRARIAN BONUS · CROWD TOO SMALL TO CALL',
                value: '+${award.contrarianBonus}',
                active: award.contrarianBonus > 0,
              ),
              PointsLine(
                label:
                    'STREAK MULTIPLIER · APPLIES AT '
                    '${PivotScoring.streakForMultiplier} DAYS',
                value: '×${award.multiplier.toStringAsFixed(1)}',
                active: award.multiplier > 1,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md + 4),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: PivotStreakPanel(streak: state.streak, risen: true),
              ),
              const SizedBox(width: AppSpacing.md + 4),
              Expanded(
                child: PivotPointsPanel(
                  title: 'TOTAL',
                  points: progress.totalDisciplinePoints,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Divider(color: AppColors.border, height: 1),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'NEXT PIVOT OPENS 09:00 TOMORROW',
          style: AppText.label(size: 12, letterSpacing: 12 * 0.22),
        ),
        const SizedBox(height: AppSpacing.xl),
        _PlayALevel(cleared: progress.clearedCount),
      ],
    );
  }
}

/// The funnel back into the Simulator — the Pivot's reason to exist.
class _PlayALevel extends ConsumerWidget {
  const _PlayALevel({required this.cleared});

  final int cleared;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: <Widget>[
        HudButton(
          label: 'PLAY A LEVEL',
          height: 62,
          fontSize: 20,
          alignStart: true,
          trailing: const Icon(Icons.arrow_forward, color: AppColors.accent),
          onPressed: () =>
              ref.read(shellTabProvider.notifier).select(AppTab.simulator),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'CAMPAIGN · $cleared LEVEL${cleared == 1 ? '' : 'S'} CLEARED',
          textAlign: TextAlign.center,
          style: AppText.label(size: 11, color: AppColors.textFaint),
        ),
      ],
    );
  }
}

// ------------------------------------------------------ the edges of the day

class PivotMissedView extends ConsumerWidget {
  const PivotMissedView({required this.state, super.key});

  final PivotViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PivotOutcome? outcome = state.outcome;
    return ListView(
      padding: _pad,
      children: <Widget>[
        const SizedBox(height: AppSpacing.xl),
        Text(
          'YOU SAT THIS ONE OUT',
          textAlign: TextAlign.center,
          style: AppText.railLabel(
            size: 24,
            weight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Today\'s poll closed at 17:00 IST without a vote from you. No '
          'penalty — the streak just starts again tomorrow.',
          textAlign: TextAlign.center,
          style: AppText.body(size: 15, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (outcome != null)
          HudPanel(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: <Widget>[
                Text("TODAY'S ANSWER", style: AppText.label(size: 11)),
                const SizedBox(height: AppSpacing.md),
                Text(
                  outcome.winner.label,
                  style: AppText.display(
                    size: 48,
                    color: outcome.winner == PivotChoice.yes
                        ? AppColors.accent
                        : AppColors.down,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'BTC CLOSED ${formatUsd(outcome.close)} · STRIKE ${formatUsd(outcome.strike)}',
                  textAlign: TextAlign.center,
                  style: AppText.label(size: 11),
                ),
                const SizedBox(height: AppSpacing.xs + 2),
                SourceTag.fromAttribution(state.sourceLabel),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'NEXT PIVOT OPENS 09:00 TOMORROW',
          textAlign: TextAlign.center,
          style: AppText.label(size: 12, letterSpacing: 12 * 0.22),
        ),
        const SizedBox(height: AppSpacing.xl),
        _PlayALevel(cleared: ref.watch(progressProvider).clearedCount),
      ],
    );
  }
}

class PivotBeforeOpenView extends ConsumerWidget {
  const PivotBeforeOpenView({required this.state, super.key});

  final PivotViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int points = ref.watch(progressProvider).totalDisciplinePoints;
    return ListView(
      padding: _pad,
      children: <Widget>[
        const SizedBox(height: AppSpacing.lg),
        Text(
          "TODAY'S QUESTION OPENS AT 09:00 IST",
          textAlign: TextAlign.center,
          style: AppText.label(size: 12, letterSpacing: 12 * 0.2),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: PivotCountdown(
            target: PivotClock.openUtc(state.dayKey),
            onElapsed: () => ref.read(pivotControllerProvider.notifier).sync(),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'One yes/no call on Bitcoin. The strike is its price at 09:00; the '
          'answer is its price at 17:00.',
          textAlign: TextAlign.center,
          style: AppText.body(size: 15, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: PivotStreakPanel(streak: state.streak)),
              const SizedBox(width: AppSpacing.md + 4),
              Expanded(
                child: PivotPointsPanel(title: 'POINTS', points: points),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PivotFailedView extends ConsumerWidget {
  const PivotFailedView({required this.state, super.key});

  final PivotViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: _pad,
      child: FeedFailurePane(
        title: 'PRICE FEED UNAVAILABLE',
        message:
            'Today\'s question needs Bitcoin\'s 09:00 IST price, and '
            'Binance could not be reached.\n\n${state.error ?? ''}',
        onRetry: () => ref.read(pivotControllerProvider.notifier).load(),
      ),
    );
  }
}

class PivotLoadingView extends StatelessWidget {
  const PivotLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _pad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text("TODAY'S INSTRUMENT", style: AppText.label(size: 11)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Text('BITCOIN', style: AppText.headline(size: 38)),
              const Spacer(),
              const FeedLoadingValue(width: 140, height: 34),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const FeedLoadingValue(width: double.infinity, height: 170),
        ],
      ),
    );
  }
}
