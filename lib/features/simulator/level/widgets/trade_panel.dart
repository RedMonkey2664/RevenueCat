import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/formatting.dart';
import '../../../../app/theme.dart';
import '../../../../app/widgets/hud.dart';

/// Advanced mode's always-live trade bar (artboard 1d).
///
/// Unlike the beginner mode's `DecisionPanel`, this never blocks playback and
/// is never gated on a scripted moment — the whole point of advanced mode is
/// that the player can act on any candle.
///
/// Size is a fraction, not a rupee amount: fractions stay meaningful as the
/// portfolio moves, and they keep the panel to one tap plus one chip.
/// How invested the player is lives in the header's position bar, so it is
/// not repeated here.
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

  double _size = 0.5;

  @override
  Widget build(BuildContext context) {
    final bool canBuy = widget.cash > 0.01;
    final bool canSell = widget.exposure > 0.0001;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md + 2,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    'CASH ${formatRupees(widget.cash)}',
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label(size: 11),
                  ),
                ),
                const Spacer(),
                Text('SIZE', style: AppText.label(size: 11)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            Row(
              children: <Widget>[
                for (int i = 0; i < _sizes.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: _SizeChip(
                      label: '${(_sizes[i] * 100).round()}%',
                      selected: _size == _sizes[i],
                      onTap: () => setState(() => _size = _sizes[i]),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md - 2),
            Row(
              children: <Widget>[
                Expanded(
                  child: HudButton(
                    // Stays visible and says why, rather than silently doing
                    // nothing, when the move is impossible.
                    label: canBuy ? 'BUY' : 'NO CASH',
                    color: AppColors.accent,
                    height: 58,
                    fontSize: canBuy ? 24 : 15,
                    onPressed: canBuy ? () => widget.onBuy(_size) : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.md + 2),
                Expanded(
                  child: HudButton(
                    label: canSell ? 'SELL' : 'NO POSITION',
                    color: AppColors.down,
                    height: 58,
                    fontSize: canSell ? 24 : 15,
                    onPressed: canSell ? () => widget.onSell(_size) : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
    return Semantics(
      button: true,
      selected: selected,
      label: 'Size $label',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: AppMotion.fast,
          height: kMinTouchTarget,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.1)
                : Colors.transparent,
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Text(
            label,
            style: AppText.body(
              size: 15,
              weight: FontWeight.w500,
              color: selected ? AppColors.accent : AppColors.textSecondary,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
