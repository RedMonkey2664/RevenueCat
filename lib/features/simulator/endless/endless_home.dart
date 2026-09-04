import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../app/widgets/pressable.dart';
import '../campaign/level_repository.dart' show AssetClass;
import '../engine/endless_generator.dart';
import '../engine/level_model.dart';
import '../engine/simulation_mode.dart';
import '../level/level_screen.dart';

/// Endless mode entry (DESIGN.md screen 3): "start a random run".
///
/// Deliberately simple. The campaign is where curated history and written
/// reveals live; Endless is an infinite supply of unseen windows, which is
/// exactly what makes blind mode worth having.
class EndlessHome extends ConsumerStatefulWidget {
  const EndlessHome({required this.mode, super.key});

  final SimulationMode mode;

  @override
  ConsumerState<EndlessHome> createState() => _EndlessHomeState();
}

class _EndlessHomeState extends ConsumerState<EndlessHome> {
  bool _busy = false;

  Future<void> _start(AssetClass market) async {
    setState(() => _busy = true);

    // TODO(phase8): MONETIZATION.md gates Endless behind the `pro`
    // entitlement. This is one of exactly two places that check belongs.
    final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    try {
      final HistoryPool pool =
          await ref.read(historyPoolRepositoryProvider).load(market);
      final SimulationLevel level =
          EndlessGenerator(pool: pool).generate();

      if (!mounted) return;
      setState(() => _busy = false);

      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => LevelScreen(level: level, mode: widget.mode),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not start a run: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<AssetClass>> markets =
        ref.watch(endlessMarketsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ENDLESS')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          Text('A window you have never seen.', style: AppText.title(size: 26)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Six months of real market history, picked at random and skipped '
            'unless something actually falls. No written reveal — just the '
            'asset, the dates, and what you did.',
            style: AppText.body(size: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          markets.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (Object e, StackTrace s) => _Panel(
              color: AppColors.down,
              title: 'COULD NOT READ THE HISTORY POOLS',
              body: '$e',
            ),
            data: (List<AssetClass> available) {
              if (available.isEmpty) {
                return const _Panel(
                  color: AppColors.simulatedBadge,
                  title: 'NO HISTORY POOL BUNDLED',
                  body: 'Endless needs a long-run price series per market, '
                      'and none is bundled yet.',
                );
              }
              return Column(
                children: <Widget>[
                  for (final AssetClass m in available)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _MarketCard(
                        market: m,
                        busy: _busy,
                        onTap: () => _start(m),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  _Panel(
                    color: AppColors.border,
                    title: 'ONLY ONE MARKET SO FAR',
                    body: 'International and Indian pools need the same '
                        'per-market data licence as the campaign levels. '
                        'Endless runs on whichever markets are cleared, so '
                        'they appear here as they land.',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MarketCard extends StatelessWidget {
  const _MarketCard({
    required this.market,
    required this.busy,
    required this.onTap,
  });

  final AssetClass market;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: busy ? null : onTap,
      minTarget: 0,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              AppColors.accent.withValues(alpha: 0.10),
              AppColors.surface,
            ],
          ),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.45)),
          borderRadius: AppRadius.card,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.14),
                borderRadius: AppRadius.chip,
              ),
              child: const Icon(
                Icons.shuffle,
                size: 18,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Random ${market.label} window',
                    style: AppText.body(size: 15, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '~6 months of real daily candles',
                    style: AppText.body(
                      size: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (busy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              )
            else
              const Icon(
                Icons.arrow_forward,
                size: 16,
                color: AppColors.accent,
              ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.color,
    required this.title,
    required this.body,
  });

  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        border: Border(left: BorderSide(color: color, width: 2)),
        borderRadius: const BorderRadius.horizontal(right: AppRadius.chipR),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: AppText.label(size: 9.5)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: AppText.body(
              size: 12.5,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
