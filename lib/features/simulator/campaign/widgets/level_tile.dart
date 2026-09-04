import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../app/widgets/pressable.dart';
import '../../../../core/services/progress_service.dart';
import '../level_repository.dart';

/// One square on the campaign map.
///
/// Blind mode starts here, not on the level screen: an uncleared tile shows
/// only its number, difficulty and asset class. The real event name appears
/// after the level has been played, which also makes clearing one feel like
/// it revealed something (ENGINE.md §3).
///
/// Designed to look deliberate while empty. A tile whose only content is
/// "Level 4 / DATA PENDING" must not read as a broken card, so the index
/// numeral itself carries the tile as a large ghosted watermark and the status
/// sits on a single baseline.
class LevelTile extends StatelessWidget {
  const LevelTile({
    required this.entry,
    required this.progress,
    required this.onTap,
    super.key,
  });

  final LevelManifestEntry entry;
  final LevelProgress? progress;

  /// Null when the tile is not playable — the tile stays visible and says why
  /// rather than disappearing (DESIGN.md's rule for inert features).
  final VoidCallback? onTap;

  bool get _isCleared => progress?.isCleared ?? false;

  Color get _statusColor => switch (entry.dataStatus) {
        LevelDataStatus.sourced => AppColors.accent,
        LevelDataStatus.pendingSource => AppColors.textFaint,
        LevelDataStatus.needsDecision => AppColors.simulatedBadge,
      };

  String get _statusLabel => switch (entry.dataStatus) {
        LevelDataStatus.sourced => entry.difficulty.label.toUpperCase(),
        LevelDataStatus.pendingSource => 'PENDING',
        LevelDataStatus.needsDecision => 'DECIDE',
      };

  @override
  Widget build(BuildContext context) {
    final bool playable = onTap != null;
    final Color edge = _isCleared
        ? AppColors.up.withValues(alpha: 0.55)
        : playable
            ? AppColors.accent.withValues(alpha: 0.45)
            : AppColors.border;

    return Pressable(
      onTap: onTap ?? () => _explain(context),
      minTarget: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: playable || _isCleared
                ? <Color>[AppColors.surfaceRaised, AppColors.surface]
                : <Color>[AppColors.surface, AppColors.background],
          ),
          border: Border.all(color: edge),
          borderRadius: AppRadius.card,
        ),
        child: Stack(
          children: <Widget>[
            // The index as a watermark. Fills the tile so an unsourced level
            // still has a subject instead of a hole.
            Positioned(
              right: -6,
              bottom: -14,
              child: Text(
                // Market-scoped, matching the masked title above it — the
                // global order would put "11" behind a tile reading IND 01.
                entry.indexInMarket.toString().padLeft(2, '0'),
                style: AppText.mono(
                  size: 60,
                  weight: FontWeight.w700,
                  color: (_isCleared ? AppColors.up : AppColors.textPrimary)
                      .withValues(alpha: playable || _isCleared ? 0.10 : 0.05),
                  letterSpacing: -3,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm + 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      _StatusDot(color: _statusColor, filled: playable),
                      if (playable && !entry.licence.isCleared) ...<Widget>[
                        const SizedBox(width: 4),
                        // Built but not clear to ship. Visible so an
                        // unshippable level never looks finished.
                        Icon(
                          Icons.gavel,
                          size: 9,
                          color: AppColors.simulatedBadge
                              .withValues(alpha: 0.75),
                        ),
                      ],
                      const Spacer(),
                      if (_isCleared && progress?.bestScore != null)
                        Text(
                          progress!.bestScore.toString(),
                          style: AppText.mono(
                            size: 13,
                            weight: FontWeight.w700,
                            color: AppColors.up,
                          ),
                        )
                      else if (entry.isFree)
                        Text(
                          'FREE',
                          style: AppText.label(
                            color: AppColors.accent,
                            size: 9,
                          ),
                        )
                      else
                        const Icon(
                          Icons.lock_outline,
                          size: 12,
                          color: AppColors.textFaint,
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    // The reveal is the reward for clearing it.
                    _isCleared ? entry.revealTitle : entry.maskedTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(
                      size: 12.5,
                      height: 1.25,
                      weight: _isCleared ? FontWeight.w600 : FontWeight.w500,
                      color: _isCleared
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _statusLabel,
                    style: AppText.label(color: _statusColor, size: 8.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const String _paragraphBreak = '\n\n';

  /// A tapped-but-unplayable tile must explain itself, never no-op silently.
  void _explain(BuildContext context) {
    const String licenceNote =
        'Licensing is cleared per market, so this level does not inherit '
        'clearance from the others. It ships with real prices or it does '
        'not ship.';

    final String message = switch (entry.dataStatus) {
      LevelDataStatus.needsDecision => entry.openQuestion ??
          'This level needs a product decision before it can be built.',
      LevelDataStatus.pendingSource => <String>[
          'Waiting on ${entry.assetClass.label} market data that can be '
              'legally bundled with the app.',
          licenceNote,
          if (entry.openQuestion != null) entry.openQuestion!,
        ].join(_paragraphBreak),
      LevelDataStatus.sourced when _isCleared => entry.description,
      LevelDataStatus.sourced => entry.licence.isCleared
          ? 'This level is not unlocked yet.'
          : 'This level is built and playable, but its data source is not '
              'cleared for release. It runs in development and demo builds; '
              'publishing it needs a licensed source first.',
    };

    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: Text(
          // Cleared levels have earned their name; the rest stay masked.
          _isCleared ? entry.revealTitle : entry.maskedTitle,
          style: AppText.title(size: 17),
        ),
        content: Text(
          message,
          style: AppText.body(size: 13, color: AppColors.textSecondary),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Got it',
              style: AppText.body(
                size: 14,
                weight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : Colors.transparent,
        border: Border.all(color: color, width: 1.2),
        boxShadow: filled
            ? <BoxShadow>[
                BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6),
              ]
            : null,
      ),
    );
  }
}
