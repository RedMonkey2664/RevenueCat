import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../app/widgets/pressable.dart';
import '../../../../core/services/progress_service.dart';
import '../level_repository.dart';

/// The campaign as an S-curve path of nodes.
///
/// Artboard 1f of `Market Nerve HUD.dc.html`, whose note is the whole spec:
/// *"S-curve path replaces the tile grid. Cleared nodes show score + stars,
/// current node pulses with PLAY, locked nodes are amber with a lock, no-data
/// is dashed and desaturated."*
///
/// ## On the palette
///
/// The nodes are deliberately **not** in the HUD's mint/amber/red vocabulary.
/// The canvas gives them a playful candy palette with a chunky 3D shadow —
/// closer to a level map in a game than to instrumentation — and lets the
/// tactical chrome frame it. That contrast is the design, not a slip: the path
/// is the one place in the app that should feel like progress rather than like
/// a trading terminal. The colours live in [_NodeSkin] so they are named once
/// instead of scattered.
///
/// Blind mode still holds. A node shows its real event name only once cleared;
/// before that it is the masked plate, exactly as the old tile grid was.
class CampaignPath extends StatelessWidget {
  const CampaignPath({
    required this.entries,
    required this.progress,
    required this.onTap,
    super.key,
  });

  final List<LevelManifestEntry> entries;
  final ProgressState progress;
  final ValueChanged<LevelManifestEntry> onTap;

  /// Height of one node's slot: the largest circle, plus the three label rows
  /// under it.
  ///
  /// The canvas's bezier puts its control points 130pt apart, and taking that
  /// as the node pitch was wrong — the canvas lays its nodes out in a normal
  /// flex column and draws the path *behind* them at approximate coordinates,
  /// so 130 was never a spacing anyone had to honour. Using it literally made
  /// every label collide with the circle below it.
  /// Node pitch, measured off the reference screen: three cleared nodes and
  /// the PLAY node inside one phone height. The label block is *not* added to
  /// it — nodes alternate sides, so a node's labels hang in the gap beside
  /// its neighbour rather than above it.
  static const double _spacing = 120;

  static const double _firstCentre = 54;

  /// How far a node may swing either side of centre. Scaled from the width so
  /// the curve reads the same on a 375 and a 430 screen.
  static double _amplitude(double width) => (width * 0.2).clamp(42.0, 80.0);

