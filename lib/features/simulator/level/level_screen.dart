import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/formatting.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/hud.dart';
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
/// override, so the same screen serves campaign levels, Endless windows and
/// Custom Simulations without branching on which it is.
///
/// Artboards 1a–1d are four states of the same six regions — top bar, header,
/// chart, controls, a deliberate void, and the bottom panel. Only the state
/// colour and the bottom panel change; when something needs room, the chart
/// is the region that yields.
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

  /// Fixed heights of the control strips, so the chart/void split below can
  /// be worked out before layout rather than discovered by overflow.
  static const double _toolbarBand = 48 + AppSpacing.md;
  static const double _transportBand = 52 + AppSpacing.md;

  ChartSettings _settingsFor(bool blind) {
    final ChartSettings base = _settings ??= ref
        .read(chartPreferencesProvider)
        .loadSettings(defaultInterval: BarInterval.d1);

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

  void _openDebrief(ReplayController controller) {
    controller.reveal();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            DebriefScreen(state: ref.read(replayControllerProvider)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ReplayState state = ref.watch(replayControllerProvider);
    final ReplayController controller = ref.read(
      replayControllerProvider.notifier,
    );

    final bool blind = !state.isRevealed;
    final ChartSettings settings = _settingsFor(blind);
    final ChartLabels labels = blind
        ? BlindChartLabels(baselinePrice: state.level.candles.first.close)
        : const RealChartLabels();

    final _RunState run = _RunState.of(state);
    final Color stateColor = run.color;
    final int lastIndex = math.max(1, state.level.length - 1);

    final Widget body = Column(
      children: <Widget>[
        if (state.level.isSyntheticSample) const SyntheticDataBadge(),
        BlindModeHeader(
          dayNumber: state.dayNumber,
          totalDays: state.totalDays,
          portfolioValue: state.portfolioValue,
          pnlPercent: state.pnlPercent,
          revealedAssetName: state.isRevealed
              ? state.level.realAssetName
              : null,
          stateColor: run.railColor,
          // Advanced mode swaps the P&L chip for the exposure readout and
          // gains the position/cash split bar (artboard 1d).
          exposure: state.mode.isAdvanced && run != _RunState.idle
              ? state.exposure
              : null,
          idle: run == _RunState.idle,
          halted: run.isHalted,
          callMarks: <double>[
            for (final d in state.decisions)
              d.pausePoint.triggerIndex / lastIndex,
          ],
        ),
        if (run == _RunState.idle)
          Expanded(
            child: _IdleStage(
              feed: _AwaitingFeed(bars: state.totalDays),
              brief: _PreRunBrief(
                mode: state.mode,
                brief: LevelBrief.of(state.level),
                drawdowns: state.drawdownEpisodes.length,
                color: stateColor,
                onStart: controller.play,
              ),
            ),
          )
        else ...<Widget>[
          Expanded(
            child: _Stage(
              chart: _ChartFrame(
                state: state,
                settings: settings,
                labels: labels,
                halted: run.isHalted,
              ),
              toolbar: run.isHalted
                  ? null
                  : ChartToolbar(
                      settings: settings,
                      onChanged: _applySettings,
                      availableIntervals: _intervals,
                      showScaleToggle: !blind,
                      singleRow: true,
                    ),
              transport: run.isHalted || state.isFinished
                  ? null
                  : _TransportBar(
                      state: state,
                      controller: controller,
                      color: stateColor,
                    ),
              fillChart: state.isFinished,
              toolbarBand: _toolbarBand,
              transportBand: _transportBand,
            ),
          ),
          // The panel takes real estate from the chart rather than floating
          // over it, so the low the player is reacting to stays visible.
          if (state.isAwaitingDecision)
            DecisionPanel(onDecision: controller.submitDecision)
          else if (state.isFinished)
            _RunCompleteBar(onDebrief: () => _openDebrief(controller))
          else if (state.mode.isAdvanced)
            TradePanel(
              cash: state.portfolio.cash,
              exposure: state.exposure,
              onBuy: controller.buy,
              onSell: controller.sell,
            )
          else
            _StatusFooter(paused: state.status == ReplayStatus.paused),
        ],
      ],
    );

    return Scaffold(
      // The alarm warms the whole ground, not just the panel.
      backgroundColor: run.isHalted
          ? AppColors.alarmBackground
          : AppColors.background,
      appBar: HudTopBar(
        title: run.title(state),
        titleColor: stateColor,
        railColor: run.isHalted
            ? AppColors.down.withValues(alpha: 0.35)
            : AppColors.border,
        leading: IconButton(
          tooltip: 'Leave run',
          icon: Icon(
            Icons.close,
            color: run.isHalted
                ? AppColors.down.withValues(alpha: 0.8)
                : AppColors.textSecondary,
          ),
          onPressed: () {
            controller.pause();
            Navigator.of(context).maybePop();
          },
        ),
        trailing: run.pip,
      ),
      // Halted, the whole screen is ruled in red — the one moment in the app
      // that gets the alarm treatment edge to edge.
      body: run.isHalted
          ? DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.down.withValues(alpha: 0.45),
                ),
              ),
              child: body,
            )
          : body,
    );
  }
}

