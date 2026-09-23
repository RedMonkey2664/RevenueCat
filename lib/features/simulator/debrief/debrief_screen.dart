import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/formatting.dart';
import '../../../app/shell_state.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/mascot.dart';
import '../../../app/widgets/discipline_badge.dart';
import '../../../app/widgets/hud.dart';
import '../../../app/widgets/hud_accordion.dart';
import '../../../app/widgets/simulated_badge.dart';
import '../../../core/services/progress_service.dart';
import '../../../core/services/purchases_service.dart';
import '../../../core/services/run_history_service.dart';
import '../../paywall/paywall_screen.dart';
import '../campaign/level_repository.dart';
import 'behaviour_trend.dart';
import '../engine/candle_model.dart';
import '../engine/discipline_score.dart';
import '../engine/level_brief.dart';
import '../engine/level_model.dart';
import '../engine/replay_controller.dart';
import '../engine/script_event_model.dart';
import '../level/level_screen.dart';
import 'run_record_builder.dart';

/// End of run: Discipline Score, simulated P&L, and the blind-mode reveal
/// (artboard 1e).
///
/// This is the only screen allowed to name the asset and the real dates
/// (ENGINE.md §3). Everything shown here is either measured from the run or
/// read from the level's authored `reveal_headline` — nothing is invented.
///
/// The score is the answer, so it leads; each of the four sections below is
/// there for the player who wants the working, and starts closed.
class DebriefScreen extends ConsumerStatefulWidget {
  const DebriefScreen({required this.state, super.key});

  final ReplayState state;

  @override
  ConsumerState<DebriefScreen> createState() => _DebriefScreenState();
}

class _DebriefScreenState extends ConsumerState<DebriefScreen> {
  /// History as it stood before this run was filed, so the comparison is
  /// against earlier runs rather than against itself.
  late final BehaviourTrend _trend = BehaviourTrend.from(
    priorHistory: ref.read(runHistoryProvider),
    state: widget.state,
  );

