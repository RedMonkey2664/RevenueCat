import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/formatting.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/feed_state.dart';
import '../../../app/widgets/hud.dart';
import '../../../core/market/candle.dart';
import '../../chart/model/chart_labels.dart';
import '../../chart/model/chart_types.dart';
import '../../chart/pro_chart.dart';
import '../model/pivot_models.dart';

/// Pieces shared by the Daily Pivot's screens.

/// The tape: BTC/USDT in 15-minute bars with the strike marked across it.
///
/// The same chart widget as everywhere else in the app (CLAUDE.md: one
/// chart), in its compact, axis-free form.
class PivotTape extends StatelessWidget {
  const PivotTape({
    required this.bars,
    required this.strike,
    required this.height,
    this.framed = true,
    super.key,
  });

  final List<Candle> bars;
  final double? strike;
  final double height;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final Widget chart = bars.isEmpty
        ? const Center(child: FeedLoadingValue(width: 160, height: 14))
        : ProChart(
            bars: bars,
            baseInterval: BarInterval.m15,
            settings: const ChartSettings(interval: BarInterval.m15),
            labels: const RealChartLabels(currencySymbol: r'$'),
            interactive: false,
            showAxes: false,
            showLastPriceLine: false,
            referenceLine: strike == null
                ? null
                : ChartReferenceLine(
                    price: strike!,
                    label: 'STRIKE ${formatUsd(strike!, symbol: false)}',
                    color: AppColors.caution,
                  ),
          );

    return SizedBox(
      height: height,
      child: framed
          ? DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
              ),
              child: Padding(padding: const EdgeInsets.all(4), child: chart),
            )
          : chart,
    );
  }
}

/// A ticking HH:MM:SS to a fixed instant. Calls [onElapsed] once when it
/// reaches zero so the screen can move to the next phase.
class PivotCountdown extends StatefulWidget {
  const PivotCountdown({
    required this.target,
    this.onElapsed,
    this.size = 64,
    super.key,
  });

  final DateTime target;
  final VoidCallback? onElapsed;
  final double size;

  @override
  State<PivotCountdown> createState() => _PivotCountdownState();
}

