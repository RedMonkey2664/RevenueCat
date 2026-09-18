import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../app/widgets/mascot.dart';
import '../../../app/widgets/feed_state.dart';
import '../../../app/widgets/hud.dart';
import '../../../app/widgets/pressable.dart';
import '../../../core/services/progress_service.dart';
import '../../../core/services/purchases_service.dart';
import '../../../data/sample/dev_sample_level.dart';
import '../../daily_pivot/services/pivot_controller.dart'
    show pivotStreakProvider;
import '../../paywall/paywall_screen.dart';
import '../../profile/nerve_profile_screen.dart';
import '../custom/custom_sim_setup_screen.dart';
import '../endless/endless_home.dart';
import '../engine/level_model.dart';
import '../engine/simulation_mode.dart';
import '../level/level_screen.dart';
import 'level_repository.dart';
import 'widgets/campaign_path.dart';

/// Simulator tab: the campaign as an S-curve path (artboard 1f), with the
/// Custom Simulation above it.
///
/// The reference screen puts exactly one card between the stats strip and
/// SELECT MISSION, so Endless — a way of playing rather than a mission —
/// moved into the settings sheet. Every gap here is measured from that
/// screen, which is why they are tighter than the app's usual rhythm.
///
/// The map is driven entirely by `level_manifest.json` — adding or reordering
/// a level is a data change, never a code change (CLAUDE.md).
class CampaignHome extends ConsumerStatefulWidget {
  const CampaignHome({super.key});

  @override
  ConsumerState<CampaignHome> createState() => _CampaignHomeState();
}

class _CampaignHomeState extends ConsumerState<CampaignHome> {
  SimulationMode _mode = SimulationMode.beginner;

  /// Null shows every market. LEVELS.md wants "which market am I in" obvious
  /// at a glance, since the three-market framing is part of the pitch.
  AssetClass? _market;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<LevelManifestEntry>> manifest = ref.watch(
      levelManifestProvider,
    );
    final ProgressState progress = ref.watch(progressProvider);
    final int streak = ref.watch(pivotStreakProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md + 4,
                AppSpacing.md,
                AppSpacing.md + 4,
                0,
              ),
              sliver: SliverList.list(
                children: <Widget>[
                  _Header(
                    mode: _mode,
                    onSettings: _openSettings,
                    onProfile: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const NerveProfileScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _StatsStrip(
                    progress: progress,
                    streak: streak,
                    totalLevels: manifest.maybeWhen(
                      data: (List<LevelManifestEntry> all) => all.length,
                      orElse: () => 0,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _EntryCard(
                    emphasis: true,
                    icon: Icons.gps_not_fixed,
                    title: 'CUSTOM SIMULATION',
                    body:
                        'Any instrument, any dates.\nBuild your own scenario.',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CustomSimSetupScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(height: 1, color: AppColors.border),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'SELECT MISSION',
                    style: AppText.railLabel(
                      size: 16,
                      weight: FontWeight.w800,
                      color: AppColors.textSecondary,
                      letterSpacing: 16 * 0.3,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm + 4),
                  _MarketFilter(
                    selected: _market,
                    onChanged: (AssetClass? m) => setState(() => _market = m),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
            manifest.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(
                    child: MascotLoader(caption: 'LOADING MISSIONS'),
                  ),
                ),
              ),
              error: (Object e, StackTrace s) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md + 4,
                  ),
                  child: SizedBox(
                    height: 200,
                    child: FeedFailurePane(
                      title: 'THE LEVEL MANIFEST COULD NOT BE READ',
                      message: '$e',
                    ),
                  ),
                ),
              ),
              data: (List<LevelManifestEntry> all) {
                final List<LevelManifestEntry> entries = _market == null
                    ? all
                    : all
                          .where(
                            (LevelManifestEntry e) => e.assetClass == _market,
                          )
                          .toList();
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: CampaignPath(
                      entries: entries,
                      progress: progress,
                      onTap: _onNode,
                    ),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
          ],
        ),
      ),
    );
  }

  Future<void> _onNode(LevelManifestEntry entry) async {
    // Only a level with real, sourced data is launchable. Everything else
    // still responds and explains itself.
    if (!entry.dataStatus.isPlayable) {
      _explainUnsourced(context, entry);
      return;
    }
    // MONETIZATION.md: the campaign level loader is one of exactly two places
    // the `pro` check belongs.
    if (!entry.isFree && !ref.read(proAccessProvider).hasPro) {
      final bool unlocked = await PaywallScreen.show(context);
      if (!unlocked || !mounted) return;
    }
    await _launch(entry);
  }

  Future<void> _launch(LevelManifestEntry entry) async {
    // rootNavigator: a run is a full-screen mode, not a page inside the
    // Simulator tab — the bottom nav both distracts and steals the chart's
    // height.
    final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    try {
      final SimulationLevel level = await runWithMascot(
        context,
        () => ref.read(levelRepositoryProvider).loadLevel(entry),
        caption: 'ARMING THE RUN',
      );
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

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => _RunSettingsSheet(
        mode: _mode,
        onMode: (SimulationMode m) => setState(() => _mode = m),
        onEndless: () {
          Navigator.of(sheetContext).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => EndlessHome(mode: _mode)),
          );
        },
        onDevRun: () {
          Navigator.of(sheetContext).pop();
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  LevelScreen(level: DevSampleLevel.build(), mode: _mode),
            ),
          );
        },
      ),
    );
  }
}

