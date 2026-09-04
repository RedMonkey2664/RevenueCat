import 'package:flutter/material.dart';

import '../theme.dart';

/// The non-negotiable "this is not real money" marker (CLAUDE.md, DESIGN.md).
///
/// Must be visible during Simulator play and at Debrief. Never make it
/// dismissible, never shrink it to decoration.
class SimulatedBadge extends StatelessWidget {
  const SimulatedBadge({this.capital = '₹1,00,000', super.key});

  final String capital;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.simulatedBadge.withValues(alpha: 0.12),
        border: Border.all(
          color: AppColors.simulatedBadge.withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        'SIMULATED · $capital VIRTUAL CAPITAL',
        style: AppText.label(color: AppColors.simulatedBadge),
      ),
    );
  }
}

/// Louder variant for the development sample run, whose numbers are generated
/// rather than sourced. Nothing shipped to users may rely on this.
class SyntheticDataBadge extends StatelessWidget {
  const SyntheticDataBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 5,
      ),
      color: AppColors.down.withValues(alpha: 0.13),
      child: Row(
        children: <Widget>[
          const Icon(Icons.science_outlined, size: 11, color: AppColors.down),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              // One line. The two-line shouty version cost ~90pt of a phone
              // screen on the app's most important view.
              'SYNTHETIC DATA — NOT A REAL ASSET OR REAL PRICES',
              overflow: TextOverflow.ellipsis,
              style: AppText.label(color: AppColors.down, size: 8.5),
            ),
          ),
        ],
      ),
    );
  }
}
