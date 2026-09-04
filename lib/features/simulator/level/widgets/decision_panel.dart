import 'package:flutter/material.dart';

import '../../../../app/formatting.dart';
import '../../../../app/theme.dart';
import '../../engine/script_event_model.dart';

/// The three buttons, and only these three (ENGINE.md §2).
///
/// No countdown timer: ENGINE.md makes that an explicit post-Phase-3 maybe,
/// and a deliberate pause is more honest to "the discipline is the point".
///
/// This panel never says what the optimal move was — that is Debrief's job,
/// and saying it here would break blind mode.
class DecisionPanel extends StatelessWidget {
  const DecisionPanel({
    required this.flashTreatment,
    required this.portfolioValue,
    required this.pnlPercent,
    required this.onDecision,
    super.key,
  });

  final FlashTreatment flashTreatment;
  final double portfolioValue;
  final double pnlPercent;
  final ValueChanged<DecisionAction> onDecision;

  Color get _urgencyColor => switch (flashTreatment) {
        FlashTreatment.redFlashHard => AppColors.flashHard,
        FlashTreatment.amberFlashSoft => AppColors.flashSoft,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(top: BorderSide(color: _urgencyColor, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.warning_amber_rounded,
                    size: 16, color: _urgencyColor),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'MARKET EVENT · YOUR CALL',
                    style: AppText.label(color: _urgencyColor),
                  ),
                ),
                Text(
                  formatSignedPercent(pnlPercent),
                  style: AppText.mono(
                    size: 12,
                    weight: FontWeight.w700,
                    color: _urgencyColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _DecisionButton(
              action: DecisionAction.hold,
              subtitle: 'Ride it out',
              color: AppColors.textSecondary,
              onTap: onDecision,
            ),
            const SizedBox(height: AppSpacing.sm),
            _DecisionButton(
              action: DecisionAction.sell,
              subtitle: 'Everything to cash',
              color: AppColors.down,
              onTap: onDecision,
            ),
            const SizedBox(height: AppSpacing.sm),
            _DecisionButton(
              action: DecisionAction.buyDip,
              subtitle: 'Deploy the cash reserve',
              color: AppColors.accent,
              onTap: onDecision,
            ),
          ],
        ),
      ),
    );
  }
}

class _DecisionButton extends StatelessWidget {
  const _DecisionButton({
    required this.action,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final DecisionAction action;
  final String subtitle;
  final Color color;
  final ValueChanged<DecisionAction> onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => onTap(action),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.55)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: <Widget>[
              Text(
                action.label.toUpperCase(),
                style: AppText.mono(
                  size: 14,
                  weight: FontWeight.w700,
                  color: color,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(
                    size: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
