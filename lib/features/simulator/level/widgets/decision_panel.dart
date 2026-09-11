import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../app/widgets/hud.dart';
import '../../engine/script_event_model.dart';

/// The three calls, and only these three (ENGINE.md §2). Artboard 1c.
///
/// This is a panel and not an overlay because the player has to be able to
/// see the drawdown they are being asked to react to: the panel pushes the
/// chart up rather than covering the low.
///
/// No countdown timer. ENGINE.md makes that an explicit post-Phase-3 maybe,
/// and the wireframe commits to it in copy: "NO TIMER. THE TAPE WAITS FOR
/// YOU."
///
/// This panel never says what the optimal move was — that is the Debrief's
/// job, and saying it here would break blind mode.
class DecisionPanel extends StatelessWidget {
  const DecisionPanel({required this.onDecision, super.key});

  final ValueChanged<DecisionAction> onDecision;

  @override
  Widget build(BuildContext context) {
    // On a short phone the panel tightens rather than taking the chart's
    // last pixels: the low still has to be visible above it.
    final bool compact = MediaQuery.sizeOf(context).height < 720;
    final double gap = compact ? AppSpacing.sm + 2 : AppSpacing.sm + 6;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        compact ? AppSpacing.md : AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        // The alarm light spilling upward, rather than a flat fill.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            AppColors.down.withValues(alpha: 0.07),
            AppColors.alarmBackground,
          ],
        ),
        border: Border(
          top: BorderSide(color: AppColors.down.withValues(alpha: 0.3)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            RuledLabel(
              text: 'WHAT DO YOU DO?',
              color: AppColors.down,
              textColor: AppColors.textFaint,
              size: compact ? 15 : 17,
            ),
            SizedBox(height: compact ? AppSpacing.md : AppSpacing.md + 4),

            // The colour assignment is not the obvious one: holding is cyan
            // (nominal), selling is red (the alarm), and buying the dip is
            // amber — the boldest move, not the safest. None of them wears a
            // "recommended" treatment.
            _row(DecisionAction.hold, 'DO NOTHING', AppColors.accent, compact),
            SizedBox(height: gap),
            _row(DecisionAction.sell, 'EXIT TO CASH', AppColors.down, compact),
            SizedBox(height: gap),
            _row(
              DecisionAction.buyDip,
              'DEPLOY CASH',
              AppColors.caution,
              compact,
            ),

            SizedBox(height: compact ? AppSpacing.sm + 4 : AppSpacing.md),
            Text(
              'NO TIMER. THE TAPE WAITS FOR YOU.',
              textAlign: TextAlign.center,
              style: AppText.label(size: 10.5, color: AppColors.textFaint),
            ),
          ],
        ),
      ),
    );
  }

  /// Subtitles describe the *mechanic* rather than the sentiment — "EXIT TO
  /// CASH", not "get out while you can". The panel must not editorialise.
  Widget _row(
    DecisionAction action,
    String subtitle,
    Color color,
    bool compact,
  ) {
    return HudButton(
      label: action.label.toUpperCase(),
      subtitle: subtitle,
      color: color,
      height: compact ? 52 : 60,
      fontSize: compact ? 21 : 24,
      letterSpacingEm: 0.22,
      onPressed: () => onDecision(action),
    );
  }
}
