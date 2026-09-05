import 'package:flutter/foundation.dart';

import 'candle_model.dart';
import 'script_event_model.dart';

/// A playable run: candle data plus its pause-point script, already bound
/// together and index-resolved.
///
/// Campaign levels build this from two bundled JSON files; Endless mode builds
/// it from a generated window over a bundled history pool. The engine cannot
/// tell the two apart, which is the point (ENGINE.md).
@immutable
class SimulationLevel {
  SimulationLevel({
    required this.id,
    required this.realAssetName,
    required this.startingBalance,
    required this.candles,
    required List<PausePoint> pausePoints,
    this.description,
    this.isSyntheticSample = false,
    this.revealFromStart = false,
  })  : assert(candles.length > 1, 'A level needs at least two candles'),
        pausePoints = List<PausePoint>.unmodifiable(
          pausePoints.toList()
            ..sort(
              (PausePoint a, PausePoint b) =>
                  a.triggerIndex.compareTo(b.triggerIndex),
            ),
        );

  factory SimulationLevel.fromJson({
    required Map<String, dynamic> levelJson,
    required Map<String, dynamic> scriptJson,
    String? description,
  }) {
    final List<Candle> candles = (levelJson['candles'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Candle.fromJson)
        .toList(growable: false);

    final List<PausePoint> pausePoints =
        (scriptJson['pause_points'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map((Map<String, dynamic> j) => PausePoint.fromJson(j, candles))
            .toList();

    return SimulationLevel(
      id: levelJson['id'] as String,
      realAssetName: levelJson['real_asset_name'] as String,
      startingBalance: (levelJson['starting_balance'] as num).toDouble(),
      candles: candles,
      pausePoints: pausePoints,
      description: description,
    );
  }

  final String id;

  /// Hidden until Debrief (ENGINE.md §3 blind mode).
  final String realAssetName;

  /// What the event actually was. Shown at the Debrief and on a cleared
  /// tile — never before play, or blind mode is pointless.
  final String? description;

  final double startingBalance;
  final List<Candle> candles;
  final List<PausePoint> pausePoints;

  /// True only for the development sample run, which uses generated numbers.
  /// Every screen that could be mistaken for a historical claim must say so.
  final bool isSyntheticSample;

  /// Skips blind mode (ENGINE.md §3) for this run.
  ///
  /// Only the Custom Simulation sets it. Blind mode exists so a campaign
  /// level cannot be recognised before it is played; when the player chose
  /// the instrument and the dates themselves there is nothing left to hide,
  /// and hiding it anyway would just make the axes unreadable.
  final bool revealFromStart;

  int get length => candles.length;

  PausePoint? pausePointAt(int index) {
    for (final PausePoint p in pausePoints) {
      if (p.triggerIndex == index) return p;
    }
    return null;
  }
}