/// Artboard 1a's lower two-thirds: the viewfinder takes whatever the brief
/// leaves, but never less than [_minFeed]. On a short phone the whole stage
/// scrolls instead, so START RUN can never be pushed off-screen or clipped.
class _IdleStage extends StatelessWidget {
  const _IdleStage({required this.feed, required this.brief});

  final Widget feed;
  final Widget brief;

  static const double _minFeed = 140;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: _minFeed),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: feed,
                      ),
                    ),
                  ),
                  brief,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The middle band: chart, then the control strips, then the deliberate void.
///
/// The wireframes leave the bottom of the playing state empty on purpose —
/// "that void is what makes 1c land" — so the chart takes a share of the
/// space rather than all of it. On a short phone the chart keeps priority and
/// the void is what shrinks.
class _Stage extends StatelessWidget {
  const _Stage({
    required this.chart,
    required this.toolbar,
    required this.transport,
    required this.fillChart,
    required this.toolbarBand,
    required this.transportBand,
  });

  final Widget chart;
  final Widget? toolbar;
  final Widget? transport;
  final bool fillChart;
  final double toolbarBand;
  final double transportBand;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double controls =
            (toolbar == null ? 0 : toolbarBand) +
            (transport == null ? 0 : transportBand);
        final double free = math.max(0, box.maxHeight - controls);
        final double chartHeight = fillChart
            ? free
            : math.min(free, math.max(free * 0.62, 230));

        return Column(
          children: <Widget>[
            SizedBox(height: chartHeight, child: chart),
            if (toolbar != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              toolbar!,
            ],
            if (transport != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              transport!,
            ],
            const Spacer(),
          ],
        );
      },
    );
  }
}

/// The chart in its ruled frame, with the one overlay each state carries:
/// the OHLC readout while playing, the entry line in advanced mode, and the
/// drawdown chip while halted.
class _ChartFrame extends StatelessWidget {
  const _ChartFrame({
    required this.state,
    required this.settings,
    required this.labels,
    required this.halted,
  });

  final ReplayState state;
  final ChartSettings settings;
  final ChartLabels labels;
  final bool halted;

