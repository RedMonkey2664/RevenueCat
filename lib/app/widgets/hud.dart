import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// The HUD's shared primitives.
///
/// Every screen in the wireframes is built from the same handful of parts —
/// ruled panels, corner-ticked frames, hatched redactions, wide-tracked
/// buttons, a status pip. They live here once so no two screens drift apart.

/// A square panel with a hairline rail. The wireframes' default container.
class HudPanel extends StatelessWidget {
  const HudPanel({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.color,
    this.fill,
    this.dashed = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Rail colour. Defaults to the steel border.
  final Color? color;

  /// Background. Defaults to the barely-lifted surface.
  final Color? fill;

  /// A dashed rail marks a *variant* or a placeholder slot — the wireframes'
  /// low-vote variant and empty states.
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final Color rail = color ?? AppColors.border;
    if (dashed) {
      return CustomPaint(
        painter: _DashedRectPainter(color: rail),
        child: Container(
          color: fill ?? Colors.transparent,
          padding: padding,
          child: child,
        ),
      );
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill ?? AppColors.surface.withValues(alpha: 0.6),
        border: Border.all(color: rail),
      ),
      child: child,
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const double dash = 4;
    const double gap = 3;
    void line(Offset a, Offset b) {
      final double len = (b - a).distance;
      if (len <= 0) return;
      final Offset dir = (b - a) / len;
      double d = 0;
      while (d < len) {
        final double e = math.min(d + dash, len);
        canvas.drawLine(a + dir * d, a + dir * e, p);
        d = e + gap;
      }
    }

    final Rect i = (Offset.zero & size).deflate(0.5);
    line(i.topLeft, i.topRight);
    line(i.topRight, i.bottomRight);
    line(i.bottomRight, i.bottomLeft);
    line(i.bottomLeft, i.topLeft);
  }

  @override
  bool shouldRepaint(_DashedRectPainter old) => old.color != color;
}

/// A frame with L-shaped corner ticks — the chart's viewfinder in the idle
/// state, and the outcome panels on the Pivot.
class CornerTickFrame extends StatelessWidget {
  const CornerTickFrame({
    required this.child,
    this.color = AppColors.accent,
    this.tick = 16,
    this.railColor,
    this.onlyDiagonal = false,
    super.key,
  });

  final Widget child;
  final Color color;
  final double tick;

  /// Optional full rail under the ticks.
  final Color? railColor;

  /// Top-left and bottom-right only — the Pivot's outcome panels.
  final bool onlyDiagonal;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _CornerTickPainter(
        color: color,
        tick: tick,
        rail: railColor,
        onlyDiagonal: onlyDiagonal,
      ),
      child: child,
    );
  }
}

class _CornerTickPainter extends CustomPainter {
  const _CornerTickPainter({
    required this.color,
    required this.tick,
    required this.rail,
    required this.onlyDiagonal,
  });

  final Color color;
  final double tick;
  final Color? rail;
  final bool onlyDiagonal;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect r = (Offset.zero & size).deflate(0.75);
    if (rail != null) {
      canvas.drawRect(
        r,
        Paint()
          ..color = rail!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    final Paint p = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final double t = math.min(tick, size.shortestSide / 3);

    void corner(Offset o, double dx, double dy) {
      canvas
        ..drawLine(o, o + Offset(dx * t, 0), p)
        ..drawLine(o, o + Offset(0, dy * t), p);
    }

    corner(r.topLeft, 1, 1);
    corner(r.bottomRight, -1, -1);
    if (!onlyDiagonal) {
      corner(r.topRight, -1, 1);
      corner(r.bottomLeft, 1, -1);
    }
  }

  @override
  bool shouldRepaint(_CornerTickPainter old) =>
      old.color != color ||
      old.tick != tick ||
      old.rail != rail ||
      old.onlyDiagonal != onlyDiagonal;
}

/// Diagonal hatching — the wireframes' vocabulary for "withheld" (a redacted
/// ticker) and "not here yet" (a loading value, a low-vote slot).
class HatchPainter extends CustomPainter {
  const HatchPainter({
    this.color = const Color(0x33FFFFFF),
    this.spacing = 7,
    this.strokeWidth = 3,
  });

