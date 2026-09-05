import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/daily_pivot/pivot_home.dart';
import '../features/live_market/live_market_home.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/simulator/campaign/campaign_home.dart';
import '../features/time_machine/calculator_screen.dart';
import 'theme.dart';

/// Shows onboarding once, then the tab shell.
///
/// Gating here rather than inside a tab guarantees the no-real-money framing
/// is seen before any pillar is reachable (DESIGN.md).
class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool seen = ref.watch(onboardingSeenProvider);
    return seen ? const AppShell() : const OnboardingScreen();
  }
}

/// The tab shell. Each tab keeps its own navigator so a Simulator run in
/// progress is not torn down by a trip to Time Machine.
///
/// ARCHITECTURE.md describes three tabs; Live Markets is a fourth, added with
/// the live-data features. Four fits a phone bottom bar comfortably; a fifth
/// would not, which is why the Custom Simulation is reached from inside the
/// Simulator and Live Markets rather than getting a tab of its own.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const List<_Tab> _tabs = <_Tab>[
    _Tab(
      label: 'Simulator',
      icon: Icons.candlestick_chart_outlined,
      activeIcon: Icons.candlestick_chart,
    ),
    _Tab(
      label: 'Markets',
      icon: Icons.show_chart_outlined,
      activeIcon: Icons.show_chart,
    ),
    _Tab(
      label: 'Daily Pivot',
      icon: Icons.swap_vert_circle_outlined,
      activeIcon: Icons.swap_vert_circle,
    ),
    _Tab(
      label: 'Time Machine',
      icon: Icons.history_toggle_off_outlined,
      activeIcon: Icons.history_toggle_off,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const <Widget>[
          _TabNavigator(child: CampaignHome()),
          _TabNavigator(child: LiveMarketHome()),
          _TabNavigator(child: PivotHome()),
          _TabNavigator(child: CalculatorScreen()),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        tabs: _tabs,
        index: _index,
        onSelect: (int i) => setState(() => _index = i),
      ),
    );
  }
}

/// Custom nav rather than [BottomNavigationBar].
///
/// The Material default centres a shifting icon+label pair and paints its own
/// surface, which fights the terminal aesthetic. This one keeps a fixed
/// layout, an accent rail on the active tab, and a full-height tap target.
class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.tabs,
    required this.index,
    required this.onSelect,
  });

  final List<_Tab> tabs;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: <Widget>[
              for (int i = 0; i < tabs.length; i++)
                Expanded(
                  child: _NavItem(
                    tab: tabs[i],
                    selected: i == index,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color =
        selected ? AppColors.accent : AppColors.textFaint;

    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Active rail. Cheaper and calmer than a moving pill, and it
            // survives the dark background better than a filled indicator.
            AnimatedContainer(
              duration: AppMotion.normal,
              curve: AppMotion.curve,
              height: 2,
              width: selected ? 26 : 0,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.all(Radius.circular(1)),
              ),
            ),
            const SizedBox(height: 8),
            Icon(selected ? tab.activeIcon : tab.icon, size: 21, color: color),
            const SizedBox(height: 3),
            Text(
              tab.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label(
                color: color,
                size: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab {
  const _Tab({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class _TabNavigator extends StatelessWidget {
  const _TabNavigator({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (RouteSettings settings) =>
          MaterialPageRoute<void>(builder: (_) => child, settings: settings),
    );
  }
}