  @override
  Widget build(BuildContext context) {
    final List<Candle> visible = state.visibleCandles;

    final Widget overlay;
    if (halted) {
      overlay = _DrawdownChip(drawdown: _drawdownFromPeak(visible));
    } else if (state.mode.isAdvanced) {
      overlay = Text(
        'ENTRY ${formatRupees(state.level.startingBalance)} · '
        'AVG ${labels.price(_averageCost(state))}',
        style: AppText.mono(size: 10.5, color: AppColors.textSecondary),
      );
    } else {
      overlay = OhlcLegend(
        bar: visible.isEmpty ? null : visible.last,
        previous: visible.length > 1 ? visible[visible.length - 2] : null,
        labels: labels,
        indicatorLegend: <String>[
          for (final IndicatorSpec i in settings.indicators) i.label,
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: halted
                ? AppColors.down.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: Stack(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 30, 2, 2),
              child: ProChart(
                bars: visible,
                baseInterval: BarInterval.d1,
                settings: settings,
                labels: labels,
                // Keeps the newest candle in view as the replay advances,
                // unless the player has panned away to look at something.
                autoFollow: true,
                replayCursorIndex: visible.length - 1,
                percentBaseline: state.level.candles.first.close,
              ),
            ),
            Positioned(
              left: AppSpacing.sm + 2,
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: IgnorePointer(
                child: Align(alignment: Alignment.topLeft, child: overlay),
              ),
            ),
            PauseFlashOverlay(
              treatment: state.activePausePoint?.flashTreatment,
            ),
          ],
        ),
      ),
    );
  }

  /// How far the latest close sits below the highest close so far. Relative,
  /// so it is safe in blind mode.
  static double _drawdownFromPeak(List<Candle> bars) {
    if (bars.isEmpty) return 0;
    double peak = bars.first.close;
    for (final Candle c in bars) {
      if (c.close > peak) peak = c.close;
    }
    return peak <= 0 ? 0 : 1 - bars.last.close / peak;
  }

  /// Weighted average cost of the units currently held, rebuilt from the
  /// opening position and the trade log. Sells leave it unchanged, as they
  /// do on any broker statement.
  static double _averageCost(ReplayState state) {
    final double entry = state.level.candles.first.close;
    double units =
        state.level.startingBalance * _openingDeployedFraction / entry;
    double cost = units * entry;
    for (final t in state.trades) {
      if (t.unitsDelta > 0) {
        cost += t.unitsDelta * t.price;
        units += t.unitsDelta;
      } else if (units > 0) {
        final double avg = cost / units;
        units += t.unitsDelta;
        cost = avg * math.max(0, units);
      }
    }
    return units <= 1e-12 ? entry : cost / units;
  }

  /// Mirrors `Portfolio.initialDeployedFraction`, which is what the opening
  /// position was bought with.
  static const double _openingDeployedFraction = 0.75;
}

class _DrawdownChip extends StatelessWidget {
  const _DrawdownChip({required this.drawdown});

  final double drawdown;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.alarmBackground.withValues(alpha: 0.9),
        border: Border.all(color: AppColors.down.withValues(alpha: 0.6)),
      ),
      child: Text(
        'DRAWDOWN −${(drawdown * 100).round()}%',
        style: AppText.label(
          size: 11,
          weight: FontWeight.w600,
          color: AppColors.down,
        ),
      ),
    );
  }
}

/// Artboard 1a's chart slot before the tape rolls: a corner-ticked viewfinder
/// with a grid, a slow scan sweep and the bar count. Nothing about the series
/// is drawn until the run starts.
class _AwaitingFeed extends StatefulWidget {
  const _AwaitingFeed({required this.bars});

  final int bars;

  @override
  State<_AwaitingFeed> createState() => _AwaitingFeedState();
}

