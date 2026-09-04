import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../engine/script_event_model.dart';

/// The screen's reaction when a pause point fires (ENGINE.md §2, DESIGN.md).
///
/// Two treatments, driven entirely by the script's `flash_treatment` field:
/// a hard fast red pulse for a genuine crash, a slow soft amber one for the
/// quieter "are you sure?" moments like a dead-cat bounce.
///
/// Purely decorative — it never blocks input, so the decision panel underneath
/// stays tappable.
class PauseFlashOverlay extends StatefulWidget {
  const PauseFlashOverlay({required this.treatment, super.key});

  /// Null when no pause point is active; the overlay then draws nothing.
  final FlashTreatment? treatment;

  @override
  State<PauseFlashOverlay> createState() => _PauseFlashOverlayState();
}

class _PauseFlashOverlayState extends State<PauseFlashOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  @override
  void initState() {
    super.initState();
    _syncToTreatment();
  }

  @override
  void didUpdateWidget(PauseFlashOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.treatment != widget.treatment) _syncToTreatment();
  }

  void _syncToTreatment() {
    final FlashTreatment? treatment = widget.treatment;
    if (treatment == null) {
      _controller
        ..stop()
        ..value = 0;
      return;
    }
    _controller
      ..duration = switch (treatment) {
        FlashTreatment.redFlashHard => const Duration(milliseconds: 260),
        FlashTreatment.amberFlashSoft => const Duration(milliseconds: 900),
      }
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FlashTreatment? treatment = widget.treatment;
    if (treatment == null) return const SizedBox.shrink();

    final (Color color, double peak) = switch (treatment) {
      FlashTreatment.redFlashHard => (AppColors.flashHard, 0.30),
      FlashTreatment.amberFlashSoft => (AppColors.flashSoft, 0.16),
    };

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: color.withValues(alpha: _controller.value * 0.9),
                width: 3,
              ),
              gradient: RadialGradient(
                radius: 1.1,
                colors: <Color>[
                  Colors.transparent,
                  color.withValues(alpha: _controller.value * peak),
                ],
              ),
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}
