import 'package:flutter/material.dart';

import '../../../../app/formatting.dart';
import '../../../../app/theme.dart';

/// Advanced mode's always-live trade bar.
///
/// Unlike the beginner mode's [DecisionPanel], this never blocks playback and
/// is never gated on a scripted moment — the whole point of advanced mode is
/// that the player can act on any candle.
///
/// Size is a fraction, not a rupee amount: fractions stay meaningful as the
/// portfolio moves, and they keep the panel to one tap plus one chip on a
/// phone-sized screen.
class TradePanel extends StatefulWidget {
  const TradePanel({
    required this.cash,
    required this.exposure,
    required this.onBuy,
    required this.onSell,
    super.key,
  });

  final double cash;

  /// Share of portfolio value currently held in the asset, 0..1.
  final double exposure;

  /// Called with the fraction of remaining cash to deploy.
  final ValueChanged<double> onBuy;

  /// Called with the fraction of the held position to liquidate.
  final ValueChanged<double> onSell;

  @override
  State<TradePanel> createState() => _TradePanelState();
}

class _TradePanelState extends State<TradePanel> {
  static const List<double> _sizes = <double>[0.25, 0.5, 1];

  double _size = 0.25;

  String _sizeLabel(double f) => f == 1 ? 'MAX' : '${(f * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final bool canBuy = widget.cash > 0.01;
    final bool canSell = widget.exposure > 0.0001;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text('SIZE', style: AppText.label()),
                const SizedBox(width: AppSpacing.sm),
                for (final double f in _sizes)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: _SizeChip(
                      label: _sizeLabel(f),
                      selected: _size == f,
                      onTap: () => setState(() => _size = f),
                    ),
                  ),
                const Spacer(),
                // Flexible so a large cash figure shrinks instead of pushing
                // the row off a narrow phone (same trap as the transport bar).
                Flexible(
                  child: Text(
                    'CASH ${formatRupees(widget.cash)}',
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style:
                        AppText.mono(size: 11, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: _TradeButton(
                    label: 'BUY',
                    color: AppColors.up,
                    enabled: canBuy,
                    disabledHint: 'No cash left',
                    onTap: () => widget.onBuy(_size),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _TradeButton(
                    label: 'SELL',
                    color: AppColors.down,
                    enabled: canSell,
                    disabledHint: 'No position',
                    onTap: () => widget.onSell(_size),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _ExposureBar(exposure: widget.exposure),
          ],
        ),
      ),
    );
  }
}

/// A single glance at how invested the player is — the number advanced mode's
/// Discipline Score actually reads.
class _ExposureBar extends StatelessWidget {
  const _ExposureBar({required this.exposure});

  final double exposure;

  @override
  Widget build(BuildContext context) {
    final double clamped = exposure.clamp(0.0, 1.0);
    return Row(
      children: <Widget>[
        Text('INVESTED', style: AppText.label()),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: clamped,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.accent,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '${(clamped * 100).round()}%',
          style: AppText.mono(size: 11, weight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _SizeChip extends StatelessWidget {
  const _SizeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
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
          label,
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

class _TradeButton extends StatelessWidget {
  const _TradeButton({
    required this.label,
    required this.color,
    required this.enabled,
    required this.disabledHint,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool enabled;

  /// Shown in place of the label when the move is impossible — the button
  /// stays visible and says why, rather than silently doing nothing.
  final String disabledHint;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color effective = enabled ? color : AppColors.textFaint;
    return Material(
      color: effective.withValues(alpha: enabled ? 0.1 : 0.04),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: effective.withValues(alpha: 0.55)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              enabled ? label : disabledHint.toUpperCase(),
              style: AppText.mono(
                size: enabled ? 15 : 10,
                weight: FontWeight.w700,
                color: effective,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
