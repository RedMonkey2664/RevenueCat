import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The four tabs of the shell, in bar order.
enum AppTab { simulator, markets, pivot, timeMachine }

/// Which tab is showing.
///
/// A provider rather than local state in the shell so any screen can move the
/// player between pillars — the Daily Pivot's "PLAY A LEVEL" is the funnel
/// back into the Simulator, and it has to be one tap.
final NotifierProvider<ShellTabNotifier, AppTab> shellTabProvider =
    NotifierProvider<ShellTabNotifier, AppTab>(ShellTabNotifier.new);

class ShellTabNotifier extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.simulator;

  void select(AppTab tab) => state = tab;
}

/// The Simulator tab's own navigator.
///
/// A run is pushed on the root navigator (full screen, no bottom bar), so the
/// Debrief's "CAMPAIGN" button has to unwind two stacks: the root one back to
/// the shell, and this one back to the campaign map in case the run was
/// started from the Endless or Custom Simulation screens.
final GlobalKey<NavigatorState> simulatorNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'simulator-tab');
