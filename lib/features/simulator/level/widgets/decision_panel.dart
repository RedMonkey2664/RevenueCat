import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../engine/script_event_model.dart';

/// The three calls, and only these three (ENGINE.md §2).
///
/// Restructured to artboard 1c of `Market Nerve HUD.dc.html`. Its note is the
/// reason this is a panel and not an overlay: *"the panel pushes the chart up
/// rather than overlaying it, so the low stays visible"* — the player has to
/// be able to see the drawdown they are being asked to react to.
///
/// No countdown timer. ENGINE.md makes that an explicit post-Phase-3 maybe, and
/// the canvas commits to it in copy: "NO TIMER. THE TAPE WAITS FOR YOU."
///
/// This panel never says what the optimal move was — that is the Debrief's job,
/// and saying it here would break blind mode.
class DecisionPanel extends StatelessWidget {
  const DecisionPanel({
    required this.portfolioValue,
    required this.pnlPercent,
    required this.onDecision,
    super.key,
  });

  final double portfolioValue;
  final double pnlPercent;
  final ValueChanged<DecisionAction> onDecision;

  /// Halted is red, full stop.
  ///
  /// This panel used to colour itself from the pause point's `flashTreatment`,
  /// which put an amber panel under a red "HALTED" app bar and a red progress
  /// rail — two state colours on the one screen that is supposed to be
  /// unambiguous. The canvas is explicit that "the alarm treatment exists on
  /// exactly one screen", and that screen is entirely red. The soft/hard
  /// distinction still exists, but it drives the momentary [PauseFlashOverlay]
  /// rather than the standing chrome.
  static const Color _urgencyColor = AppColors.down;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md + 2,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        // The canvas layers a dark warm gradient under this panel rather than
        // a flat fill — it reads as the alarm light spilling upward.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            _urgencyColor.withValues(alpha: 0.12),
            AppColors.alarmBackground,
          ],
        ),
        border: Border(top: BorderSide(color: _urgencyColor.withValues(alpha: 0.45))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // The question, ruled off on both sides. Barlow at 0.3em is the
            // widest tracking anywhere in the app, and it is here because this
            // is the one line the whole product is built around.
            Row(
              children: <Widget>[
                Expanded(child: _Rule(color: _urgencyColor)),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm + 2,
                  ),
                  child: Text(
                    'WHAT DO YOU DO?',
                    style: AppText.railLabel(
                      size: 16,
                      weight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: 16 * 0.3,
                    ),
                  ),
                ),
                Expanded(child: _Rule(color: _urgencyColor)),
              ],
            ),
            const SizedBox(height: AppSpacing.md - 2),

            // Colour assignment is the canvas's, and it is not the obvious
            // one: holding is mint (nominal), selling is red (the alarm), and
            // buying the dip is amber (caution — it is the boldest move, not
            // the safest). Previously buy-the-dip wore the accent, which read
            // as "the recommended answer".
            _DecisionRow(
              action: DecisionAction.hold,
              subtitle: 'DO NOTHING',
              color: AppColors.accent,
              onTap: onDecision,
            ),
            const SizedBox(height: AppSpacing.sm + 1),
            _DecisionRow(
              action: DecisionAction.sell,
              subtitle: 'EXIT TO CASH',
              color: AppColors.down,
              onTap: onDecision,
            ),
            const SizedBox(height: AppSpacing.sm + 1),
            _DecisionRow(
              action: DecisionAction.buyDip,
              subtitle: 'DEPLOY CASH',
              color: AppColors.caution,
              onTap: onDecision,
            ),

            const SizedBox(height: AppSpacing.sm + 2),
            SizedBox(
              width: double.infinity,
              child: Text(
                'NO TIMER. THE TAPE WAITS FOR YOU.',
                textAlign: TextAlign.center,
                style: AppText.label(size: 9, color: AppColors.textFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        color: color.withValues(alpha: 0.3),
      );
}

class _DecisionRow extends StatelessWidget {
  const _DecisionRow({
    required this.action,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final DecisionAction action;

  /// Uppercase, and describing the *mechanic* rather than the sentiment —
  /// "EXIT TO CASH", not "get out while you can". The panel must not editorialise.
  final String subtitle;

  final Color color;
  final ValueChanged<DecisionAction> onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.09),
      // Square. The HUD has no rounded panels.
      borderRadius: BorderRadius.zero,
      child: InkWell(
        onTap: () => onTap(action),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: kMinTouchTarget + 6),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md - 1,
            vertical: AppSpacing.sm + 3,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  action.label.toUpperCase(),
                  style: AppText.railLabel(
                    size: 19,
                    weight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                subtitle,
                style: AppText.label(
                  size: 9,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
