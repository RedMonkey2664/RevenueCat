import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/progress_service.dart'
    show sharedPreferencesProvider;
import '../model/chart_drawing.dart';
import '../model/chart_types.dart';

/// Persists chart setup between sessions.
///
/// Two different scopes, deliberately:
///   • Settings (chart type, indicators, scale) are **global**. Someone who
///     works in Heikin-Ashi with an RSI expects that everywhere, not to
///     re-pick it per symbol.
///   • Drawings are **per chart**, keyed by instrument or level id. A
///     trendline on NIFTY means nothing on BTC.
///
/// The interval is not persisted globally: 1m is a sensible timeframe on a
/// live chart and a meaningless one on a bundled daily campaign level, so
/// each host supplies its own default.
class ChartPreferences {
  const ChartPreferences(this._prefs);

  static const String _settingsKey = 'chart_settings_v1';
  static const String _drawingsPrefix = 'chart_drawings_v1:';

  /// Drawings are cheap but not free to paint, and an accidental scribble
  /// session should not make a chart permanently slow.
  static const int maxDrawingsPerChart = 60;

  final SharedPreferences _prefs;

  ChartSettings loadSettings({required BarInterval defaultInterval}) {
    final String? raw = _prefs.getString(_settingsKey);
    if (raw == null) return ChartSettings(interval: defaultInterval);

    try {
      final ChartSettings stored = ChartSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      // The stored interval is ignored on purpose (see the class comment),
      // and the tool always starts as the cursor — reopening a chart already
      // armed with the rectangle tool feels broken.
      return stored.copyWith(
        interval: defaultInterval,
        tool: ChartTool.cursor,
      );
    } on Object catch (error) {
      debugPrint('Chart settings unreadable, using defaults: $error');
      return ChartSettings(interval: defaultInterval);
    }
  }

  Future<void> saveSettings(ChartSettings settings) =>
      _prefs.setString(_settingsKey, jsonEncode(settings.toJson()));

  List<ChartDrawing> loadDrawings(String chartId) {
    final String? raw = _prefs.getString('$_drawingsPrefix$chartId');
    if (raw == null) return const <ChartDrawing>[];

    try {
      return <ChartDrawing>[
        for (final dynamic d in jsonDecode(raw) as List<dynamic>)
          ChartDrawing.fromJson(d as Map<String, dynamic>),
      ];
    } on Object catch (error) {
      debugPrint('Drawings unreadable for $chartId: $error');
      return const <ChartDrawing>[];
    }
  }

  Future<void> saveDrawings(String chartId, List<ChartDrawing> drawings) {
    final List<ChartDrawing> capped = drawings.length > maxDrawingsPerChart
        ? drawings.sublist(drawings.length - maxDrawingsPerChart)
        : drawings;

    return _prefs.setString(
      '$_drawingsPrefix$chartId',
      jsonEncode(<Map<String, dynamic>>[
        for (final ChartDrawing d in capped) d.toJson(),
      ]),
    );
  }

  Future<void> clearDrawings(String chartId) =>
      _prefs.remove('$_drawingsPrefix$chartId');
}

final Provider<ChartPreferences> chartPreferencesProvider =
    Provider<ChartPreferences>(
  (Ref ref) => ChartPreferences(ref.watch(sharedPreferencesProvider)),
);