class _AwaitingFeedState extends State<_AwaitingFeed>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: AppMotion.ambientSlow,
  );

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool animate =
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (animate && !_sweep.isAnimating) _sweep.repeat();
    if (!animate && _sweep.isAnimating) _sweep.stop();

    return CornerTickFrame(
      railColor: AppColors.border,
      tick: 18,
      child: ClipRect(
        child: Stack(
          children: <Widget>[
            const Positioned.fill(child: CustomPaint(painter: _GridPainter())),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _sweep,
                builder: (BuildContext context, Widget? _) =>
                    FractionalTranslation(
                      translation: Offset(
                        0,
                        animate ? _sweep.value * 1.2 - 0.1 : 0.55,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                AppColors.accent.withValues(alpha: 0),
                                AppColors.accent.withValues(alpha: 0.07),
                                AppColors.accent.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'AWAITING FEED',
                      style: AppText.railLabel(
                        size: 22,
                        weight: FontWeight.w500,
                        color: AppColors.accent.withValues(alpha: 0.85),
                        letterSpacing: 22 * 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm + 2),
                  Text(
                    '${widget.bars} BARS BUFFERED',
                    style: AppText.label(size: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = AppColors.border.withValues(alpha: 0.7)
      ..strokeWidth = 0.6;
    const int cols = 9;
    const int rows = 6;
    for (int i = 1; i < cols; i++) {
      final double x = size.width * i / cols;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (int i = 1; i < rows; i++) {
      final double y = size.height * i / rows;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}

/// The pre-run brief (artboard 1a): what the player is walking into, without
/// telling them *which* crash it is — everything here is identity-free.
class _PreRunBrief extends StatelessWidget {
  const _PreRunBrief({
    required this.mode,
    required this.brief,
    required this.drawdowns,
    required this.color,
    required this.onStart,
  });

  final SimulationMode mode;

  /// Identity-free by construction (see [LevelBrief]) — naming the event here
  /// would make the whole run a memory test.
  final LevelBrief brief;

  /// Advanced mode grades the drawdowns the series finds for itself, so it
  /// counts those instead of scripted calls.
  final int drawdowns;

  final Color color;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final int months = math.max(1, brief.approxMonths);
    final int tests = mode.isBeginner ? brief.moments : drawdowns;
    final String testUnit = mode.isBeginner
        ? (tests == 1 ? 'CALL' : 'CALLS')
        : (tests == 1 ? 'DRAWDOWN' : 'DRAWDOWNS');

    final Color severity = switch (brief.severity) {
      BriefSeverity.historic || BriefSeverity.severe => AppColors.down,
      BriefSeverity.significant => AppColors.caution,
      BriefSeverity.mild => AppColors.textSecondary,
    };

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'YOU ARE ALREADY INVESTED.',
              style: AppText.headline(size: 25, letterSpacing: 25 * 0.04),
            ),
            Text(
              mode.isBeginner
                  ? 'THE FALL HAS BEGUN.'
                  : 'NOTHING WILL STOP IT FOR YOU.',
              style: AppText.headline(
                size: 25,
                color: const Color(0xFF4B5763),
                letterSpacing: 25 * 0.04,
              ),
            ),
            const SizedBox(height: AppSpacing.md + 4),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: HudStatCell(
                      value: '$months',
                      label: months == 1 ? 'MONTH' : 'MONTHS',
                      valueSize: 30,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: HudStatCell(
                      value: '$tests',
                      label: testUnit,
                      valueSize: 30,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: Semantics(
                      label: 'Severity ${brief.severity.label.toLowerCase()}',
                      child: HudStatCell(
                        value: brief.severity.label,
                        label: 'SEVERITY',
                        labelColor: severity,
                        borderColor: severity.withValues(alpha: 0.55),
                        fill: severity.withValues(alpha: 0.07),
                        valueWidget: _SeverityGlyphs(
                          count: brief.severity.index + 1,
                          color: severity,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md + 4),
            HudButton(
              label: 'START RUN',
              color: color,
              height: 58,
              fontSize: 22,
              letterSpacingEm: 0.3,
              onPressed: onStart,
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            Center(
              child: Text(
                'NO EXIT ONCE THE TAPE ROLLS — EXCEPT ×',
                style: AppText.label(size: 10.5, color: AppColors.textFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Severity as a row of warning triangles — a band, never a percentage, so
/// the brief cannot narrow the guess to one event.
class _SeverityGlyphs extends StatelessWidget {
  const _SeverityGlyphs({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Scales down rather than overflowing: HISTORIC is four triangles, and a
    // third of a 375pt phone is narrower than four at full size.
    return SizedBox(
      height: 33,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.bottomLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            for (int i = 0; i < count; i++)
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: CustomPaint(
                  size: const Size(20, 18),
                  painter: _TrianglePainter(color: color),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}

/// Play/pause plus the three real replay speeds (artboard 1b).
///
/// Speed is the one control that belongs to the *replay* rather than to the
/// chart, so it stays here rather than moving into [ChartToolbar].
class _TransportBar extends StatelessWidget {
  const _TransportBar({
    required this.state,
    required this.controller,
    required this.color,
  });

  final ReplayState state;
  final ReplayController controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bool isPlaying = state.status == ReplayStatus.playing;
    final bool locked = state.isAwaitingDecision || state.isFinished;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: SizedBox(
        height: 52,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              button: true,
              label: isPlaying ? 'Pause' : 'Play',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: locked
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        isPlaying ? controller.pause() : controller.play();
                      },
                child: Container(
                  width: 56,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.06),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: color,
                    size: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md + 4),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final ReplaySpeed speed in ReplaySpeed.values)
                      Expanded(
                        child: _SpeedSegment(
                          speed: speed,
                          selected: state.speed == speed,
                          color: color,
                          onTap: () => controller.setSpeed(speed),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedSegment extends StatelessWidget {
  const _SpeedSegment({
    required this.speed,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final ReplaySpeed speed;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String label = speed.label.replaceAll('x', '×');
    return Semantics(
      button: true,
      selected: selected,
      label: '${speed.multiplier} times speed',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: AppMotion.fast,
          alignment: Alignment.center,
          color: selected ? color.withValues(alpha: 0.13) : Colors.transparent,
          child: Text(
            label,
            style: AppText.body(
              size: 15,
              weight: FontWeight.w500,
              color: selected ? color : AppColors.textSecondary,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// The playing state's bottom line (artboard 1b). The right-hand half is a
/// promise blind mode makes: the player never knows when the next call is.
class _StatusFooter extends StatelessWidget {
  const _StatusFooter({required this.paused});

  final bool paused;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        // spaceBetween rather than a Spacer: a Spacer takes an equal flex
        // share beside Flexible text and squeezes it into an ellipsis.
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Flexible(
              child: Text(
                paused ? 'PAUSED' : 'NO DECISION PENDING',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.label(size: 10.5, color: AppColors.textFaint),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Text(
                'NEXT CALL UNKNOWN',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: AppText.label(size: 10.5, color: AppColors.textFaint),
              ),
            ),
          ],
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
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: HudButton(
          label: 'REVEAL & SCORE',
          style: HudButtonStyle.filled,
          height: 56,
          fontSize: 17,
          onPressed: onDebrief,
        ),
      ),
    );
  }
}

/// The run's current state, and the one colour, title and status pip that
/// follow from it. Centralised so the top bar, the header rail, the chart
/// frame and the ground cannot disagree.
enum _RunState {
  idle,
  playing,
  paused,
  halted,
  advanced,
  finished;

  static _RunState of(ReplayState state) {
    if (state.isAwaitingDecision) return _RunState.halted;
    if (state.isFinished) return _RunState.finished;
    if (state.status == ReplayStatus.idle) return _RunState.idle;
    if (state.mode.isAdvanced) return _RunState.advanced;
    if (state.status == ReplayStatus.paused) return _RunState.paused;
    return _RunState.playing;
  }

  bool get isHalted => this == _RunState.halted;

  /// Orange nominal, amber for advanced mode's no-safety-net trading, red
  /// only while halted.
  Color get color => switch (this) {
    _RunState.halted => AppColors.down,
    _RunState.advanced => AppColors.caution,
    _ => AppColors.accent,
  };

  /// The progress rail reads the tape rather than offering an action, so
  /// while nominal it is cyan — the brand orange is reserved for the title
  /// and the controls beneath it.
  Color get railColor => switch (this) {
    _RunState.halted => AppColors.down,
    _RunState.advanced => AppColors.caution,
    _ => AppColors.data,
  };

  /// Top-bar title. The halted state names the call number, because "which
  /// of nine is this" is what a player wants at that moment.
  String title(ReplayState state) => switch (this) {
    _RunState.halted =>
      'HALTED · CALL ${state.decisions.length + 1} OF '
          '${state.level.pausePoints.length}',
    _RunState.advanced => 'ADVANCED RUN',
    _RunState.finished => 'RUN COMPLETE',
    _ => state.mode.isAdvanced ? 'ADVANCED RUN' : 'BEGINNER RUN',
  };

  Widget get pip => switch (this) {
    // A red dot beside a grey word: armed, not alarmed.
    _RunState.idle => const StatusPip(
      label: 'ARMED',
      color: AppColors.textSecondary,
      dotColor: AppColors.down,
    ),
    _RunState.playing => const StatusPip(
      label: 'LIVE',
      color: AppColors.textSecondary,
      dotColor: AppColors.data,
    ),
    _RunState.paused => const StatusPip(
      label: 'PAUSED',
      color: AppColors.textFaint,
      pulse: false,
    ),
    _RunState.halted => const StatusPip(label: 'STOP', color: AppColors.down),
    _RunState.advanced => const StatusPip(
      label: 'NO HALTS',
      color: AppColors.textSecondary,
      showDot: false,
    ),
    _RunState.finished => const StatusPip(
      label: 'ENDED',
      color: AppColors.textFaint,
      pulse: false,
    ),
  };
}