/// "HistoX / CAMPAIGN" and the two round buttons.
class _Header extends StatelessWidget {
  const _Header({
    required this.mode,
    required this.onSettings,
    required this.onProfile,
  });

  final SimulationMode mode;
  final VoidCallback onSettings;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'HistoX',
                  style: AppText.railLabel(
                    size: 30,
                    weight: FontWeight.w800,
                    letterSpacing: 30 * 0.005,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              // The run mode is a choice that changes how every level plays,
              // so it is named where the player always looks.
              Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: 'CAMPAIGN',
                      style: AppText.label(size: 13, letterSpacing: 13 * 0.3),
                    ),
                    if (mode.isAdvanced)
                      TextSpan(
                        text: ' · ADVANCED',
                        style: AppText.label(
                          size: 13,
                          color: AppColors.caution,
                          letterSpacing: 13 * 0.3,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _RoundButton(
          icon: Icons.settings_outlined,
          tooltip: 'Run settings',
          onTap: onSettings,
        ),
        const SizedBox(width: AppSpacing.sm + 2),
        _RoundButton(
          icon: Icons.radio_button_checked,
          tooltip: 'Nerve Profile',
          onTap: onProfile,
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Pressable(
          onTap: onTap,
          minTarget: kMinTouchTarget,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderStrong),
            ),
            child: Icon(icon, size: 16, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

/// The four-cell stats strip under the wordmark.
///
/// Glyphs are drawn, not typed: ⚡ is an emoji-presentation character and
/// renders as a yellow cartoon bolt on both phone platforms, which is not
/// the line glyph the wireframe draws.
class _StatsStrip extends StatelessWidget {
  const _StatsStrip({
    required this.progress,
    required this.streak,
    required this.totalLevels,
  });

  final ProgressState progress;

  /// The Daily Pivot streak — consecutive resolved days taken part in.
  final int streak;
  final int totalLevels;

  /// Mean best score across levels that have actually been graded.
  String get _avgScore {
    final Iterable<int> scores = progress.levels.values
        .map((LevelProgress p) => p.bestScore)
        .whereType<int>();
    if (scores.isEmpty) return '—';
    return (scores.reduce((int a, int b) => a + b) / scores.length)
        .round()
        .toString();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _StatCell(
              glyph: const _Diamond(),
              value: '$streak',
              label: 'STREAK',
              // A live streak is underlined, the way the wireframe marks it.
              underline: streak > 0,
              first: true,
            ),
            _StatCell(
              glyph: const Icon(
                Icons.star_border,
                size: 19,
                color: AppColors.textPrimary,
              ),
              value: _avgScore,
              label: 'AVG SCORE',
            ),
            _StatCell(
              glyph: const Icon(
                Icons.check,
                size: 19,
                color: AppColors.textPrimary,
              ),
              value: '${progress.clearedCount}/$totalLevels',
              label: 'CLEARED',
            ),
            _StatCell(
              glyph: const Icon(Icons.bolt, size: 20, color: AppColors.accent),
              value: '${progress.pivotBonusPoints}',
              valueColor: AppColors.accent,
              label: 'PIVOT DP',
            ),
          ],
        ),
      ),
    );
  }
}