  /// The serpentine.
  ///
  /// Strict left-right alternation, as the reference draws it. A sine was
  /// gentler but let two consecutive nodes sit at nearly the same x, and at
  /// this pitch their labels would have collided; alternating guarantees a
  /// full swing of clear space beside every label. The connector's cubic
  /// turns the zig-zag back into an S.
  static double _centreX(int i, double width) =>
      width / 2 + _amplitude(width) * (i.isEven ? -1 : 1);

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: Text(
            'No levels in this market yet.',
            style: AppText.body(size: 12, color: AppColors.textFaint),
          ),
        ),
      );
    }

    // Exactly one node is "current": the first playable, unlocked level the
    // player has not cleared. Everything after it that is free reads as
    // available; everything paid reads as locked.
    final int currentIndex = entries.indexWhere(
      (LevelManifestEntry e) =>
          e.dataStatus.isPlayable &&
          e.isFree &&
          !(progress.forLevel(e.id)?.isCleared ?? false),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final List<Offset> centres = <Offset>[
          for (int i = 0; i < entries.length; i++)
            Offset(_centreX(i, width), _firstCentre + i * _spacing),
        ];
        final double height = _firstCentre + entries.length * _spacing + 40;

        return SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: CustomPaint(
                  painter: _PathPainter(
                    centres: centres,
                    // Rim to rim: at this pitch the segment runs diagonally
                    // past the label rather than starting below it.
                    exitOffset: _PathNode.maxDiameter / 2 - 4,
                    entryOffset: _PathNode.maxDiameter / 2 - 4,
                  ),
                ),
              ),
              for (int i = 0; i < entries.length; i++)
                _positioned(
                  centre: centres[i],
                  child: _PathNode(
                    entry: entries[i],
                    levelProgress: progress.forLevel(entries[i].id),
                    state: _stateFor(i, currentIndex),
                    skinIndex: i,
                    onTap: () => onTap(entries[i]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  _NodeState _stateFor(int i, int currentIndex) {
    final LevelManifestEntry e = entries[i];
    if (!e.dataStatus.isPlayable) return _NodeState.noData;
    if (progress.forLevel(e.id)?.isCleared ?? false) return _NodeState.cleared;
    if (i == currentIndex) return _NodeState.current;
    if (!e.isFree) return _NodeState.locked;
    return _NodeState.available;
  }

  /// Nodes are positioned by their *centre*, with the label column allowed to
  /// overflow below — hence `Clip.none` on the Stack.
  Widget _positioned({required Offset centre, required Widget child}) {
    const double slot = 146;
    return Positioned(
      left: centre.dx - slot / 2,
      top: centre.dy - _PathNode.maxDiameter / 2,
      width: slot,
      child: child,
    );
  }
}

/// The dashed connector.
class _PathPainter extends CustomPainter {
  const _PathPainter({
    required this.centres,
    required this.exitOffset,
    required this.entryOffset,
  });

  final List<Offset> centres;

  /// How far below a node's centre a segment starts — at the rim of its
  /// circle.
  final double exitOffset;

  /// How far above the next node's centre a segment stops — at the rim of
  /// its circle rather than under it.
  final double entryOffset;

  @override
  void paint(Canvas canvas, Size size) {
    if (centres.length < 2) return;

    // One sub-path per gap rather than a single continuous curve: a
    // centre-to-centre path is drawn straight through the labels hanging
    // below each node, which looked like a strike-through.
    final Path path = Path();
    for (int i = 1; i < centres.length; i++) {
      final Offset a = centres[i - 1];
      final Offset b = centres[i];
      final Offset from = Offset(a.dx, a.dy + exitOffset);
      final Offset to = Offset(b.dx, b.dy - entryOffset);
      // The canvas's own connector shape: both control points sit at the
      // midpoint height, one under the start and one over the end, which
      // produces the S rather than a lazy diagonal.
      final double midY = (from.dy + to.dy) / 2;
      path
        ..moveTo(from.dx, from.dy)
        ..cubicTo(from.dx, midY, to.dx, midY, to.dx, to.dy);
    }

    canvas.drawPath(
      _dash(path),
      Paint()
        ..color = AppColors.borderStrong
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  static Path _dash(Path source, {double dash = 6, double gap = 7}) {
    final Path out = Path();
    for (final PathMetric m in source.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        final double next = math.min(d + dash, m.length);
        out.addPath(m.extractPath(d, next), Offset.zero);
        d = next + gap;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.centres != centres ||
      old.exitOffset != exitOffset ||
      old.entryOffset != entryOffset;
}

enum _NodeState { cleared, current, available, locked, noData }

/// One node's colours and size.
@immutable
class _NodeSkin {
  const _NodeSkin({
    required this.top,
    required this.bottom,
    required this.rim,
    required this.diameter,
    this.opacity = 1,
  });

  final Color top;
  final Color bottom;

  /// The colour of the chunky offset shadow that makes the node read as a
  /// physical button.
  final Color rim;

  final double diameter;
  final double opacity;

  /// The candy rotation for reachable nodes, in the reference set's order:
  /// magenta, green, blue. Orange is deliberately absent — it belongs to the
  /// brand now, and a node wearing it would read as the current one.
  static const List<List<Color>> _rotation = <List<Color>>[
    <Color>[Color(0xFFE9509E), Color(0xFFD62E86), Color(0xFF8E1A55)],
    <Color>[Color(0xFF58D68D), Color(0xFF2ECC71), Color(0xFF1E8449)],
    <Color>[Color(0xFF5DADE2), Color(0xFF2E86C1), Color(0xFF1B4F72)],
  ];

  /// Locked nodes alternate a translucent yellow and purple.
  static const List<List<Color>> _lockedRotation = <List<Color>>[
    <Color>[Color(0x59F1C40F), Color(0x4DF39C12), Color(0x66B7950B)],
    <Color>[Color(0x599B59B6), Color(0x4D8E44AD), Color(0x665B2C6F)],
  ];

  static _NodeSkin of(_NodeState state, int index) {
    switch (state) {
      case _NodeState.cleared:
        final List<Color> c = _rotation[index % _rotation.length];
        return _NodeSkin(top: c[0], bottom: c[1], rim: c[2], diameter: 80);
      case _NodeState.current:
        // Bigger, hotter, and the only node that pulses. Amber, so PLAY is
        // the one warm node on a map of cool cleared ones.
        return const _NodeSkin(
          top: Color(0xFFF7C948),
          bottom: Color(0xFFF2A50C),
          rim: Color(0xFFA9700A),
          diameter: 90,
        );
      case _NodeState.available:
        final List<Color> c = _rotation[index % _rotation.length];
        return _NodeSkin(
          top: c[0],
          bottom: c[1],
          rim: c[2],
          diameter: 76,
          opacity: 0.55,
        );
      case _NodeState.locked:
        final List<Color> c = _lockedRotation[index % _lockedRotation.length];
        return _NodeSkin(
          top: c[0],
          bottom: c[1],
          rim: c[2],
          diameter: 76,
          opacity: 0.7,
        );
      case _NodeState.noData:
        return const _NodeSkin(
          top: Color(0x40828C96),
          bottom: Color(0x335A646E),
          rim: Color(0x8032373C),
          diameter: 70,
          opacity: 0.45,
        );
    }
  }
}

class _PathNode extends StatefulWidget {
  const _PathNode({
    required this.entry,
    required this.levelProgress,
    required this.state,
    required this.skinIndex,
    required this.onTap,
  });

  /// The largest node, used to align every slot on one baseline.
  static const double maxDiameter = 90;

  final LevelManifestEntry entry;
  final LevelProgress? levelProgress;
  final _NodeState state;
  final int skinIndex;
  final VoidCallback onTap;

  @override
  State<_PathNode> createState() => _PathNodeState();
}

class _PathNodeState extends State<_PathNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  int get _stars {
    final int? score = widget.levelProgress?.bestScore;
    if (score == null) return 0;
    // 84 and 81 earn three in the canvas, 72 earns two.
    if (score >= 80) return 3;
    if (score >= 60) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final _NodeSkin skin = _NodeSkin.of(widget.state, widget.skinIndex);
    final bool cleared = widget.state == _NodeState.cleared;

    // Only the current node pulses, and only when the platform allows motion.
    final bool pulses = widget.state == _NodeState.current &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (pulses) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else if (_pulse.isAnimating) {
      _pulse.stop();
    }

    final Widget face = _NodeFace(
      skin: skin,
      child: _faceContent(skin),
    );

    return Pressable(
      onTap: widget.onTap,
      minTarget: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: _PathNode.maxDiameter,
            child: Center(
              child: pulses
                  ? ScaleTransition(
                      scale: Tween<double>(begin: 1, end: 1.06).animate(
                        CurvedAnimation(
                          parent: _pulse,
                          curve: Curves.easeInOut,
                        ),
                      ),
                      child: face,
                    )
                  : face,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.entry.maskedTitle,
            style: AppText.mono(
              size: 12.5,
              weight: FontWeight.w500,
              color: skin.top.withValues(alpha: skin.opacity),
              letterSpacing: 12.5 * 0.22,
            ),
          ),
          const SizedBox(height: 2),
          // Blind mode: the real event is named only once cleared.
          if (cleared)
            Text(
              widget.entry.revealTitle.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.headline(size: 15, letterSpacing: 15 * 0.03),
            )
          else
            // A bare row of block glyphs at title size read as a broken
            // progress bar rather than as a redaction. Boxing it — the same
            // plate the level screen's masked ticker uses — makes it
            // unmistakably "name withheld".
            _MaskedName(state: widget.state),
          const SizedBox(height: 3),
          _subLabel(skin),
        ],
      ),
    );
  }


  Widget _faceContent(_NodeSkin skin) {
    switch (widget.state) {
      case _NodeState.cleared:
        return Text(
          '${widget.levelProgress?.bestScore ?? '—'}',
          style: AppText.headline(
            size: 38,
            weight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0,
          ),
        );
      case _NodeState.current:
        return Text(
          'PLAY',
          style: AppText.railLabel(
            size: 22,
            weight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 22 * 0.16,
          ),
        );
      case _NodeState.available:
        return Text(
          widget.entry.indexInMarket.toString().padLeft(2, '0'),
          style: AppText.headline(
            size: 30,
            weight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 0.85),
            letterSpacing: 0,
          ),
        );
      case _NodeState.locked:
        return Icon(
          Icons.lock_outline,
          size: 24,
          color: Colors.white.withValues(alpha: 0.75),
        );
      case _NodeState.noData:
        return Icon(
          Icons.more_horiz,
          size: 20,
          color: AppColors.textSecondary.withValues(alpha: 0.4),
        );
    }
  }

  Widget _subLabel(_NodeSkin skin) {
    switch (widget.state) {
      case _NodeState.cleared:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < 3; i++)
              Icon(
                i < _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 17,
                color: skin.top.withValues(
                  alpha: (i < _stars ? 1.0 : 0.45) * skin.opacity,
                ),
              ),
          ],
        );
      case _NodeState.current:
        return Text(
          // The canvas also shows a call count here. The manifest does not
          // carry one — pause points live in the level's script file, which is
          // only read when a run starts — so difficulty stands alone rather
          // than inventing a number.
          widget.entry.difficulty.label.toUpperCase(),
          style: AppText.label(size: 9),
        );
      case _NodeState.available:
        return Text(
          widget.entry.difficulty.label.toUpperCase(),
          style: AppText.label(size: 9, color: AppColors.textFaint),
        );
      case _NodeState.locked:
        return Text(
          'PRO',
          style: AppText.label(
            size: 9,
            color: skin.top.withValues(alpha: 0.85),
          ),
        );
      case _NodeState.noData:
        return Text(
          'NO DATA',
          style: AppText.label(
            size: 9,
            color: AppColors.textSecondary.withValues(alpha: 0.25),
          ),
        );
    }
  }
}

