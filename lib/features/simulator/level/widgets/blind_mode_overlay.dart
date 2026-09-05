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
/// Deliberately compact. An earlier version stood 180–230pt tall, which on a
/// 667pt phone left the chart — the entire point of the screen — squeezed into
/// a strip. Everything here is one glanceable band: identity, clock, money.
class BlindModeHeader extends StatelessWidget {
  const BlindModeHeader({
    required this.dayNumber,
    required this.totalDays,
    required this.portfolioValue,
    required this.pnl,
    required this.pnlPercent,
    this.revealedAssetName,
    super.key,
  });

  final int dayNumber;
  final int totalDays;
  final double portfolioValue;
  final double pnl;
  final double pnlPercent;

  /// Non-null only after the Debrief lifts blind mode.
  final String? revealedAssetName;

  @override
  Widget build(BuildContext context) {
    final bool positive = pnl >= 0;
    final Color pnlColor = positive ? AppColors.up : AppColors.down;
    final double progress = totalDays <= 1 ? 0 : (dayNumber - 1) / (totalDays - 1);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        // Flexible, not fixed: blind mode's plate is four
                        // blocks wide, but after the reveal it holds a real
                        // asset name — "Nasdaq Composite Index" overflowed
                        // this row by 166pt on a phone. The day counter is
                        // the shorter of the two, so it yields first.
                        Flexible(
                          child: _TickerPlate(name: revealedAssetName),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            // A relative counter, never a real date, in play.
                            'DAY $dayNumber/$totalDays',
                            overflow: TextOverflow.ellipsis,
                            style: AppText.label(size: 10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatRupees(portfolioValue),
                        style: AppText.mono(
                          size: 30,
                          weight: FontWeight.w700,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _PnlPill(
                pnl: pnl,
                pnlPercent: pnlPercent,
                color: pnlColor,
                positive: positive,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // The virtual-capital framing, folded into the progress rail so it
          // is always on screen without costing its own row (CLAUDE.md makes
          // it non-negotiable, but it does not have to be a banner).
          Row(
            children: <Widget>[
              Icon(
                Icons.shield_outlined,
                size: 11,
                color: AppColors.simulatedBadge.withValues(alpha: 0.9),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'SIMULATED · ₹1,00,000 VIRTUAL',
                style: AppText.label(
                  color: AppColors.simulatedBadge.withValues(alpha: 0.9),
                  size: 9,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // Replay progress: the one piece of "how far in am I" that blind
          // mode allows, since it is relative and reveals no date.
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 2,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.accentSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The masked (or revealed) symbol.
class _TickerPlate extends StatelessWidget {
  const _TickerPlate({this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final bool blind = name == null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: blind
            ? AppColors.borderStrong.withValues(alpha: 0.5)
            : AppColors.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: blind ? AppColors.borderStrong : AppColors.accent,
          width: 0.8,
        ),
      ),
      child: Text(
        blind ? '████' : name!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.mono(
          size: 11,
          weight: FontWeight.w700,
          color: blind ? AppColors.textFaint : AppColors.accent,
        ),
      ),
    );
  }
}

class _PnlPill extends StatelessWidget {
  const _PnlPill({
    required this.pnl,
    required this.pnlPercent,
    required this.color,
    required this.positive,
  });

  final double pnl;
  final double pnlPercent;
  final Color color;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.normal,
      curve: AppMotion.curve,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.chip,
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                positive ? Icons.trending_up : Icons.trending_down,
                size: 13,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                formatSignedPercent(pnlPercent),
                style: AppText.mono(
                  size: 14,
                  weight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          Text(
            '${positive ? '+' : '-'}${formatRupees(pnl.abs())}',
            style: AppText.mono(size: 10, color: color.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}
