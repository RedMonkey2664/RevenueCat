import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../app/widgets/simulated_badge.dart';
import '../../../core/market/candle.dart';
import '../../chart/model/chart_labels.dart';
import '../../chart/model/chart_types.dart';
import '../../chart/pro_chart.dart';
import '../../chart/services/chart_preferences.dart';
import '../../chart/widgets/chart_toolbar.dart';
import '../../chart/widgets/ohlc_legend.dart';
import '../debrief/debrief_screen.dart';
import '../engine/level_brief.dart';
import '../engine/level_model.dart';
import '../engine/replay_controller.dart';
import '../engine/simulation_mode.dart';
import 'widgets/blind_mode_overlay.dart';
import 'widgets/decision_panel.dart';
import 'widgets/pause_flash_overlay.dart';
import 'widgets/trade_panel.dart';

/// The core screen: chart + blind-mode chrome + decision panel at pause points.
///
/// It receives a [SimulationLevel] and hands it to the engine through a scoped
/// override, so the same screen serves campaign levels and Endless windows
/// without branching on which it is.
class LevelScreen extends StatelessWidget {
  const LevelScreen({required this.level, required this.mode, super.key});

  final SimulationLevel level;
  final SimulationMode mode;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      // `Override` is not exported by flutter_riverpod 3.x, so this list
      // stays untyped.
      overrides: [
        currentLevelProvider.overrideWithValue(level),
        currentModeProvider.overrideWithValue(mode),
      ],
      child: const _LevelScreenBody(),
    );
  }
}

class _LevelScreenBody extends ConsumerStatefulWidget {
  const _LevelScreenBody();

  @override
  ConsumerState<_LevelScreenBody> createState() => _LevelScreenBodyState();
}

class _LevelScreenBodyState extends ConsumerState<_LevelScreenBody> {
  ChartSettings? _settings;

  /// A level's bundled bars are daily, so only daily and coarser are offered.
  /// The chart folds those locally; a finer timeframe would need data the
  /// level does not carry, and DESIGN.md's replacement rule is that a control
  /// the host cannot serve is absent rather than present-and-inert.
  static const List<BarInterval> _intervals = <BarInterval>[
    BarInterval.d1,
    BarInterval.w1,
    BarInterval.mo1,
  ];

  ChartSettings _settingsFor(bool blind) {
    final ChartSettings base = _settings ??=
        ref.read(chartPreferencesProvider).loadSettings(
              defaultInterval: BarInterval.d1,
            );

    // Blind mode pins the scale to percent so the gridlines land on round
    // moves. This is presentation only -- what actually keeps absolute prices
    // off the screen is [BlindChartLabels], which rebases every value the
    // chart is asked to render.
    return blind ? base.copyWith(scale: PriceScale.percent) : base;
  }

  void _applySettings(ChartSettings next) {
    setState(() => _settings = next);
    ref.read(chartPreferencesProvider).saveSettings(next);
  }

