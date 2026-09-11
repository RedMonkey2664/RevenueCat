import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/shell_state.dart';
import '../../app/theme.dart';
import '../../app/widgets/hud.dart';
import 'model/pivot_models.dart';
import 'services/pivot_controller.dart';
import 'widgets/pivot_views.dart';

/// Daily Pivot tab: one yes/no call on Bitcoin a day (DAILY_PIVOT.md,
/// artboards 1g–1j).
///
/// The screen is a switch over [PivotPhase]; the controller owns the day.
/// Discipline Points only, never money — the framing sits beside the vote
/// buttons and on every points readout (CLAUDE.md).
class PivotHome extends ConsumerStatefulWidget {
  const PivotHome({super.key});

  @override
  ConsumerState<PivotHome> createState() => _PivotHomeState();
}

class _PivotHomeState extends ConsumerState<PivotHome> {
  Timer? _poll;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// The live tape refreshes every 15 seconds, and only while this tab is
  /// the one on screen — never a market API poll in the background.
  void _setPolling(bool on) {
    if (on && _poll == null) {
      _poll = Timer.periodic(
        const Duration(seconds: 15),
        (_) => ref.read(pivotControllerProvider.notifier).refreshLive(),
      );
    } else if (!on && _poll != null) {
      _poll!.cancel();
      _poll = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final PivotViewState s = ref.watch(pivotControllerProvider);
    final bool visible = ref.watch(shellTabProvider) == AppTab.pivot;
    final bool live =
        visible &&
        (s.phase == PivotPhase.voting || s.phase == PivotPhase.locked);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _setPolling(live);
    });

    return Scaffold(
      appBar: HudTopBar(
        title: 'DAILY PIVOT',
        centerTitle: false,
        trailing: _status(s),
      ),
      body: AnimatedSwitcher(
        duration: AppMotion.normal,
        switchInCurve: AppMotion.curve,
        child: KeyedSubtree(
          key: ValueKey<PivotPhase>(s.phase),
          child: switch (s.phase) {
            PivotPhase.loading => const PivotLoadingView(),
            PivotPhase.beforeOpen => PivotBeforeOpenView(state: s),
            PivotPhase.voting => PivotVoteView(state: s),
            PivotPhase.locked => PivotLockedView(state: s),
            PivotPhase.pollClosed => PivotPollClosedView(state: s),
            PivotPhase.resolved => PivotResolvedView(state: s),
            PivotPhase.missed => PivotMissedView(state: s),
            PivotPhase.failed => PivotFailedView(state: s),
          },
        ),
      ),
    );
  }

  Widget _status(PivotViewState s) {
    final (String text, Color color) = switch (s.phase) {
      PivotPhase.locked => ('LOCKED', AppColors.textSecondary),
      PivotPhase.pollClosed ||
      PivotPhase.missed => ('POLL CLOSED', AppColors.caution),
      PivotPhase.resolved => ('RESOLVED', AppColors.textSecondary),
      PivotPhase.beforeOpen => ('OPENS 09:00 IST', AppColors.textSecondary),
      _ => (
        '${PivotClock.shortDate(s.dayKey)} · DAY ${s.pivotDay}',
        AppColors.textSecondary,
      ),
    };
    return Text(
      text,
      style: AppText.label(size: 11, weight: FontWeight.w500, color: color),
    );
  }
}
