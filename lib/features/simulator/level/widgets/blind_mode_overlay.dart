import 'package:flutter/material.dart';

import '../../../../app/formatting.dart';
import '../../../../app/theme.dart';

/// The console HUD during play.
///
/// This is where blind mode is enforced in the UI: the symbol slot shows a
/// masked ticker and the date slot shows a relative day counter. Nothing here
/// may leak the asset or the era — that is what makes a campaign level a real
/// test on replay instead of a memory quiz (ENGINE.md §3).
///
/// Structured to artboards 1a–1d of `Market Nerve HUD.dc.html`: identity on
/// the left, money on the right, one rail underneath. The canvas keeps this
/// band the *same height in all four states* — its note on 1d is explicit that
/// when the trade panel needs room "the chart gives up 40pt here rather than
/// the header. Same six regions, different loser." So nothing in here grows or
/// shrinks with state; only colour changes.
class BlindModeHeader extends StatelessWidget {
  const BlindModeHeader({
    required this.dayNumber,
    required this.totalDays,
    required this.portfolioValue,
    required this.pnl,
    required this.pnlPercent,
    this.revealedAssetName,
    this.stateColor,
    this.exposure,
    super.key,
  });

  final int dayNumber;
  final int totalDays;
  final double portfolioValue;
  final double pnl;
  final double pnlPercent;

  /// Non-null only after the Debrief lifts blind mode.
  final String? revealedAssetName;

  /// Tints the rail and the masked plate to the run's current state — mint
  /// nominal, amber while playing, red while halted. Defaults to the accent.
  final Color? stateColor;

  /// Advanced mode only: share of the portfolio held in the asset. When
  /// present it replaces the P&L chip with the canvas's exposure readout and
  /// adds the position/cash split bar.
  final double? exposure;

  Color get _state => stateColor ?? AppColors.accent;

  @override
  Widget build(BuildContext context) {
    final bool positive = pnl >= 0;
    final Color pnlColor = positive ? AppColors.up : AppColors.down;
    final double progress =
        totalDays <= 1 ? 0 : (dayNumber - 1) / (totalDays - 1);

    // A large falling figure takes the softer red: full-strength #FF4D4D at
    // 32pt reads as an error dialog rather than as a price.
    final Color valueColor = positive
        ? AppColors.textPrimary
        : (pnlPercent <= -15 ? AppColors.downSoft : AppColors.textPrimary);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md - 2,
        AppSpacing.md,
        AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _state.withValues(alpha: 0.18)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Identity, left.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _TickerPlate(name: revealedAssetName, stateColor: _state),
                    const SizedBox(height: AppSpacing.xs + 2),
                    Text(
                      // A relative counter, never a real date, in play.
                      'DAY $dayNumber / $totalDays',
                      overflow: TextOverflow.ellipsis,
                      style: AppText.label(size: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Money, right.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      formatRupees(portfolioValue),
                      style: AppText.display(
                        size: 32,
                        weight: FontWeight.w700,
                        color: valueColor,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (exposure == null)
                    _PnlChip(
                      pnlPercent: pnlPercent,
                      color: pnlColor,
                      positive: positive,
                    )
                  else
                    RichText(
                      text: TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: 'EXPOSURE ',
                            style: AppText.label(size: 10),
                          ),
                          TextSpan(
                            text: '${(exposure! * 100).round()}%',
                            style: AppText.label(
                              size: 10,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm + 2),

          // Replay progress: the one piece of "how far in am I" that blind
          // mode allows, since it is relative and reveals no date. The canvas
          // marks the playhead with a hairline tick above the fill.
          _ProgressRail(progress: progress.clamp(0.0, 1.0), color: _state),

          if (exposure != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _PositionBar(exposure: exposure!.clamp(0.0, 1.0)),
          ],

          const SizedBox(height: AppSpacing.sm),
          // The virtual-capital framing, folded in under the rail so it is
          // always on screen without costing its own row (CLAUDE.md makes it
          // non-negotiable, but it does not have to be a banner).
          Row(
            children: <Widget>[
              Icon(
                Icons.shield_outlined,
                size: 11,
                color: AppColors.simulatedBadge.withValues(alpha: 0.9),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'SIMULATED · ₹1,00,000 VIRTUAL CAPITAL',
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label(
                    color: AppColors.simulatedBadge.withValues(alpha: 0.9),
                    size: 9,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The rail, with a playhead tick. Hand-drawn rather than a
/// LinearProgressIndicator because the tick has to sit *above* the bar.
class _ProgressRail extends StatelessWidget {
  const _ProgressRail({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final double x = c.maxWidth * progress;
          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: ColoredBox(color: color.withValues(alpha: 0.14)),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: x,
                child: ColoredBox(color: color),
              ),
              // The playhead. 1px, taller than the rail, and the one place
              // near-white appears in the HUD.
              Positioned(
                left: (x - 0.5).clamp(0.0, c.maxWidth - 1),
                top: -4,
                width: 1,
                height: 11,
                child: const ColoredBox(color: AppColors.textPrimary),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Advanced mode's position/cash split.
class _PositionBar extends StatelessWidget {
  const _PositionBar({required this.exposure});

  final double exposure;

  @override
  Widget build(BuildContext context) {
    final int held = (exposure * 100).round();
    return Row(
      children: <Widget>[
        Text('POSITION', style: AppText.label(size: 9)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: SizedBox(
            height: 8,
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: held.clamp(1, 100),
                  child: ColoredBox(
                    color: AppColors.accent.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  flex: (100 - held).clamp(1, 100),
                  child: ColoredBox(
                    color: AppColors.accent.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text('CASH ${100 - held}%', style: AppText.label(size: 9)),
      ],
    );
  }
}

/// The masked symbol slot. Hatched while blind, named once revealed.
class _TickerPlate extends StatelessWidget {
  const _TickerPlate({this.name, required this.stateColor});

  final String? name;
  final Color stateColor;

  @override
  Widget build(BuildContext context) {
    final bool blind = name == null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: blind ? null : stateColor.withValues(alpha: 0.14),
        border: Border.all(
          color: blind
              ? AppColors.border
              : stateColor.withValues(alpha: 0.7),
        ),
      ),
      child: Text(
        blind ? '████ ██' : name!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.display(
          size: 22,
          weight: FontWeight.w700,
          color: blind
              ? AppColors.textSecondary.withValues(alpha: 0.45)
              : stateColor,
          letterSpacing: 22 * 0.14,
        ),
      ),
    );
  }
}

/// The bordered P&L chip. Square, and it carries the direction glyph the
/// canvas uses rather than a plus/minus sign alone.
class _PnlChip extends StatelessWidget {
  const _PnlChip({
    required this.pnlPercent,
    required this.color,
    required this.positive,
  });

  final double pnlPercent;
  final Color color;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        '${positive ? '▲' : '▼'} '
        '${pnlPercent.abs().toStringAsFixed(1)}%',
        style: AppText.mono(size: 11, weight: FontWeight.w600, color: color),
      ),
    );
  }
}
