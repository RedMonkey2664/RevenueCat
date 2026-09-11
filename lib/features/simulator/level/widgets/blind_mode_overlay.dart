import 'package:flutter/material.dart';

import '../../../../app/formatting.dart';
import '../../../../app/theme.dart';
import '../../../../app/widgets/hud.dart';

/// The console HUD during play.
///
/// This is where blind mode is enforced in the UI: the symbol slot shows a
/// redaction plate and the date slot shows a relative day counter. Nothing
/// here may leak the asset or the era — that is what makes a campaign level a
/// real test on replay instead of a memory quiz (ENGINE.md §3).
///
/// Structured to artboards 1a–1d: identity on the left, money on the right,
/// one rail underneath. Only colour and the idle state's taller plate change
/// between states — when the trade panel needs room, the chart gives it up,
/// not this band.
class BlindModeHeader extends StatelessWidget {
  const BlindModeHeader({
    required this.dayNumber,
    required this.totalDays,
    required this.portfolioValue,
    required this.pnlPercent,
    this.revealedAssetName,
    this.stateColor = AppColors.accent,
    this.exposure,
    this.idle = false,
    this.halted = false,
    this.callMarks = const <double>[],
    super.key,
  });

  final int dayNumber;
  final int totalDays;
  final double portfolioValue;
  final double pnlPercent;

  /// Non-null only when blind mode is off (a Custom Simulation, or after the
  /// Debrief).
  final String? revealedAssetName;

  /// Tints the rail — cyan nominal, amber advanced, red halted.
  final Color stateColor;

  /// Advanced mode only: share of the portfolio held in the asset. When
  /// present it replaces the P&L chip with the exposure readout and adds the
  /// position/cash split bar (artboard 1d).
  final double? exposure;

  /// Artboard 1a: the taller plate, "ASSET CLASSIFIED · DATES SEALED", and
  /// the day counter under the money.
  final bool idle;

  /// Artboard 1c: the figure and its chip turn red.
  final bool halted;

  /// Where on the rail the calls already made fell, as 0..1 fractions.
  /// Past calls only — marking where future calls sit would tell the player
  /// when the next test is coming.
  final List<double> callMarks;

  @override
  Widget build(BuildContext context) {
    final bool positive = pnlPercent >= 0;
    final double progress = totalDays <= 1
        ? 0
        : (dayNumber - 1) / (totalDays - 1);

    final Color valueColor = halted
        ? AppColors.downSoft
        : AppColors.textPrimary;
    final Color chipColor = positive
        ? AppColors.up
        : (halted ? AppColors.down : AppColors.caution);

    final String dayLabel = 'DAY $dayNumber / $totalDays';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md + 2,
        AppSpacing.md,
        AppSpacing.sm + 4,
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
                    FractionallySizedBox(
                      widthFactor: idle ? 0.96 : 0.9,
                      alignment: Alignment.centerLeft,
                      child: _Identity(
                        name: revealedAssetName,
                        tall: idle,
                        tint: halted ? AppColors.down : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      // A relative counter, never a real date, in play.
                      idle ? 'ASSET CLASSIFIED · DATES SEALED' : dayLabel,
                      maxLines: 2,
                      style: AppText.label(size: 10.5, weight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Money, right. Flexible, so a wide figure scales down rather
              // than squeezing the redaction plate to nothing.
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        formatRupees(portfolioValue),
                        style: AppText.display(
                          size: 34,
                          weight: FontWeight.w700,
                          color: valueColor,
                          height: 1.05,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs + 2),
                    if (idle)
                      Text(dayLabel, style: AppText.label(size: 10.5))
                    else if (exposure == null)
                      _PnlChip(
                        pnlPercent: pnlPercent,
                        color: chipColor,
                        positive: positive,
                      )
                    else
                      Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            TextSpan(
                              text: 'EXPOSURE ',
                              style: AppText.label(size: 11),
                            ),
                            TextSpan(
                              text: '${(exposure! * 100).round()}%',
                              style: AppText.label(
                                size: 11,
                                weight: FontWeight.w600,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Replay progress: the one piece of "how far in am I" blind mode
          // allows, since it is relative and reveals no date.
          _ProgressRail(
            progress: progress.clamp(0.0, 1.0),
            color: stateColor,
            marks: callMarks,
            showPlayhead: !idle,
          ),

          if (exposure != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm + 4),
            _PositionBar(exposure: exposure!.clamp(0.0, 1.0)),
          ],

          const SizedBox(height: AppSpacing.sm + 2),
          // The virtual-capital framing, folded under the rail so it is
          // always on screen without costing a banner. CLAUDE.md makes the
          // word SIMULATED non-negotiable during play.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: 'SIMULATED',
                    style: AppText.label(
                      size: 10,
                      weight: FontWeight.w600,
                      color: AppColors.simulatedBadge,
                    ),
                  ),
                  TextSpan(
                    text: ' · VIRTUAL CAPITAL · NO REAL MONEY IS AT RISK',
                    style: AppText.label(size: 10, color: AppColors.textFaint),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The redaction plate, or the instrument's name once blind mode is off.
class _Identity extends StatelessWidget {
  const _Identity({required this.name, required this.tall, required this.tint});

  final String? name;
  final bool tall;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    if (name == null) {
      return RedactionPlate(
        cells: tall ? 4 : 6,
        height: tall ? 64 : 30,
        tall: tall,
        tint: tint,
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.6)),
      ),
      child: Text(
        name!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.railLabel(
          size: 15,
          weight: FontWeight.w700,
          color: AppColors.accent,
          letterSpacing: 15 * 0.1,
        ),
      ),
    );
  }
}

/// The rail, with a playhead tick and amber marks where calls were made.
/// Hand-drawn because the tick has to stand proud of the bar.
class _ProgressRail extends StatelessWidget {
  const _ProgressRail({
    required this.progress,
    required this.color,
    required this.marks,
    required this.showPlayhead,
  });

  final double progress;
  final Color color;
  final List<double> marks;
  final bool showPlayhead;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 4,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          // A sliver of fill even on day 1, so the rail reads as "started".
          final double x = (c.maxWidth * progress).clamp(6.0, c.maxWidth);
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
              for (final double m in marks)
                Positioned(
                  left: (c.maxWidth * m - 1).clamp(0.0, c.maxWidth - 2),
                  top: -1,
                  width: 3,
                  height: 6,
                  child: const ColoredBox(color: AppColors.caution),
                ),
              if (showPlayhead)
                Positioned(
                  left: (x - 1).clamp(0.0, c.maxWidth - 2),
                  top: -6,
                  width: 2,
                  height: 16,
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
        Text('POSITION', style: AppText.label(size: 10.5)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: SizedBox(
            height: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (held > 0)
                  Expanded(
                    flex: held,
                    child: ColoredBox(
                      color: AppColors.accent.withValues(alpha: 0.55),
                    ),
                  ),
                if (held > 0 && held < 100) const SizedBox(width: 3),
                if (held < 100)
                  Expanded(
                    flex: 100 - held,
                    child: ColoredBox(
                      color: AppColors.accent.withValues(alpha: 0.1),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text('CASH ${100 - held}%', style: AppText.label(size: 10.5)),
      ],
    );
  }
}

/// The bordered P&L chip, with the direction glyph.
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        '${positive ? '▲' : '▼'} ${pnlPercent.abs().toStringAsFixed(1)}%',
        style: AppText.mono(size: 13, weight: FontWeight.w600, color: color),
      ),
    );
  }
}