  @override
  void initState() {
    super.initState();
    _trend;
    // Recorded once, on arrival — the Debrief is the only place a run is
    // considered finished. The synthetic sample never touches real progress.
    if (!widget.state.level.isSyntheticSample) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _record());
    }
  }

  Future<void> _record() async {
    final ReplayState state = widget.state;
    unawaited(
      ref
          .read(progressProvider.notifier)
          .recordRun(
            levelId: state.level.id,
            score: state.disciplineScore.score,
            pnl: _finalValue(state) - state.level.startingBalance,
            mode: state.mode,
          ),
    );

    final LevelManifestEntry? entry = await _entryFor(state.level.id);
    final String title = entry == null
        ? state.level.realAssetName
        : shortRevealTitle(entry.revealTitle);
    await ref
        .read(runHistoryProvider.notifier)
        .add(RunRecordBuilder.fromRun(state, title: title));
  }

  Future<LevelManifestEntry?> _entryFor(String id) async {
    try {
      final List<LevelManifestEntry> all = await ref.read(
        levelManifestProvider.future,
      );
      for (final LevelManifestEntry e in all) {
        if (e.id == id) return e;
      }
    } on Object {
      // The manifest is bundled; if it cannot be read the run is simply not
      // a campaign run as far as the Debrief is concerned.
    }
    return null;
  }

  static double _finalValue(ReplayState state) =>
      state.portfolio.valueAt(state.level.candles.last.close);

  /// Back to wherever the run was started from — the campaign map, the
  /// Endless screen or the Custom Simulation setup.
  void _done() {
    Navigator.of(
      context,
      rootNavigator: true,
    ).popUntil((Route<dynamic> r) => r.isFirst);
  }

  /// Back to the campaign map specifically, whatever launched the run.
  void _toCampaign() {
    _done();
    simulatorNavigatorKey.currentState?.popUntil(
      (Route<dynamic> r) => r.isFirst,
    );
    ref.read(shellTabProvider.notifier).select(AppTab.simulator);
  }

  Future<void> _nextLevel(LevelManifestEntry next) async {
    final NavigatorState root = Navigator.of(context, rootNavigator: true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final ReplayState state = widget.state;

    if (!next.isFree && !ref.read(proAccessProvider).hasPro) {
      final LevelManifestEntry? current = await _entryFor(state.level.id);
      if (!mounted) return;
      final bool unlocked = await PaywallScreen.show(
        context,
        score: state.disciplineScore.score,
        practiceYear: current == null ? null : _yearOf(current.revealTitle),
        backdrop: <double>[for (final Candle c in state.level.candles) c.close],
        dismissLabel: 'NOT NOW — BACK TO THE DEBRIEF',
      );
      if (!unlocked) return;
    }

    try {
      if (!mounted) return;
      final SimulationLevel level = await runWithMascot(
        context,
        () => ref.read(levelRepositoryProvider).loadLevel(next),
        caption: 'ARMING THE NEXT RUN',
      );
      root.popUntil((Route<dynamic> r) => r.isFirst);
      unawaited(
        root.push(
          MaterialPageRoute<void>(
            builder: (_) => LevelScreen(level: level, mode: state.mode),
          ),
        ),
      );
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not load the next level: $error')),
      );
    }
  }

  static String? _yearOf(String revealTitle) =>
      RegExp(r'\b(19|20)\d{2}\b').firstMatch(revealTitle)?.group(0);

  @override
  Widget build(BuildContext context) {
    final ReplayState state = widget.state;
    final DisciplineScore score = state.disciplineScore;
    final double finalValue = _finalValue(state);
    final double pnl = finalValue - state.level.startingBalance;
    final double pnlPercent = pnl / state.level.startingBalance * 100;

    final List<LevelManifestEntry> manifest = ref
        .watch(levelManifestProvider)
        .maybeWhen(
          data: (List<LevelManifestEntry> all) => all,
          orElse: () => const <LevelManifestEntry>[],
        );
    final int at = manifest.indexWhere(
      (LevelManifestEntry e) => e.id == state.level.id,
    );
    final LevelManifestEntry? entry = at < 0 ? null : manifest[at];
    final LevelManifestEntry? next = at < 0
        ? null
        : manifest
              .skip(at + 1)
              .where((LevelManifestEntry e) => e.dataStatus.isPlayable)
              .firstOrNull;

    final int exact = score.moments
        .where((ScoredMoment m) => m.isFullCredit)
        .length;
    final int panics = score.moments
        .where((ScoredMoment m) => m.isPanic)
        .length;
    final int partial = score.momentsTested - exact - panics;

    final String code =
        entry?.maskedTitle ??
        (state.level.isSyntheticSample
            ? 'DEV'
            : state.level.revealFromStart
            ? 'CUSTOM'
            : 'ENDLESS');

    return Scaffold(
      appBar: HudTopBar(
        title: 'DEBRIEF',
        titleColor: AppColors.textPrimary,
        leading: HudBackButton(onTap: _done),
        trailing: Text(
          code,
          style: AppText.mono(size: 13, color: AppColors.textFaint),
        ),
      ),
      body: ListView(
        children: <Widget>[
          if (state.level.isSyntheticSample) const SyntheticDataBadge(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md + 4,
              AppSpacing.lg,
              AppSpacing.md + 4,
              AppSpacing.lg,
            ),
            child: DisciplineScoreHero(score: score.score),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(color: AppColors.border),
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: <Widget>[
                  _DebriefStat(
                    label: 'P&L',
                    value: formatSignedPercent(pnlPercent),
                    color: pnl >= 0 ? AppColors.up : AppColors.down,
                  ),
                  const VerticalDivider(width: 1, color: AppColors.border),
                  _DebriefStat(
                    label: state.mode.isBeginner ? 'CALLS' : 'TESTS',
                    value: score.wasTested
                        ? '$exact/${score.momentsTested}'
                        : '—',
                    color: AppColors.data,
                  ),
                  const VerticalDivider(width: 1, color: AppColors.border),
                  _DebriefStat(
                    label: 'DAYS',
                    value: '${state.level.length}',
                    color: AppColors.textPrimary,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md + 4,
              AppSpacing.sm + 2,
              AppSpacing.md + 4,
              0,
            ),
            child: Text(
              'SIMULATED · ${formatRupees(state.level.startingBalance)} VIRTUAL CAPITAL',
              textAlign: TextAlign.center,
              style: AppText.label(size: 9.5, color: AppColors.simulatedBadge),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md + 4,
              AppSpacing.lg,
              AppSpacing.md + 4,
              AppSpacing.md,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: next != null
                      ? HudButton(
                          label: 'NEXT LEVEL',
                          style: HudButtonStyle.filled,
                          height: 54,
                          fontSize: 17,
                          onPressed: () => _nextLevel(next),
                        )
                      : HudButton(
                          label: 'DONE',
                          style: HudButtonStyle.filled,
                          height: 54,
                          fontSize: 17,
                          onPressed: _done,
                        ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: HudButton(
                    label: 'CAMPAIGN',
                    style: HudButtonStyle.ghost,
                    height: 54,
                    fontSize: 17,
                    onPressed: _toCampaign,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md + 4),
            child: Column(
              children: <Widget>[
                HudAccordion(
                  title: 'TAKEAWAY',
                  child: Text(
                    _takeaway(score),
                    style: AppText.body(
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                if (_trend.line case final String line)
                  HudAccordion(
                    title: 'YOUR PATTERN',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          line,
                          style: AppText.body(
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        for (final String note in <String?>[
                          _trend.change,
                          _trend.depthNote,
                        ].whereType<String>()) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            note,
                            style: AppText.body(
                              size: 14,
                              color: AppColors.textFaint,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                HudAccordion(
                  title: 'THE REVEAL',
                  child: _Reveal(state: state, entry: entry),
                ),
                HudAccordion(
                  title: state.mode.isBeginner
                      ? 'CALL BREAKDOWN'
                      : 'TEST BREAKDOWN',
                  summary: score.wasTested
                      ? _BreakdownSummary(
                          exact: exact,
                          partial: partial,
                          panics: panics,
                        )
                      : null,
                  child: _Breakdown(state: state, score: score),
                ),
                HudAccordion(
                  title: 'P&L DETAILS',
                  child: _PnlDetails(
                    state: state,
                    finalValue: finalValue,
                    pnl: pnl,
                    pnlPercent: pnlPercent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  static String _takeaway(DisciplineScore score) {
    if (!score.wasTested) {
      return score.mode.isBeginner
          ? 'You did not reach a decision point in this run, so there is '
                'nothing to score yet.'
          : 'This window never fell far enough to test your nerve. '
                'Discipline is only measurable in a drawdown.';
    }
    if (score.panicCount == 0) {
      return 'You never cut a position while it was falling. That single '
          'habit is what the Discipline Score is measuring — and it is the '
          'one most runs fail.';
    }
    if (score.panicCount == 1) {
      return 'You sold into a fall once. That is the reflex this app exists '
          'to make visible: the loss became permanent the moment you took it.';
    }
    return 'You sold into a fall ${score.panicCount} times. Each one turned a '
        'paper loss into a real one — look at what the price did afterwards.';
  }
}

class _DebriefStat extends StatelessWidget {
  const _DebriefStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md + 4),
        child: Column(
          children: <Widget>[
            Text(label, style: AppText.label(size: 11)),
            const SizedBox(height: AppSpacing.sm + 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: AppText.display(size: 32, color: color, height: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The blind-mode reveal, finally.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.state, required this.entry});

  final ReplayState state;
  final LevelManifestEntry? entry;

  @override
  Widget build(BuildContext context) {
    final DateTime from = state.level.candles.first.date;
    final DateTime to = state.level.candles.last.date;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'YOU WERE TRADING',
          style: AppText.label(
            color: AppColors.accent,
            weight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        Text(state.level.realAssetName, style: AppText.title(size: 19)),
        if (entry != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            entry!.revealTitle.toUpperCase(),
            style: AppText.label(size: 11, weight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: AppSpacing.xs + 2),
        Text(
          // Real dates, finally — blind mode is over.
          '${from.dateLabel} → ${to.dateLabel}',
          style: AppText.mono(size: 12, color: AppColors.textSecondary),
        ),
        // Held back until now on purpose: naming the event earlier would
        // turn every replay into a memory test (ENGINE.md §3).
        if ((state.level.description ?? '').isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text(
            state.level.description!,
            style: AppText.body(size: 14, color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Played in ${state.mode.label} mode.',
          style: AppText.body(size: 12, color: AppColors.textFaint),
        ),
      ],
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.state, required this.score});

  final ReplayState state;
  final DisciplineScore score;

  @override
  Widget build(BuildContext context) {
    if (!score.wasTested) {
      return Text(
        'Nothing in this run was gradeable.',
        style: AppText.body(size: 13, color: AppColors.textSecondary),
      );
    }
    final List<RecordedDecision> decisions = state.decisions;
    return Column(
      children: <Widget>[
        for (int i = 0; i < score.moments.length; i++) ...<Widget>[
          _MomentRow(
            moment: score.moments[i],
            headline: state.mode.isBeginner && i < decisions.length
                ? decisions[i].pausePoint.revealHeadline
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _MomentRow extends StatelessWidget {
  const _MomentRow({required this.moment, this.headline});

  final ScoredMoment moment;

  /// What actually happened next — the level's authored reveal for this
  /// pause point.
  final String? headline;

  @override
  Widget build(BuildContext context) {
    final Color color = moment.isPanic
        ? AppColors.down
        : moment.isFullCredit
        ? AppColors.up
        : AppColors.caution;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md - 2),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  moment.label.toUpperCase(),
                  style: AppText.label(size: 11, weight: FontWeight.w600),
                ),
              ),
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
          const SizedBox(height: AppSpacing.xs + 2),
          Text(moment.detail, style: AppText.body(size: 13)),
          if (headline != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              headline!,
              style: AppText.body(size: 12.5, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _PnlDetails extends StatelessWidget {
  const _PnlDetails({
    required this.state,
    required this.finalValue,
    required this.pnl,
    required this.pnlPercent,
  });

  final ReplayState state;
  final double finalValue;
  final double pnl;
  final double pnlPercent;

  @override
  Widget build(BuildContext context) {
    final LevelBrief brief = LevelBrief.of(state.level);
    final Color pnlColor = pnl >= 0 ? AppColors.up : AppColors.down;
    return Column(
      children: <Widget>[
        _row('STARTING CAPITAL', formatRupees(state.level.startingBalance)),
        _row('FINAL VALUE', formatRupees(finalValue)),
        _row(
          'SIMULATED P&L',
          '${pnl >= 0 ? '+' : '-'}${formatRupees(pnl.abs())} · '
              '${formatSignedPercent(pnlPercent)}',
          color: pnlColor,
        ),
        _row(
          'DEEPEST FALL IN THE WINDOW',
          '−${(brief.deepestDrawdown * 100).toStringAsFixed(1)}%',
        ),
        _row('CASH AT THE END', formatRupees(state.portfolio.cash)),
      ],
    );
  }

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: AppText.label(size: 10.5))),
          Text(
            value,
            style: AppText.mono(
              size: 13,
              weight: FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

extension on DateTime {
  String get dateLabel {
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '$day ${months[month - 1]} $year';
  }
}

/// "4✓ 3~ 1✕" beside CALL BREAKDOWN, with the marks drawn as icons so they
/// render the same on every platform.
class _BreakdownSummary extends StatelessWidget {
  const _BreakdownSummary({
    required this.exact,
    required this.partial,
    required this.panics,
  });

  final int exact;
  final int partial;
  final int panics;

  @override
  Widget build(BuildContext context) {
    final TextStyle n = AppText.mono(size: 12, color: AppColors.textFaint);
    Widget mark(int count, Widget glyph) => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('$count', style: n),
        glyph,
      ],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        mark(
          exact,
          const Icon(Icons.check, size: 12, color: AppColors.textFaint),
        ),
        const SizedBox(width: AppSpacing.sm),
        mark(partial, Text('~', style: n)),
        const SizedBox(width: AppSpacing.sm),
        mark(
          panics,
          const Icon(Icons.close, size: 12, color: AppColors.textFaint),
        ),
      ],
    );
  }
}