  final Color color;
  final double spacing;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final Paint p = Paint()
      ..color = color
      ..strokeWidth = strokeWidth;
    for (double x = -size.height; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(HatchPainter old) =>
      old.color != color ||
      old.spacing != spacing ||
      old.strokeWidth != strokeWidth;
}

/// A hatched box of a given size.
class HatchBox extends StatelessWidget {
  const HatchBox({
    this.width,
    this.height,
    this.color = const Color(0x2EFFFFFF),
    this.border,
    super.key,
  });

  final double? width;
  final double? height;
  final Color color;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: border == null ? null : Border.all(color: border!),
      ),
      child: CustomPaint(painter: HatchPainter(color: color)),
    );
  }
}

/// The blind-mode ticker: a hatched plate with solid block cells.
///
/// Reads unmistakably as *redacted* rather than as a loading bar — the plate
/// has a border and the cells sit on the hatch like blacked-out characters.
class RedactionPlate extends StatelessWidget {
  const RedactionPlate({
    this.cells = 6,
    this.height = 30,
    this.tall = false,
    this.tint = AppColors.textSecondary,
    super.key,
  });

  /// How many blocked-out characters.
  final int cells;
  final double height;

  /// The idle state's plate is two rows tall with staggered cells.
  final bool tall;

  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Asset name hidden',
      child: Container(
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: tint.withValues(alpha: 0.28)),
        ),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: CustomPaint(
                painter: HatchPainter(
                  color: tint.withValues(alpha: 0.16),
                  spacing: 8,
                  strokeWidth: 3.5,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(tall ? 6 : 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (int i = 0; i < cells; i++) ...<Widget>[
                    if (i > 0) SizedBox(width: tall ? 6 : 4),
                    Expanded(
                      child: Padding(
                        // Tall plates stagger their cells like an uneven
                        // redaction; short plates keep a clean row.
                        padding: EdgeInsets.only(
                          bottom: tall && i >= cells / 2 ? height * 0.42 : 0,
                        ),
                        child: ColoredBox(color: tint.withValues(alpha: 0.32)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The wide-tracked HUD button, in three weights.
///
///   * outlined — a state-coloured rail over a faint tint (START RUN, HOLD).
///   * filled — the one primary action on a screen (NEXT LEVEL).
///   * ghost — a secondary action, steel rail (CAMPAIGN).
enum HudButtonStyle { outlined, filled, ghost }

class HudButton extends StatefulWidget {
  const HudButton({
    required this.label,
    required this.onPressed,
    this.color = AppColors.accent,
    this.style = HudButtonStyle.outlined,
    this.subtitle,
    this.trailing,
    this.height = 56,
    this.fontSize = 18,
    this.alignStart = false,
    this.letterSpacingEm = 0.24,
    super.key,
  });

  final String label;

  /// Null renders the button visibly disabled.
  final VoidCallback? onPressed;

  final Color color;
  final HudButtonStyle style;

  /// Right-aligned secondary text ("DO NOTHING").
  final String? subtitle;
  final Widget? trailing;
  final double height;
  final double fontSize;
  final bool alignStart;
  final double letterSpacingEm;

  @override
  State<HudButton> createState() => _HudButtonState();
}

class _HudButtonState extends State<HudButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;
    final Color c = enabled ? widget.color : AppColors.textFaint;

    final (Color fill, Color rail, Color text) = switch (widget.style) {
      HudButtonStyle.filled => (
        c.withValues(alpha: _down ? 0.8 : 1),
        c,
        enabled ? AppColors.onAccent : AppColors.background,
      ),
      HudButtonStyle.outlined => (
        c.withValues(alpha: _down ? 0.2 : 0.09),
        c.withValues(alpha: enabled ? 0.85 : 0.4),
        c,
      ),
      HudButtonStyle.ghost => (
        _down ? AppColors.surfaceRaised : Colors.transparent,
        AppColors.borderStrong,
        enabled ? AppColors.textSecondary : AppColors.textFaint,
      ),
    };

    final bool spread =
        widget.alignStart || widget.subtitle != null || widget.trailing != null;

    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                widget.onPressed!();
              }
            : null,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md + 2),
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: rail, width: 1.2),
          ),
          child: Row(
            mainAxisAlignment: spread
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.center,
            children: <Widget>[
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    style: AppText.railLabel(
                      size: widget.fontSize,
                      weight: FontWeight.w800,
                      color: text,
                      letterSpacing: widget.fontSize * widget.letterSpacingEm,
                    ),
                  ),
                ),
              ),
              if (widget.subtitle != null) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  widget.subtitle!,
                  style: AppText.label(
                    size: 10,
                    weight: FontWeight.w600,
                    color: text.withValues(alpha: 0.75),
                  ),
                ),
              ],
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