/// The streak's green diamond.
class _Diamond extends StatelessWidget {
  const _Diamond();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.785398,
      child: Container(width: 11, height: 11, color: AppColors.positive),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.glyph,
    required this.value,
    required this.label,
    this.valueColor = AppColors.textPrimary,
    this.underline = false,
    this.first = false,
  });

  final Widget glyph;
  final String value;
  final String label;
  final Color valueColor;
  final bool underline;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: first
                ? BorderSide.none
                : const BorderSide(color: AppColors.border),
          ),
        ),
        child: Stack(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                4,
                AppSpacing.sm + 4,
                4,
                AppSpacing.sm + 2,
              ),
              child: Column(
                children: <Widget>[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      children: <Widget>[
                        glyph,
                        const SizedBox(width: 8),
                        Text(
                          value,
                          style: AppText.display(
                            size: 23,
                            color: valueColor,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm + 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: AppText.label(size: 10, letterSpacing: 10 * 0.2),
                    ),
                  ),
                ],
              ),
            ),
            if (underline)
              const Positioned(
                left: 0,
                bottom: 0,
                width: 70,
                height: 3,
                child: ColoredBox(color: AppColors.accent),
              ),
          ],
        ),
      ),
    );
  }
}

/// Entry to a run that is not a numbered campaign level. Endless and the
/// Custom Simulation are different *kinds* of thing from a level, so they sit
/// above the map rather than in it, and share one card so they never drift.
class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.emphasis = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  /// The lead card carries a warm wash and an accent rail, so the eye lands
  /// on one of the two entries rather than weighing them up.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      minTarget: 0,
      scale: 0.985,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm + 4,
          AppSpacing.md + 2,
          AppSpacing.sm + 4,
        ),
        decoration: BoxDecoration(
          color: emphasis ? null : AppColors.surface.withValues(alpha: 0.5),
          gradient: emphasis
              ? LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[
                    AppColors.accent.withValues(alpha: 0.16),
                    AppColors.accent.withValues(alpha: 0.03),
                  ],
                )
              : null,
          border: Border.all(
            color: emphasis
                ? AppColors.accent.withValues(alpha: 0.55)
                : AppColors.borderStrong,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 22, color: AppColors.accent),
            const SizedBox(width: AppSpacing.md + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.railLabel(
                      size: 15.5,
                      weight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: 15.5 * 0.16,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    body,
                    style: AppText.body(
                      size: 13,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}

/// All / International / Indian / Crypto.
///
/// The engine is indifferent to market (ENGINE.md) — this is purely
/// player-facing framing, which LEVELS.md asks to be obvious at a glance.
class _MarketFilter extends StatelessWidget {
  const _MarketFilter({required this.selected, required this.onChanged});

  final AssetClass? selected;
  final ValueChanged<AssetClass?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          _MarketChip(
            label: 'All',
            selected: selected == null,
            onTap: () => onChanged(null),
          ),
          for (final AssetClass m in AssetClass.values)
            _MarketChip(
              label: m.label,
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
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      child: Semantics(
        button: true,
        selected: selected,
        label: '$label levels',
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.curve,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md + 4),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.accent.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: const BorderRadius.all(Radius.circular(999)),
              border: Border.all(
                color: selected ? AppColors.accent : AppColors.borderStrong,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Text(
              label,
              style: AppText.body(
                size: 14.5,
                weight: FontWeight.w500,
                color: selected ? AppColors.accent : AppColors.textSecondary,
                letterSpacing: 14.5 * 0.1,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ⚙ — how the next run plays, and the development sample.
class _RunSettingsSheet extends StatefulWidget {
  const _RunSettingsSheet({
    required this.mode,
    required this.onMode,
    required this.onEndless,
    required this.onDevRun,
  });

  final SimulationMode mode;
  final ValueChanged<SimulationMode> onMode;

  /// Endless is a way of playing rather than a mission, so it sits with the
  /// mode switch instead of on the map (see [CampaignHome]).
  final VoidCallback onEndless;
  final VoidCallback onDevRun;

  @override
  State<_RunSettingsSheet> createState() => _RunSettingsSheetState();
}

class _RunSettingsSheetState extends State<_RunSettingsSheet> {
  late SimulationMode _mode = widget.mode;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md + 4,
          AppSpacing.lg,
          AppSpacing.md + 4,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('RUN SETTINGS', style: AppText.railLabel(size: 16)),
            const SizedBox(height: AppSpacing.lg),
            Text('MODE', style: AppText.label(size: 11)),
            const SizedBox(height: AppSpacing.sm + 2),
            for (final SimulationMode m in SimulationMode.values) ...<Widget>[
              _ModeOption(
                mode: m,
                selected: m == _mode,
                onTap: () {
                  setState(() => _mode = m);
                  widget.onMode(m);
                },
              ),
              const SizedBox(height: AppSpacing.sm + 2),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text('OTHER RUNS', style: AppText.label(size: 11)),
            const SizedBox(height: AppSpacing.sm + 2),
            HudButton(
              label: 'ENDLESS',
              subtitle: 'A WINDOW YOU HAVE NEVER SEEN',
              height: 52,
              fontSize: 14,
              letterSpacingEm: 0.18,
              onPressed: widget.onEndless,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('DEVELOPMENT', style: AppText.label(size: 11)),
            const SizedBox(height: AppSpacing.sm + 2),
            HudButton(
              label: 'ENGINE TEST RUN',
              subtitle: 'SYNTHETIC DATA',
              color: AppColors.down,
              height: 52,
              fontSize: 14,
              letterSpacingEm: 0.18,
              onPressed: widget.onDevRun,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Proves the engine, teaches nothing. Its prices are generated, '
              'and it never counts towards your progress.',
              style: AppText.body(size: 12.5, color: AppColors.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final SimulationMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color c = mode.isAdvanced ? AppColors.caution : AppColors.accent;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? c.withValues(alpha: 0.08) : Colors.transparent,
            border: Border.all(
              color: selected ? c : AppColors.border,
              width: selected ? 1.3 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${mode.label.toUpperCase()} RUN',
                style: AppText.railLabel(
                  size: 15,
                  color: selected ? c : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs + 2),
              Text(
                mode.blurb,
                style: AppText.body(size: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Explains why a node cannot be played.
///
/// A level that cannot ship says so plainly rather than being quietly absent,
/// and it never blames the player.
void _explainUnsourced(BuildContext context, LevelManifestEntry entry) {
  const String paragraphBreak = '\n\n';
  const String licenceNote =
      'Licensing is cleared per market, so this level does not inherit '
      'clearance from the others. It ships with real prices or it does '
      'not ship.';

  final String message = switch (entry.dataStatus) {
    LevelDataStatus.needsDecision =>
      entry.openQuestion ??
          'This level needs a product decision before it can be built.',
    LevelDataStatus.pendingSource => <String>[
      'Waiting on ${entry.assetClass.label} market data that can be '
          'legally bundled with the app.',
      licenceNote,
      if (entry.openQuestion != null) entry.openQuestion!,
    ].join(paragraphBreak),
    LevelDataStatus.sourced =>
      entry.licence.isCleared
          ? 'This level is not unlocked yet.'
          : 'This level is built and playable, but its data source is not '
                'cleared for release. It runs in development and demo builds; '
                'publishing it needs a licensed source first.',
  };

  showDialog<void>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(
        entry.maskedTitle,
        style: AppText.railLabel(size: 17, color: AppColors.textPrimary),
      ),
      content: Text(
        message,
        style: AppText.body(size: 13.5, color: AppColors.textSecondary),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CLOSE'),
        ),
      ],
    ),
  );
}
