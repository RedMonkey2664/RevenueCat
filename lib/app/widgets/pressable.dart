import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// A tappable surface that dips slightly while held.
///
/// Two reasons this exists rather than a bare InkWell: a ripple reads poorly
/// on near-black surfaces, and a small scale response plus a haptic tick is
/// what makes a phone UI feel physical rather than like a web page in a
/// WebView.
///
/// It also guarantees the 44pt minimum tap target regardless of how small the
/// visual is.
class Pressable extends StatefulWidget {
  const Pressable({
    required this.child,
    required this.onTap,
    this.scale = 0.97,
    this.haptic = true,
    this.minTarget = kMinTouchTarget,
    super.key,
  });

  final Widget child;

  /// Null renders the child inert but still visible — the DESIGN.md rule for
  /// locked chrome.
  final VoidCallback? onTap;

  final double scale;
  final bool haptic;
  final double minTarget;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null;

    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: enabled
            ? () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              }
            : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: widget.minTarget,
            minHeight: widget.minTarget,
          ),
          child: AnimatedScale(
            scale: _down ? widget.scale : 1,
            duration: AppMotion.fast,
            curve: AppMotion.curve,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Centres a small control inside a full-size tap target.
///
/// Used for console chips, which should look compact but must not be a 24pt
/// hit box on a phone.
class TouchTarget extends StatelessWidget {
  const TouchTarget({
    required this.child,
    this.height = kMinTouchTarget,
    super.key,
  });

  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(child: child),
    );
  }
}
