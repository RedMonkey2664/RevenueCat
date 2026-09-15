import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme.dart';
import 'hud.dart';
import 'nerve_avatar.dart';

/// The mascot's animations, one per use.
///
/// Every file in `assets/mascot/` is named for where it plays, and each gets
/// one value here plus one line in `pubspec.yaml`. A Flow export on a green
/// screen goes through `tool/mascot/key_clip.py` first, which bakes the key
/// onto the app's ground and names the result for its use.
enum MascotClip {
  /// The Nerve cat with its orbiting light. Plays wherever the app is doing
  /// real work the player has to wait for.
  loading('assets/mascot/loading.mp4'),

  /// The kitten walks in, sits, and waves hello. Keyed onto the app's
  /// ground, so it plays frameless. The first thing a new player sees.
  welcome('assets/mascot/welcome.mp4');

  const MascotClip(this.asset);

  final String asset;
}

/// How a clip is framed.
enum MascotFrame {
  /// The whole 9:16 clip, corner-ticked like the chart's viewfinder. For
  /// screen-level waits, where the cat is the only thing on screen.
  portrait,

  /// The cat's head in a ringed disc — the same shape as the drawn
  /// [NerveAvatar], so the two read as one character. For waits inside a
  /// pane, where a full portrait would crowd the layout.
  disc,

  /// No frame at all — for clips keyed onto the app's ground, where the
  /// character should stand on the page rather than sit in a window.
  bare,
}

/// Plays a mascot clip: muted, looping, framed.
///
/// Always silent. The clips carry an audio track, and a loader that makes a
/// sound — or interrupts the player's music — is broken, so the volume is
/// zeroed before the first frame plays and the player mixes with other audio.
///
/// Until the first frame decodes, and on any platform that cannot play the
/// clip, the drawn [NerveAvatar] stands in: the character is always there,
/// the video is an upgrade.
class MascotVideo extends StatefulWidget {
  const MascotVideo({
    required this.clip,
    this.frame = MascotFrame.portrait,
    this.size = 180,
    super.key,
  });

  final MascotClip clip;
  final MascotFrame frame;

  /// Width of the portrait, or diameter of the disc.
  final double size;

  @override
  State<MascotVideo> createState() => _MascotVideoState();
}

class _MascotVideoState extends State<MascotVideo> {
  VideoPlayerController? _controller;
  bool _failed = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final VideoPlayerController c = VideoPlayerController.asset(
      widget.clip.asset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = c;
    try {
      await c.initialize();
      await c.setVolume(0);
      await c.setLooping(true);
      if (!mounted) return;
      _sync();
      setState(() {});
    } on Object catch (error) {
      debugPrint('Mascot clip ${widget.clip.name} unavailable: $error');
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _sync();
  }

  /// Plays, or holds the first frame when the OS asks for reduced motion.
  void _sync() {
    final VideoPlayerController? c = _controller;
    if (c == null || !c.value.isInitialized) return;
    _reduceMotion ? c.pause() : c.play();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  bool get _ready => !_failed && (_controller?.value.isInitialized ?? false);

  @override
  Widget build(BuildContext context) {
    final bool disc = widget.frame == MascotFrame.disc;
    final double w = widget.size;
    final double h = disc ? w : w * 16 / 9;

    final Widget stand = Center(
      child: NerveAvatar(size: disc ? w : w * 0.8, glow: false),
    );

    final Widget picture = AnimatedSwitcher(
      duration: AppMotion.slow,
      child: _ready
          ? _Picture(
              key: const ValueKey<String>('video'),
              controller: _controller!,
              // The disc sits on the cat's head; the portrait shows it all.
              alignment: disc ? const Alignment(0, -0.45) : Alignment.center,
            )
          : KeyedSubtree(key: const ValueKey<String>('stand'), child: stand),
    );

    return Semantics(
      label: 'Market Nerve mascot',
      image: true,
      child: SizedBox(
        width: w,
        height: h,
        child: widget.frame == MascotFrame.bare
            ? ClipRect(child: picture)
            : disc
            ? DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.38),
                    width: 1.5,
                  ),
                ),
                child: ClipOval(child: picture),
              )
            : CornerTickFrame(
                railColor: AppColors.border,
                tick: 18,
                child: ClipRect(child: picture),
              ),
      ),
    );
  }
}

class _Picture extends StatelessWidget {
  const _Picture({
    required this.controller,
    required this.alignment,
    super.key,
  });

  final VideoPlayerController controller;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final Size v = controller.value.size;
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        alignment: alignment,
        child: SizedBox(
          width: v.width,
          height: v.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}

/// The mascot with a caption under it: "● FETCHING THE TAPE".
///
/// This is for waits on *work* — a network fetch, a history pool, a level
/// being armed. A single loading value inside a row keeps the hatch-and-pulse
/// of the feed-state grammar (artboard 1l); the mascot is never used there.
class MascotLoader extends StatelessWidget {
  const MascotLoader({
    required this.caption,
    this.detail,
    this.frame = MascotFrame.disc,
    this.size,
    super.key,
  });

  final String caption;
  final String? detail;
  final MascotFrame frame;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final double s = size ?? (frame == MascotFrame.disc ? 132 : 200);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        MascotVideo(clip: MascotClip.loading, frame: frame, size: s),
        const SizedBox(height: AppSpacing.lg),
        StatusPip(label: caption, color: AppColors.accent),
        if (detail != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            detail!,
            textAlign: TextAlign.center,
            style: AppText.body(size: 13, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// Runs [task], and puts the mascot on screen if it takes long enough to be
/// worth a word.
///
/// Nothing appears for the first quarter-second, so a fast load never
/// flashes a loader at the player; once the mascot *is* up it stays for at
/// least 900ms, so it never blinks off mid-animation either. Back is blocked
/// while it is showing — the task cannot be cancelled halfway.
Future<T> runWithMascot<T>(
  BuildContext context,
  Future<T> Function() task, {
  required String caption,
  String? detail,
}) async {
  final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
  Route<void>? route;
  DateTime? shownAt;

  final Timer timer = Timer(const Duration(milliseconds: 250), () {
    shownAt = DateTime.now();
    route = PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: AppMotion.normal,
      reverseTransitionDuration: AppMotion.normal,
      pageBuilder: (_, _, _) => PopScope(
        canPop: false,
        child: _MascotScreen(caption: caption, detail: detail),
      ),
      transitionsBuilder: (_, Animation<double> a, _, Widget child) =>
          FadeTransition(opacity: a, child: child),
    );
    navigator.push(route!);
  });

  try {
    return await task();
  } finally {
    timer.cancel();
    final Route<void>? shown = route;
    if (shown != null) {
      const Duration minimum = Duration(milliseconds: 900);
      final Duration elapsed = DateTime.now().difference(shownAt!);
      if (elapsed < minimum) await Future<void>.delayed(minimum - elapsed);
      if (shown.isActive) navigator.removeRoute(shown);
    }
  }
}

class _MascotScreen extends StatelessWidget {
  const _MascotScreen({required this.caption, this.detail});

  final String caption;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    // Tall enough to be the moment, short enough to leave room for the words
    // on a 667pt phone.
    final double width = (screen.height * 0.42 * 9 / 16).clamp(150.0, 240.0);
    return ColoredBox(
      color: AppColors.background.withValues(alpha: 0.97),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: MascotLoader(
            caption: caption,
            detail: detail,
            frame: MascotFrame.portrait,
            size: width,
          ),
        ),
      ),
    );
  }
}