class _PivotCountdownState extends State<PivotCountdown> {
  Timer? _timer;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (!_fired && !widget.target.isAfter(DateTime.now().toUtc())) {
        _fired = true;
        widget.onElapsed?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Duration left = widget.target.difference(DateTime.now().toUtc());
    if (left.isNegative) left = Duration.zero;
    String two(int v) => v.toString().padLeft(2, '0');
    final String hm = '${two(left.inHours)}:${two(left.inMinutes % 60)}';
    final String s = ':${two(left.inSeconds % 60)}';

    return Semantics(
      label: '${left.inHours} hours ${left.inMinutes % 60} minutes left',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(hm, style: AppText.display(size: widget.size, height: 1)),
          Text(
            s,
            style: AppText.display(
              size: widget.size * 0.55,
              color: AppColors.textFaint,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// 09:00 OPEN ──●──────── 17:00 CLOSE, filled to now.
class PivotDayRail extends StatelessWidget {
  const PivotDayRail({required this.dayKey, required this.now, super.key});

  final String dayKey;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final DateTime open = PivotClock.openUtc(dayKey);
    final DateTime close = PivotClock.closeUtc(dayKey);
    final double f =
        (now.difference(open).inSeconds / close.difference(open).inSeconds)
            .clamp(0.0, 1.0);
    return Column(
      children: <Widget>[
        SizedBox(
          height: 14,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) => Stack(
              alignment: Alignment.centerLeft,
              children: <Widget>[
                Container(height: 6, color: AppColors.border),
                Container(
                  height: 6,
                  width: c.maxWidth * f,
                  color: AppColors.accent,
                ),
                Positioned(
                  left: (c.maxWidth * f - 1).clamp(0.0, c.maxWidth - 2),
                  child: Container(
                    width: 2,
                    height: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        Row(
          children: <Widget>[
            Text(
              '09:00 OPEN',
              style: AppText.label(size: 10, color: AppColors.textFaint),
            ),
            const Spacer(),
            Text(
              '17:00 CLOSE',
              style: AppText.label(size: 10, color: AppColors.textFaint),
            ),
          ],
        ),
      ],
    );
  }
}

/// The big YES / NO voting target.
class PivotVoteButton extends StatefulWidget {
  const PivotVoteButton({
    required this.choice,
    required this.color,
    required this.onTap,
    super.key,
  });

  final PivotChoice choice;
  final Color color;
  final VoidCallback? onTap;

  @override
  State<PivotVoteButton> createState() => _PivotVoteButtonState();
}

class _PivotVoteButtonState extends State<PivotVoteButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final Color c = widget.color;
    return Semantics(
      button: true,
      label: '${widget.choice.label}, ${widget.choice.meaning}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                widget.onTap!();
              },
        child: AnimatedContainer(
          duration: AppMotion.fast,
          height: 132,
          decoration: BoxDecoration(
            color: c.withValues(alpha: _down ? 0.22 : 0.1),
            border: Border.all(color: c.withValues(alpha: 0.85), width: 1.3),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                widget.choice.label,
                style: AppText.display(
                  size: 50,
                  weight: FontWeight.w700,
                  color: c,
                  letterSpacing: 50 * 0.18,
                  height: 1,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                widget.choice.meaning,
                style: AppText.label(
                  size: 12,
                  weight: FontWeight.w500,
                  color: c.withValues(alpha: 0.8),
                  letterSpacing: 12 * 0.22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// STREAK · 4 DAYS · ▮▮▮▮▯
class PivotStreakPanel extends StatelessWidget {
  const PivotStreakPanel({required this.streak, this.risen = false, super.key});

  final int streak;

  /// Today's call just extended it — the ▲ in artboard 1j.
  final bool risen;

  @override
  Widget build(BuildContext context) {
    const int goal = PivotScoring.streakForMultiplier;
    final int left = goal - streak;
    return HudPanel(
      padding: const EdgeInsets.all(AppSpacing.md + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('STREAK', style: AppText.label(size: 11)),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text('$streak', style: AppText.display(size: 40, height: 1)),
              const SizedBox(width: AppSpacing.sm + 2),
              if (risen)
                const Icon(
                  Icons.arrow_drop_up,
                  color: AppColors.positive,
                  size: 26,
                )
              else
                Text(
                  streak == 1 ? 'DAY' : 'DAYS',
                  style: AppText.headline(
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentBar(
            filled: streak.clamp(0, goal),
            total: goal,
            height: 6,
            color: AppColors.data,
          ),
          if (risen) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              left > 0
                  ? '$left MORE FOR ×${PivotScoring.streakMultiplier}'
                  : '×${PivotScoring.streakMultiplier} ACTIVE',
              style: AppText.label(size: 9.5, color: AppColors.textFaint),
            ),
          ],
        ],
      ),
    );
  }
}

/// TOTAL / POINTS · 1,240 · DISCIPLINE POINTS · NOT MONEY
class PivotPointsPanel extends StatelessWidget {
  const PivotPointsPanel({
    required this.title,
    required this.points,
    super.key,
  });

  final String title;
  final int points;

  @override
  Widget build(BuildContext context) {
    return HudPanel(
      padding: const EdgeInsets.all(AppSpacing.md + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: AppText.label(size: 11)),
          const SizedBox(height: AppSpacing.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _grouped(points),
              style: AppText.display(size: 40, height: 1),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // The framing rule, wherever points are shown (DESIGN.md).
          Text(
            'DISCIPLINE POINTS · NOT MONEY',
            style: AppText.label(size: 9.5, color: AppColors.textFaint),
          ),
        ],
      ),
    );
  }

  static String _grouped(int n) => formatUsd(n, symbol: false);
}

/// The crowd split bar with the player's side marked.
class CrowdSplitBar extends StatelessWidget {
  const CrowdSplitBar({required this.tally, required this.you, super.key});

  final PivotTally tally;
  final PivotChoice? you;

  @override
  Widget build(BuildContext context) {
    final double yes = tally.yesShare;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double split = c.maxWidth * yes;
        final double marker = you == PivotChoice.no
            ? (split + 24).clamp(0.0, c.maxWidth - 2)
            : (split - 24).clamp(0.0, c.maxWidth - 2);
        return SizedBox(
          height: 100,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              if (you != null)
                Positioned(
                  left: (marker - 28).clamp(0.0, c.maxWidth - 56),
                  top: 0,
                  child: SizedBox(
                    width: 56,
                    child: Text(
                      'YOU ▼',
                      textAlign: TextAlign.center,
                      style: AppText.label(
                        size: 11,
                        weight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              if (you != null)
                Positioned(
                  left: marker,
                  top: 20,
                  child: Container(
                    width: 1.5,
                    height: 44,
                    color: AppColors.textPrimary,
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                top: 40,
                height: 50,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      flex: (yes * 1000).round().clamp(1, 999),
                      child: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: AppSpacing.md + 4),
                        color: AppColors.data.withValues(alpha: 0.4),
                        child: Text(
                          'YES',
                          style: AppText.label(
                            size: 12,
                            weight: FontWeight.w600,
                            color: AppColors.data,
                          ),
                        ),
                      ),
                    ),
                    Container(width: 3, color: AppColors.textPrimary),
                    Expanded(
                      flex: ((1 - yes) * 1000).round().clamp(1, 999),
                      child: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(
                          right: AppSpacing.md + 4,
                        ),
                        color: AppColors.down.withValues(alpha: 0.12),
                        child: Text(
                          'NO',
                          style: AppText.label(
                            size: 12,
                            weight: FontWeight.w600,
                            color: AppColors.down,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One line of the points ledger: "BASE · CORRECT CALL ........ +10".
class PointsLine extends StatelessWidget {
  const PointsLine({
    required this.label,
    required this.value,
    this.active = true,
    super.key,
  });

  final String label;
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: AppText.body(
                size: 12.5,
                color: active ? AppColors.textPrimary : AppColors.textFaint,
                letterSpacing: 12.5 * 0.03,
              ),
            ),
          ),
          Text(
            value,
            style: AppText.mono(
              size: 14,
              color: active ? AppColors.positive : AppColors.textFaint,
            ),
          ),
        ],
      ),
    );
  }
}
