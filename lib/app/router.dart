import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/daily_pivot/pivot_home.dart';
import '../features/daily_pivot/services/pivot_controller.dart';
import '../features/live_market/live_market_home.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/simulator/campaign/campaign_home.dart';
import '../features/time_machine/calculator_screen.dart';
import 'shell_state.dart';
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
/// Four tabs fit a phone bottom bar comfortably; a fifth would not, which is
/// why the Custom Simulation is reached from inside the Simulator rather than
/// getting a tab of its own.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const List<_Tab> _tabs = <_Tab>[
    _Tab(label: 'SIMULATOR', glyph: _Glyph.simulator),
    _Tab(label: 'MARKETS', glyph: _Glyph.markets),
    _Tab(label: 'PIVOT', glyph: _Glyph.pivot),
    // Abbreviated exactly as the wireframes do: four labels at this tracking
    // do not fit a 375pt bar with "TIME MACHINE" spelled out.
    _Tab(label: 'TIME M.', glyph: _Glyph.time, semantics: 'Time Machine'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTab tab = ref.watch(shellTabProvider);
    final bool pivotBadge = ref.watch(pivotNeedsAttentionProvider);

    return Scaffold(
      body: IndexedStack(
        index: tab.index,
        children: <Widget>[
          _TabNavigator(
            navigatorKey: simulatorNavigatorKey,
            child: const CampaignHome(),
          ),
          const _TabNavigator(child: LiveMarketHome()),
          const _TabNavigator(child: PivotHome()),
          const _TabNavigator(child: CalculatorScreen()),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        tabs: _tabs,
        index: tab.index,
        badges: <bool>[false, false, pivotBadge, false],
        onSelect: (int i) =>
            ref.read(shellTabProvider.notifier).select(AppTab.values[i]),
      ),
    );
  }
}

/// Custom nav rather than [BottomNavigationBar].
///
/// The Material default centres a shifting icon+label pair and paints its own
/// surface, which fights the HUD. This one keeps a fixed layout, square line
/// glyphs, and wide-tracked labels, as the wireframes draw it.
class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.tabs,
    required this.index,
    required this.badges,
    required this.onSelect,
  });

  final List<_Tab> tabs;
  final int index;
  final List<bool> badges;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: <Widget>[
              for (int i = 0; i < tabs.length; i++)
                Expanded(
                  child: _NavItem(
                    tab: tabs[i],
                    selected: i == index,
                    badge: badges[i],
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
    required this.badge,
    required this.onTap,
  });

  final _Tab tab;
  final bool selected;
  final bool badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? AppColors.accent : AppColors.textFaint;

    return Semantics(
      selected: selected,
      button: true,
      label: '${tab.semantics ?? tab.label}${badge ? ', needs attention' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 30,
              height: 22,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: <Widget>[
                  AnimatedSwitcher(
                    duration: AppMotion.fast,
                    child: CustomPaint(
                      key: ValueKey<bool>(selected),
                      size: const Size(18, 18),
                      painter: _GlyphPainter(
                        glyph: tab.glyph,
                        color: color,
                        active: selected,
                      ),
                    ),
                  ),
                  // Something is waiting on this tab — today's Pivot is open
                  // and unanswered, or its outcome is in and unseen.
                  if (badge)
                    Positioned(
                      right: -4,
                      top: -3,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.down,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tab.label,
                maxLines: 1,
                style: AppText.label(
                  size: 11,
                  weight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                  letterSpacing: 11 * 0.18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Glyph { simulator, markets, pivot, time }

/// The tab glyphs: square line drawings, to match the HUD rather than
/// Material's rounded icon set. ▣ ◫ ◈ ◷.
class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({
    required this.glyph,
    required this.color,
    required this.active,
  });

  final _Glyph glyph;
  final Color color;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final Paint fill = Paint()..color = color;
    final Rect r = (Offset.zero & size).deflate(1.5);
    final Offset c = r.center;

    switch (glyph) {
      case _Glyph.simulator:
        canvas.drawRect(r, stroke);
        canvas.drawRect(
          Rect.fromCenter(
            center: c,
            width: r.width * 0.5,
            height: r.height * 0.5,
          ),
          active ? fill : stroke,
        );
      case _Glyph.markets:
        final Rect m = Rect.fromCenter(
          center: c,
          width: r.width,
          height: r.height * 0.8,
        );
        canvas
          ..drawRect(m, stroke)
          ..drawLine(m.topCenter, m.bottomCenter, stroke);
        if (active) {
          canvas.drawRect(
            Rect.fromLTRB(m.left, m.top, m.center.dx, m.bottom).deflate(2.5),
            fill,
          );
        }
      case _Glyph.pivot:
        Path diamond(double half) => Path()
          ..moveTo(c.dx, c.dy - half)
          ..lineTo(c.dx + half, c.dy)
          ..lineTo(c.dx, c.dy + half)
          ..lineTo(c.dx - half, c.dy)
          ..close();
        canvas
          ..drawPath(diamond(r.width / 2), stroke)
          ..drawPath(diamond(r.width * 0.24), active ? fill : stroke);
      case _Glyph.time:
        final double radius = r.width / 2;
        canvas.drawCircle(c, radius, stroke);
        // Hands at nine o'clock: the "look back" of a time machine.
        canvas
          ..drawLine(c, c.translate(0, -radius * 0.6), stroke)
          ..drawLine(
            c,
            c.translate(
              -radius * 0.5 * math.cos(0.3),
              -radius * 0.5 * math.sin(0.3),
            ),
            stroke,
          );
        if (active) canvas.drawCircle(c, 1.8, fill);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.color != color || old.active != active;
}

class _Tab {
  const _Tab({required this.label, required this.glyph, this.semantics});

  final String label;
  final _Glyph glyph;

  /// Spoken name, where the visible label is abbreviated.
  final String? semantics;
}

class _TabNavigator extends StatelessWidget {
  const _TabNavigator({required this.child, this.navigatorKey});

  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (RouteSettings settings) =>
          MaterialPageRoute<void>(builder: (_) => child, settings: settings),
    );
  }
}