/// The physical-button face: a lit gradient, an offset rim and a top sheen.
///
/// Flutter has no `inset` box-shadow, which is what the canvas uses for the
/// bevel, so the highlight is a second gradient layered over the face. Close
/// enough at this size and far cheaper than a blur.
class _NodeFace extends StatelessWidget {
  const _NodeFace({required this.skin, required this.child});

  final _NodeSkin skin;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: skin.opacity,
      child: Container(
        width: skin.diameter,
        height: skin.diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[skin.top, skin.bottom],
          ),
          boxShadow: <BoxShadow>[
            // The chunky rim. Zero blur, offset down — this is what makes it
            // read as a button you could press rather than a flat disc.
            BoxShadow(color: skin.rim, offset: const Offset(0, 6)),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              offset: const Offset(0, 8),
              blurRadius: 16,
            ),
          ],
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.white.withValues(alpha: 0.25),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.15),
              ],
              stops: const <double>[0, 0.45, 1],
            ),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// The withheld name of a level that has not been cleared.
///
/// The node the player is about to open says CLASSIFIED — it is about to be
/// revealed, and showing it the same blocks as an unreachable level made the
/// next move look locked. Everything else gets the redaction plate.
class _MaskedName extends StatelessWidget {
  const _MaskedName({required this.state});

  final _NodeState state;

  @override
  Widget build(BuildContext context) {
    if (state == _NodeState.current) {
      return Text(
        'CLASSIFIED',
        style: AppText.headline(
          size: 16,
          color: AppColors.textSecondary,
          letterSpacing: 16 * 0.12,
        ),
      );
    }

    final double alpha = state == _NodeState.noData ? 0.16 : 0.3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border.withValues(alpha: alpha)),
      ),
      child: Text(
        '████',
        style: AppText.mono(
          size: 9,
          color: AppColors.textSecondary.withValues(alpha: alpha + 0.08),
        ),
      ),
    );
  }
}
