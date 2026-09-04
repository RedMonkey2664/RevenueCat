import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../app/widgets/simulated_badge.dart';
import '../debrief/debrief_screen.dart';
import '../engine/level_brief.dart';
import '../engine/level_model.dart';
import '../engine/replay_controller.dart';
import '../engine/simulation_mode.dart';
import 'widgets/blind_mode_overlay.dart';
import 'widgets/chart_view.dart';
import 'widgets/console_chrome.dart';
import 'widgets/decision_panel.dart';
import 'widgets/pause_flash_overlay.dart';
import 'widgets/rsi_panel.dart';
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
  bool _sma = true;
  bool _rsi = false;

  @override
  Widget build(BuildContext context) {
    final ReplayState state = ref.watch(replayControllerProvider);
    final ReplayController controller =
        ref.read(replayControllerProvider.notifier);

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
          ConsoleChrome(
            smaEnabled: _sma,
            rsiEnabled: _rsi,
            onToggleSma: () => setState(() => _sma = !_sma),
            onToggleRsi: () => setState(() => _rsi = !_rsi),
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
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.sm,
                        ),
                        child: ChartView(
                          candles: state.visibleCandles,
                          baselinePrice: state.level.candles.first.close,
                          blindMode: !state.isRevealed,
                          showSma: _sma,
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
                // Inside the flexible region, not below it. As a fixed
                // sibling of the chart it pushed the column past the bottom
                // of shorter screens; here it takes space from the chart
                // instead of overflowing.
                if (_rsi)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.sm,
                      right: AppSpacing.md,
                      bottom: AppSpacing.sm,
                    ),
                    child: RsiPanel(candles: state.visibleCandles),
                  ),
              ],
            ),
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
      // Centred when there is room, scrollable when there is not. With the
      // RSI panel open on a short phone the chart area shrinks below this
      // overlay's natural height, and a plain Center overflowed it.
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) =>
            SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              // Clamped: with the RSI panel open on a short phone the
              // available height can drop below the padding, and a negative
              // minHeight is a hard layout error.
              minHeight: (constraints.maxHeight - AppSpacing.md * 2)
                  .clamp(0.0, double.infinity),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
            Text(
              'You are already invested.',
              style: AppText.title(size: 22),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
                          unit: brief.approxMonths == 1 ? 'MONTH' : 'MONTHS',
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
                            BriefSeverity.mild => AppColors.textSecondary,
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
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                'The asset and the dates stay hidden until the debrief. '
                '${mode.blurb}',
                textAlign: TextAlign.center,
                style: AppText.body(size: 12, color: AppColors.textFaint),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Play/pause plus the three real replay speeds.
///
/// The locked extra speeds (0.5x, 8x) and the rest of the console chrome are
/// Phase 7 work — deliberately absent here rather than half-built.
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