/// A dot and a word — "● ARMED", "● LIVE", "● STOP".
///
/// The dot breathes while [pulse] is on, at ambient speed. It honours the OS
/// reduce-motion setting; an ambient loop that never settles would otherwise
/// also keep every test harness from reaching idle.
class StatusPip extends StatefulWidget {
  const StatusPip({
    required this.label,
    required this.color,
    this.dotColor,
    this.pulse = true,
    this.showDot = true,
    super.key,
  });

  final String label;
  final Color color;

  /// The dot may differ from the word — the idle level screen's red ARMED dot
  /// next to a grey word.
  final Color? dotColor;
  final bool pulse;
  final bool showDot;

  @override
  State<StatusPip> createState() => _StatusPipState();
}

class _StatusPipState extends State<StatusPip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.ambient,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool animate =
        widget.pulse &&
        widget.showDot &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (animate) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else if (_c.isAnimating) {
      _c.stop();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.showDot) ...<Widget>[
          FadeTransition(
            opacity: animate
                ? Tween<double>(begin: 0.35, end: 1).animate(
                    CurvedAnimation(parent: _c, curve: Curves.easeInOut),
                  )
                : const AlwaysStoppedAnimation<double>(0.9),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: widget.dotColor ?? widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs + 3),
        ],
        Text(
          widget.label,
          style: AppText.label(
            size: 10.5,
            weight: FontWeight.w600,
            color: widget.color,
          ),
        ),
      ],
    );
  }
}

/// "——— WHAT DO YOU DO? ———": a label ruled off on both sides.
class RuledLabel extends StatelessWidget {
  const RuledLabel({
    required this.text,
    required this.color,
    this.textColor,
    this.size = 16,
    super.key,
  });

  final String text;
  final Color color;
  final Color? textColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget rule() => Expanded(
      child: Container(height: 1, color: color.withValues(alpha: 0.35)),
    );
    return Row(
      children: <Widget>[
        rule(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 4),
          child: Text(
            text,
            style: AppText.railLabel(
              size: size,
              weight: FontWeight.w800,
              color: textColor ?? AppColors.textSecondary,
              letterSpacing: size * 0.3,
            ),
          ),
        ),
        rule(),
      ],
    );
  }
}

/// Segmented progress — the streak bar.
class SegmentBar extends StatelessWidget {
  const SegmentBar({
    required this.filled,
    required this.total,
    this.color = AppColors.accent,
    this.height = 5,
    this.gap = 4,
    this.width,
    super.key,
  });

  final int filled;
  final int total;
  final Color color;
  final double height;
  final double gap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final Widget row = Row(
      children: <Widget>[
        for (int i = 0; i < total; i++) ...<Widget>[
          if (i > 0) SizedBox(width: gap),
          Expanded(
            child: AnimatedContainer(
              duration: AppMotion.slow,
              curve: AppMotion.curve,
              height: height,
              color: i < filled ? color : AppColors.borderStrong,
            ),
          ),
        ],
      ],
    );
    return width == null ? row : SizedBox(width: width, child: row);
  }
}