  @override
  Widget build(BuildContext context) {
    final ReplayState state = ref.watch(replayControllerProvider);
    final ReplayController controller =
        ref.read(replayControllerProvider.notifier);

    final bool blind = !state.isRevealed;
    final ChartSettings settings = _settingsFor(blind);
    final List<Candle> visible = state.visibleCandles;
    final ChartLabels labels = blind
        ? BlindChartLabels(baselinePrice: state.level.candles.first.close)
        : const RealChartLabels();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${state.mode.label.toUpperCase()} RUN',
          style: AppText.label(),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            controller.pause();
            Navigator.of(context).maybePop();
          },
        ),
      ),
      body: Column(
        children: <Widget>[
          if (state.level.isSyntheticSample) const SyntheticDataBadge(),
          BlindModeHeader(
            dayNumber: state.dayNumber,
            totalDays: state.totalDays,
            portfolioValue: state.portfolioValue,
            pnl: state.pnl,
            pnlPercent: state.pnlPercent,
            revealedAssetName:
                state.isRevealed ? state.level.realAssetName : null,
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Expanded(
                  child: Stack(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.sm,
                          AppSpacing.xl,
                          AppSpacing.xs,
                          AppSpacing.sm,
                        ),
                        child: ProChart(
                          bars: visible,
                          baseInterval: BarInterval.d1,
                          settings: settings,
                          labels: labels,
                          // Keeps the newest candle in view as the replay
                          // advances, unless the player has panned away to
                          // look at something.
                          autoFollow: true,
                          replayCursorIndex: visible.length - 1,
                          percentBaseline: state.level.candles.first.close,
                        ),
                      ),
                      Positioned(
                        left: AppSpacing.md,
                        top: AppSpacing.xs,
                        right: AppSpacing.md,
                        child: IgnorePointer(
                          child: OhlcLegend(
                            bar: visible.isEmpty ? null : visible.last,
                            previous: visible.length > 1
                                ? visible[visible.length - 2]
                                : null,
                            labels: labels,
                            indicatorLegend: <String>[
                              for (final IndicatorSpec i in settings.indicators)
                                i.label,
                            ],
                          ),
                        ),
                      ),
                      PauseFlashOverlay(
                        treatment: state.activePausePoint?.flashTreatment,
                      ),
                      if (state.status == ReplayStatus.idle)
                        _StartOverlay(
                          mode: state.mode,
                          brief: LevelBrief.of(state.level),
                          onStart: controller.play,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Hidden until the run starts. Before that the pre-run brief covers
          // the chart, so the toolbar controls something the player cannot
          // reach — and on a 375x667 phone its 76pt pushed the START RUN
          // button below the fold of the brief's scroll view.
          if (state.status != ReplayStatus.idle)
            ChartToolbar(
              settings: settings,
              onChanged: _applySettings,
              availableIntervals: _intervals,
              showScaleToggle: !blind,
            ),
          _TransportBar(state: state, controller: controller),
          // The panel takes real estate from the chart rather than floating
          // over it. Overlaying looked tidier but hid the bottom of the
          // drawdown behind the panel — the player could not see the low they
          // were being asked to react to. The panel is kept compact instead,
          // so the chart above it stays legible.
          if (state.isAwaitingDecision)
            DecisionPanel(
              flashTreatment: state.activePausePoint!.flashTreatment,
              portfolioValue: state.portfolioValue,
              pnlPercent: state.pnlPercent,
              onDecision: controller.submitDecision,
            )
          else if (state.mode.isAdvanced && !state.isFinished)
            TradePanel(
              cash: state.portfolio.cash,
              exposure: state.exposure,
              onBuy: controller.buy,
              onSell: controller.sell,
            )
          else if (state.isFinished)
            _RunCompleteBar(
              onDebrief: () {
                controller.reveal();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DebriefScreen(
                      state: ref.read(replayControllerProvider),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _StartOverlay extends StatelessWidget {
  const _StartOverlay({
    required this.mode,
    required this.brief,
    required this.onStart,
  });

  final SimulationMode mode;

  /// Identity-free by construction (see [LevelBrief]) — naming the event here
  /// would make the whole run a memory test.
  final LevelBrief brief;

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background.withValues(alpha: 0.88),
      // The brief scrolls; the button does not.
      //
      // Both used to live in one scroll view, which meant that whenever the
      // content was taller than the chart area the CTA went under the fold —
      // on an iPhone SE it was cut off by about 20pt, so the primary action
      // of the screen was half-visible and untappable. Pinning it costs
      // nothing on a tall phone and fixes the short one outright.
      child: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'You are already invested.',
                    style: AppText.title(size: 22),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: cardDecoration(raised: true),
                      child: Column(
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              _BriefStat(
                                value: brief.approxMonths.toString(),
                                unit: brief.approxMonths == 1
                                    ? 'MONTH'
                                    : 'MONTHS',
                              ),
                              Container(
                                width: 1,
                                height: 28,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                ),
                                color: AppColors.border,
                              ),
                              _BriefStat(
                                value: brief.moments.toString(),
                                unit: brief.moments == 1 ? 'CALL' : 'CALLS',
                              ),
                              Container(
                                width: 1,
                                height: 28,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                ),
                                color: AppColors.border,
                              ),
                              _BriefStat(
                                value: brief.severity.label,
                                unit: 'SEVERITY',
                                color: switch (brief.severity) {
                                  BriefSeverity.historic ||
                                  BriefSeverity.severe =>
                                    AppColors.down,
                                  BriefSeverity.significant =>
                                    AppColors.simulatedBadge,
                                  BriefSeverity.mild =>
                                    AppColors.textSecondary,
                                },
                                small: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            brief.body,
                            textAlign: TextAlign.center,
                            style: AppText.body(
                              size: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Text(
                      'The asset and the dates stay hidden until the debrief. '
                      '${mode.blurb}',
                      textAlign: TextAlign.center,
                      style: AppText.body(
                        size: 12,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.md,
              bottom: AppSpacing.lg,
            ),
            child: FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.background,
                shape: const RoundedRectangleBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
              ),
              child: Text(
                'START RUN',
                style: AppText.mono(
                  size: 14,
                  weight: FontWeight.w700,
                  color: AppColors.background,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Play/pause plus the three real replay speeds.
///
/// Speed is the one chart control that belongs to the *replay* rather than to
/// the chart, so it stays here rather than moving into [ChartToolbar] with
/// the rest of the console.
class _TransportBar extends StatelessWidget {
  const _TransportBar({required this.state, required this.controller});

  final ReplayState state;
  final ReplayController controller;

  @override
  Widget build(BuildContext context) {
    final bool isPlaying = state.status == ReplayStatus.playing;
    final bool locked = state.isAwaitingDecision || state.isFinished;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: locked
                ? null
                : (isPlaying ? controller.pause : controller.play),
            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
            color: AppColors.accent,
            // Compact visually, but never below the 44pt minimum tap target
            // — shrinking the hit box to fit the row was the wrong trade.
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(
              width: kMinTouchTarget,
              height: kMinTouchTarget,
            ),
            iconSize: 24,
          ),
          const SizedBox(width: AppSpacing.sm),
          for (final ReplaySpeed speed in ReplaySpeed.values)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: _SpeedChip(
                speed: speed,
                selected: state.speed == speed,
                onTap: () => controller.setSpeed(speed),
              ),
            ),
          const Spacer(),
          // Flexible, not fixed. With a Spacer soaking up the slack, an
          // over-wide fixed trailing group cannot shrink and the bar
          // overflows the screen — which it did, by 60pt, on a 390pt phone.
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (state.mode.isBeginner && state.totalMoments > 0) ...<Widget>[
                  Flexible(
                    child: Text(
                      '${state.momentsResolved}/${state.totalMoments}',
                      overflow: TextOverflow.ellipsis,
                      style: AppText.label(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Flexible(
                  child: Text(
                    switch (state.status) {
                      ReplayStatus.idle => 'READY',
                      ReplayStatus.playing => 'RUNNING',
                      ReplayStatus.paused => 'PAUSED',
                      ReplayStatus.awaitingDecision => 'DECIDE',
                      ReplayStatus.finished => 'COMPLETE',
                    },
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: AppText.label(
                      color: state.isAwaitingDecision
                          ? AppColors.flashHard
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({
    required this.speed,
    required this.selected,
    required this.onTap,
  });

  final ReplaySpeed speed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.14)
              : Colors.transparent,
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          speed.label,
          style: AppText.mono(
            size: 11,
            weight: FontWeight.w700,
            color: selected ? AppColors.accent : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// End of playback. The Debrief is a separate screen so blind mode is lifted
/// by an explicit step rather than by the run simply ending.
class _RunCompleteBar extends StatelessWidget {
  const _RunCompleteBar({required this.onDebrief});

  final VoidCallback onDebrief;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AppColors.surfaceRaised,
      child: SafeArea(
        top: false,
        child: FilledButton(
          onPressed: onDebrief,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.background,
            shape: const RoundedRectangleBorder(),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          ),
          child: Text(
            'REVEAL & SCORE',
            style: AppText.mono(
              size: 14,
              weight: FontWeight.w700,
              color: AppColors.background,
              letterSpacing: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

/// One figure in the pre-play brief.
class _BriefStat extends StatelessWidget {
  const _BriefStat({
    required this.value,
    required this.unit,
    this.color = AppColors.textPrimary,
    this.small = false,
  });

  final String value;
  final String unit;
  final Color color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          style: AppText.mono(
            size: small ? 13 : 20,
            weight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(unit, style: AppText.label(size: 8.5)),
      ],
    );
  }
}
