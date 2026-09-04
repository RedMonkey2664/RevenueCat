import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../app/widgets/discipline_badge.dart';
import '../../../app/widgets/pressable.dart';
import '../../../core/services/progress_service.dart';
import '../../../data/sample/dev_sample_level.dart';
import '../../profile/profile_screen.dart';
import '../engine/level_model.dart';
import '../endless/endless_home.dart';
import '../engine/simulation_mode.dart';
import '../level/level_screen.dart';
import 'level_repository.dart';
import 'widgets/level_tile.dart';

/// Simulator tab: mode choice, the campaign map, and the dev sample run.
///
/// The map is driven entirely by `level_manifest.json` — adding or reordering
/// a level is a data change, never a code change (CLAUDE.md).
class CampaignHome extends ConsumerStatefulWidget {
  const CampaignHome({super.key});

  @override
  ConsumerState<CampaignHome> createState() => _CampaignHomeState();
}

class _CampaignHomeState extends ConsumerState<CampaignHome> {
  // TODO(persistence): worth remembering in progress_service once there is a
  // real level to return to.
  SimulationMode _mode = SimulationMode.beginner;

  /// Null shows every market. LEVELS.md wants "which market am I in" obvious
  /// at a glance, since the three-market framing is part of the pitch.
  AssetClass? _market;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<LevelManifestEntry>> manifest =
        ref.watch(levelManifestProvider);
    final ProgressState progress = ref.watch(progressProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            titleSpacing: AppSpacing.md,
            title: const _Wordmark(),
            // In `actions`, not stuffed into `title` — the title slot has no
            // slack for a 44pt tap target and the row overflowed by 14pt.
            actions: <Widget>[
              if (progress.totalDisciplinePoints > 0)
                Center(
                  child: DisciplinePointsChip(
                    points: progress.totalDisciplinePoints,
                  ),
                ),
              IconButton(
                tooltip: 'Profile',
                icon: const Icon(Icons.person_outline),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ProfileScreen(),
                  ),
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            sliver: SliverList.list(
              children: <Widget>[
                Text('Survive the crash.', style: AppText.title(size: 30)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'A real drawdown, with the asset and the dates hidden. '
                  'One question: what do you do now?',
                  style: AppText.body(
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _ModeSelector(
                  selected: _mode,
                  onChanged: (SimulationMode m) => setState(() => _mode = m),
                ),
                const SizedBox(height: AppSpacing.lg),
                _DevRunCard(
                  // rootNavigator: a run is a full-screen mode, not a page
                  // inside the Simulator tab — the bottom nav both distracts
                  // and steals ~58pt from the chart.
                  onTap: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LevelScreen(
                        level: DevSampleLevel.build(),
                        mode: _mode,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _EndlessCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EndlessHome(mode: _mode),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _SectionHeader(
                  label: 'CAMPAIGN',
                  trailing: manifest.maybeWhen(
                    data: (List<LevelManifestEntry> all) =>
                        '${progress.clearedCount}/${all.length} CLEARED',
                    orElse: () => null,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _MarketFilter(
                  selected: _market,
                  counts: manifest.maybeWhen(
                    data: _countByMarket,
                    orElse: () => const <AssetClass, int>{},
                  ),
                  onChanged: (AssetClass? m) => setState(() => _market = m),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
          manifest.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (Object e, StackTrace s) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                child: _Notice(
                  title: 'THE LEVEL MANIFEST COULD NOT BE READ',
                  body: '$e',
                  color: AppColors.down,
                ),
              ),
            ),
            data: (List<LevelManifestEntry> all) {
              final List<LevelManifestEntry> entries = _market == null
                  ? all
                  : all
                      .where((LevelManifestEntry e) => e.assetClass == _market)
                      .toList();
              return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverGrid.builder(
                itemCount: entries.length,
                // Max-extent rather than a fixed column count: a fixed 3
                // columns turns into 630pt tiles on a wide window. This caps
                // tile size and adds columns instead.
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 132,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                  // Near-square. Taller tiles left a dead void in the middle
                  // of every unsourced level.
                  childAspectRatio: 0.94,
                ),
                itemBuilder: (BuildContext context, int i) {
                  final LevelManifestEntry entry = entries[i];
                  return LevelTile(
                    entry: entry,
                    progress: progress.forLevel(entry.id),
                    // Only a level with real, sourced data is launchable.
                    // Everything else stays visible and explains itself.
                    onTap: entry.dataStatus.isPlayable
                        ? () => _launch(context, entry)
                        : null,
                  );
                },
              ),
              );
            },
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.md),
            sliver: SliverList.list(
              children: const <Widget>[
                SizedBox(height: AppSpacing.sm),
                _Notice(
                  title: 'WHY NOTHING IS PLAYABLE YET',
                  body: 'No campaign level has a historical data source that '
                      'can be legally bundled with the app yet. Every price, '
                      'date and "optimal move" has to trace to a real, sourced '
                      'value — so these tiles stay empty rather than shipping '
                      'invented numbers. Tap any tile to see what it is '
                      'waiting on.',
                  color: AppColors.border,
                ),
                SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Map<AssetClass, int> _countByMarket(List<LevelManifestEntry> all) {
    final Map<AssetClass, int> counts = <AssetClass, int>{};
    for (final LevelManifestEntry e in all) {
      counts[e.assetClass] = (counts[e.assetClass] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _launch(BuildContext context, LevelManifestEntry entry) async {
    // TODO(phase8): MONETIZATION.md puts the `pro` entitlement check here and
    // at the Endless entry point — the only two places it belongs.
    final NavigatorState navigator =
        Navigator.of(context, rootNavigator: true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    try {
      final SimulationLevel level =
          await ref.read(levelRepositoryProvider).loadLevel(entry);
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => LevelScreen(level: level, mode: _mode),
        ),
      );
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not load that level: $error')),
      );
    }
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 3,
          height: 16,
          decoration: const BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'Market Nerve',
          style: AppText.body(size: 15, weight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// A small mono label with a hairline running to the trailing text. Gives the
/// page structure without spending a heading's worth of vertical space.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.trailing});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(label, style: AppText.label(size: 10)),
        const SizedBox(width: AppSpacing.sm),
        const Expanded(child: Divider(height: 1, color: AppColors.border)),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          Text(trailing!, style: AppText.label(size: 10)),
        ],
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.title,
    required this.body,
    required this.color,
  });

  final String title;
  final String body;
  final Color color;

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

/// The dev-only synthetic run. Styled as a distinct utility strip rather than
/// a hero card so it never reads as the product's main entry point.
class _DevRunCard extends StatelessWidget {
  const _DevRunCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      minTarget: 0,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              AppColors.down.withValues(alpha: 0.10),
              AppColors.surface,
            ],
          ),
          border: Border.all(color: AppColors.down.withValues(alpha: 0.35)),
          borderRadius: AppRadius.card,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.down.withValues(alpha: 0.14),
                borderRadius: AppRadius.chip,
              ),
              child: const Icon(
                Icons.science_outlined,
                size: 18,
                color: AppColors.down,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        'Engine test run',
                        style: AppText.body(
                          size: 15,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.down.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          'DEV',
                          style: AppText.label(
                            color: AppColors.down,
                            size: 8.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Synthetic data. Proves the engine, teaches nothing.',
                    style: AppText.body(
                      size: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward,
              size: 16,
              color: AppColors.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}

/// Beginner vs Advanced, as a segmented control with a sliding indicator.
class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.selected, required this.onChanged});

  final SimulationMode selected;
  final ValueChanged<SimulationMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final int index = SimulationMode.values.indexOf(selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: AppRadius.chip,
          ),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final double w = c.maxWidth / SimulationMode.values.length;
              return SizedBox(
                height: 38,
                child: Stack(
                  children: <Widget>[
                    AnimatedPositioned(
                      duration: AppMotion.normal,
                      curve: AppMotion.curve,
                      left: index * w,
                      width: w,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.16),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.7),
                          ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    Row(
                      children: <Widget>[
                        for (final SimulationMode m in SimulationMode.values)
                          Expanded(
                            child: Pressable(
                              onTap: () => onChanged(m),
                              minTarget: 0,
                              scale: 1,
                              child: Center(
                                child: AnimatedDefaultTextStyle(
                                  duration: AppMotion.normal,
                                  style: AppText.body(
                                    size: 13,
                                    weight: FontWeight.w600,
                                    color: m == selected
                                        ? AppColors.accent
                                        : AppColors.textSecondary,
                                  ),
                                  child: Text(m.label),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AnimatedSwitcher(
          duration: AppMotion.normal,
          child: Text(
            selected.blurb,
            key: ValueKey<SimulationMode>(selected),
            style: AppText.body(size: 12.5, color: AppColors.textFaint),
          ),
        ),
      ],
    );
  }
}

/// The three-way market filter LEVELS.md asks for on the campaign home:
/// International / Indian / Bitcoin, plus an "All" default.
///
/// The engine is indifferent to market (ENGINE.md, one engine regardless of
/// asset_class) — this is purely player-facing framing, and it is also where
/// the per-market licensing story becomes visible.
class _MarketFilter extends StatelessWidget {
  const _MarketFilter({
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  final AssetClass? selected;
  final Map<AssetClass, int> counts;
  final ValueChanged<AssetClass?> onChanged;

  @override
  Widget build(BuildContext context) {
    final int total = counts.values.fold(0, (int a, int b) => a + b);

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          _MarketChip(
            label: 'All',
            count: total,
            selected: selected == null,
            onTap: () => onChanged(null),
          ),
          for (final AssetClass m in AssetClass.values)
            _MarketChip(
              label: m.label,
              count: counts[m] ?? 0,
              selected: selected == m,
              onTap: () => onChanged(m),
            ),
        ],
      ),
    );
  }
}

class _MarketChip extends StatelessWidget {
  const _MarketChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Pressable(
        onTap: onTap,
        minTarget: 0,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md - 2,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.14)
                : AppColors.surface,
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
            ),
            borderRadius: AppRadius.chip,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: AppText.body(
                  size: 12.5,
                  weight: FontWeight.w600,
                  color:
                      selected ? AppColors.accent : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                count.toString(),
                style: AppText.mono(
                  size: 10.5,
                  weight: FontWeight.w700,
                  color: selected
                      ? AppColors.accent.withValues(alpha: 0.8)
                      : AppColors.textFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Entry to Endless mode. Sits under the dev run and above the campaign map,
/// because it is a different *kind* of thing from a numbered level.
class _EndlessCard extends StatelessWidget {
  const _EndlessCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      minTarget: 0,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              AppColors.accent.withValues(alpha: 0.09),
              AppColors.surface,
            ],
          ),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
          borderRadius: AppRadius.card,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.14),
                borderRadius: AppRadius.chip,
              ),
              child: const Icon(
                Icons.shuffle,
                size: 17,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Endless',
                    style: AppText.body(size: 15, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'A random six-month window you have never seen.',
                    style: AppText.body(
                      size: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward,
              size: 16,
              color: AppColors.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}
