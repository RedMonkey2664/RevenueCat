import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// One collapsible section — the Debrief's TAKEAWAY / THE REVEAL / CALL
/// BREAKDOWN / P&L DETAILS rows (artboard 1e).
///
/// The Debrief shows four headings rather than four walls of text: the score
/// is the answer, and each section is there for the player who wants the
/// working. Rows are ruled, wide-tracked and square, like everything else.
class HudAccordion extends StatefulWidget {
  const HudAccordion({
    required this.title,
    required this.child,
    this.summary,
    this.initiallyExpanded = false,
    super.key,
  });

  final String title;

  /// A compact readout beside the title, e.g. "4✓ 3~ 1✕".
  final Widget? summary;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<HudAccordion> createState() => _HudAccordionState();
}

class _HudAccordionState extends State<HudAccordion>
    with SingleTickerProviderStateMixin {
  late bool _open = widget.initiallyExpanded;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.normal,
    value: _open ? 1 : 0,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _open = !_open);
    _open ? _c.forward() : _c.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> curve = CurvedAnimation(
      parent: _c,
      curve: AppMotion.curve,
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            button: true,
            expanded: _open,
            label: widget.title,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              child: SizedBox(
                height: 64,
                child: Row(
                  children: <Widget>[
                    // Title and summary share one block that takes the row;
                    // the chevron stays pinned to the right edge.
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.railLabel(
                                size: 15.5,
                                weight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: 15.5 * 0.2,
                              ),
                            ),
                          ),
                          if (widget.summary != null) ...<Widget>[
                            const SizedBox(width: AppSpacing.md),
                            widget.summary!,
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    RotationTransition(
                      turns: Tween<double>(begin: 0, end: 0.5).animate(curve),
                      child: const Icon(
                        Icons.keyboard_arrow_down,
                        size: 20,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: curve,
            axisAlignment: -1,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
