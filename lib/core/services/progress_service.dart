import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/simulator/engine/simulation_mode.dart';

/// What the player has done on one level.
@immutable
class LevelProgress {
  const LevelProgress({
    required this.levelId,
    required this.bestScore,
    required this.bestPnl,
    required this.timesPlayed,
    required this.modesPlayed,
  });

  factory LevelProgress.fromJson(Map<String, dynamic> json) {
    return LevelProgress(
      levelId: json['level_id'] as String,
      bestScore: json['best_score'] as int?,
      bestPnl: (json['best_pnl'] as num?)?.toDouble(),
      timesPlayed: json['times_played'] as int? ?? 0,
      modesPlayed: (json['modes_played'] as List<dynamic>? ?? <dynamic>[])
          .cast<String>()
          .toSet(),
    );
  }

  final String levelId;

  /// Null when every run so far contained nothing gradeable.
  final int? bestScore;

  final double? bestPnl;
  final int timesPlayed;

  /// Which modes this level has been played in, so the map can show that
  /// advanced is still untried.
  final Set<String> modesPlayed;

  bool get isCleared => timesPlayed > 0;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'level_id': levelId,
        'best_score': bestScore,
        'best_pnl': bestPnl,
        'times_played': timesPlayed,
        'modes_played': modesPlayed.toList(),
      };

  LevelProgress mergedWith({
    required int? score,
    required double pnl,
    required SimulationMode mode,
  }) {
    return LevelProgress(
      levelId: levelId,
      bestScore: switch ((bestScore, score)) {
        (null, final int? s) => s,
        (final int b, null) => b,
        (final int b, final int s) => s > b ? s : b,
      },
      bestPnl: bestPnl == null || pnl > bestPnl! ? pnl : bestPnl,
      timesPlayed: timesPlayed + 1,
      modesPlayed: <String>{...modesPlayed, mode.name},
    );
  }
}

/// Local progress across all three pillars (ARCHITECTURE.md: no backend, no
/// account — `shared_preferences` only, per CLAUDE.md's storage rule).
@immutable
class ProgressState {
  const ProgressState({
    required this.levels,
    required this.pivotBonusPoints,
  });

  static const ProgressState empty = ProgressState(
    levels: <String, LevelProgress>{},
    pivotBonusPoints: 0,
  );

  final Map<String, LevelProgress> levels;

  /// Daily Pivot's contribution to the shared total (DAILY_PIVOT.md). Written
  /// by Phase 6; kept here so the Profile has one number to read.
  final int pivotBonusPoints;

  LevelProgress? forLevel(String levelId) => levels[levelId];

  int get clearedCount =>
      levels.values.where((LevelProgress p) => p.isCleared).length;

  /// The cross-app stat (ENGINE.md §4).
  ///
  /// DECISION(somi): the Simulator contributes each level's *best* score, not
  /// the sum of every run. Replaying a level to improve raises the total;
  /// replaying it to farm the same score does not.
  int get totalDisciplinePoints {
    final int fromLevels = levels.values.fold<int>(
      0,
      (int sum, LevelProgress p) => sum + (p.bestScore ?? 0),
    );
    return fromLevels + pivotBonusPoints;
  }
}

/// Reads and writes [ProgressState]. Deliberately dumb: no migrations, no
/// schema versioning beyond the key prefix, because there is nothing here
/// worth recovering if it is lost.
class ProgressService {
  const ProgressService(this._prefs);

  static const String _levelsKey = 'mn.progress.levels.v1';
  static const String _pivotKey = 'mn.progress.pivot_points.v1';

  final SharedPreferences _prefs;

  ProgressState load() {
    final String? raw = _prefs.getString(_levelsKey);
    final Map<String, LevelProgress> levels = <String, LevelProgress>{};

    if (raw != null) {
      try {
        final Map<String, dynamic> decoded =
            jsonDecode(raw) as Map<String, dynamic>;
        for (final MapEntry<String, dynamic> e in decoded.entries) {
          levels[e.key] =
              LevelProgress.fromJson(e.value as Map<String, dynamic>);
        }
      } on Object catch (error) {
        // Corrupt local data must never block play: start clean instead.
        debugPrint('Progress data unreadable, starting fresh: $error');
      }
    }

    return ProgressState(
      levels: levels,
      pivotBonusPoints: _prefs.getInt(_pivotKey) ?? 0,
    );
  }

  Future<void> save(ProgressState state) async {
    final Map<String, dynamic> encoded = <String, dynamic>{
      for (final MapEntry<String, LevelProgress> e in state.levels.entries)
        e.key: e.value.toJson(),
    };
    await _prefs.setString(_levelsKey, jsonEncode(encoded));
    await _prefs.setInt(_pivotKey, state.pivotBonusPoints);
  }
}

/// Overridden in main() once SharedPreferences has loaded.
final Provider<SharedPreferences> sharedPreferencesProvider =
    Provider<SharedPreferences>(
  (Ref ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden at startup',
  ),
);

final Provider<ProgressService> progressServiceProvider =
    Provider<ProgressService>(
  (Ref ref) => ProgressService(ref.watch(sharedPreferencesProvider)),
);

final NotifierProvider<ProgressNotifier, ProgressState> progressProvider =
    NotifierProvider<ProgressNotifier, ProgressState>(ProgressNotifier.new);

class ProgressNotifier extends Notifier<ProgressState> {
  @override
  ProgressState build() => ref.watch(progressServiceProvider).load();

  /// Records a finished run. Called once, from the Debrief.
  Future<void> recordRun({
    required String levelId,
    required int? score,
    required double pnl,
    required SimulationMode mode,
  }) async {
    final LevelProgress existing = state.levels[levelId] ??
        LevelProgress(
          levelId: levelId,
          bestScore: null,
          bestPnl: null,
          timesPlayed: 0,
          modesPlayed: const <String>{},
        );

    state = ProgressState(
      levels: <String, LevelProgress>{
        ...state.levels,
        levelId: existing.mergedWith(score: score, pnl: pnl, mode: mode),
      },
      pivotBonusPoints: state.pivotBonusPoints,
    );

    await ref.read(progressServiceProvider).save(state);
  }
}