/// A figure with a small caption under it — the pre-run brief's cells, the
/// Debrief's three stats, the Pivot's "IF RIGHT / IF WRONG".
class HudStatCell extends StatelessWidget {
  const HudStatCell({
    required this.value,
    required this.label,
    this.valueColor = AppColors.textPrimary,
    this.borderColor,
    this.fill,
    this.valueWidget,
    this.alignStart = true,
    this.valueSize = 34,
    this.mono = false,
    this.labelColor = AppColors.textSecondary,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md + 2,
      vertical: AppSpacing.md - 2,
    ),
    super.key,
  });

  final String value;
  final String label;
  final Color valueColor;
  final Color? borderColor;
  final Color? fill;

  /// Replaces the value text — the severity triangles.
  final Widget? valueWidget;
  final bool alignStart;
  final double valueSize;

  /// JetBrains Mono rather than Inter for the figure.
  final bool mono;
  final Color labelColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final CrossAxisAlignment cross = alignStart
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.center;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill ?? AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: borderColor ?? AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: cross,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          valueWidget ??
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: alignStart ? Alignment.centerLeft : Alignment.center,
                child: Text(
                  value,
                  style: mono
                      ? AppText.display(
                          size: valueSize,
                          weight: FontWeight.w700,
                          color: valueColor,
                          height: 1.1,
                        )
                      : AppText.headline(
                          size: valueSize,
                          weight: FontWeight.w800,
                          color: valueColor,
                          height: 1.1,
                        ),
                ),
              ),
          const SizedBox(height: AppSpacing.xs + 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignStart ? Alignment.centerLeft : Alignment.center,
            child: Text(
              label,
              maxLines: 1,
              style: AppText.label(
                size: 10.5,
                weight: FontWeight.w600,
                color: labelColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The top bar used by every HUD screen: a left action, a centred
/// wide-tracked title, and an optional right-hand readout. Built by hand
/// rather than with [AppBar] so the three slots align the way the wireframes
/// draw them.
class HudTopBar extends StatelessWidget implements PreferredSizeWidget {
  const HudTopBar({
    required this.title,
    this.titleColor = AppColors.accent,
    this.leading,
    this.trailing,
    this.railColor,
    this.centerTitle = true,
    super.key,
  });

  final String title;
  final Color titleColor;
  final Widget? leading;
  final Widget? trailing;
  final Color? railColor;
  final bool centerTitle;

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: railColor ?? AppColors.border),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 57,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Align(
                alignment: centerTitle
                    ? Alignment.center
                    : Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: centerTitle ? 76 : AppSpacing.md + 4,
                    right: 76,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      maxLines: 1,
                      style: AppText.railLabel(
                        size: 17,
                        weight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                  ),
                ),
              ),
              if (leading != null)
                Positioned(left: AppSpacing.xs, child: leading!),
              if (trailing != null)
                Positioned(right: AppSpacing.md, child: trailing!),
            ],
          ),
        ),
      ),
    );
  }
}

/// "‹ BACK", in the accent.
class HudBackButton extends StatelessWidget {
  const HudBackButton({this.onTap, this.label = 'BACK', super.key});

  final VoidCallback? onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap ?? () => Navigator.of(context).maybePop(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kMinTouchTarget,
            minWidth: kMinTouchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.chevron_left,
                  size: 22,
                  color: AppColors.accent,
                ),
                Text(
                  label,
                  style: AppText.railLabel(size: 15, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An "✕" close control with a full tap target.
class HudCloseButton extends StatelessWidget {
  const HudCloseButton({
    required this.onTap,
    this.boxed = false,
    this.color = AppColors.textSecondary,
    super.key,
  });

  final VoidCallback onTap;

  /// The paywall's close sits in a ruled square.
  final bool boxed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Close',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: boxed ? 48 : kMinTouchTarget,
          height: boxed ? 48 : kMinTouchTarget,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: boxed ? Border.all(color: AppColors.borderStrong) : null,
            ),
            child: Icon(Icons.close, size: 22, color: color),
          ),
        ),
      ),
    );
  }
}

/// Faint horizontal scanlines over the whole app — the "glass" in the
/// wireframes. Painted once into its own layer, so it costs one texture, not
/// a repaint per frame.
class Scanlines extends StatelessWidget {
  const Scanlines({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        child,
        const Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(painter: _ScanlinePainter()),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  const _ScanlinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = const Color(0x08FFFFFF)
      ..strokeWidth = 1;
    for (double y = 1.5; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_ScanlinePainter old) => false;
}
