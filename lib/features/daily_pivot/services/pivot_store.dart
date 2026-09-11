import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/progress_service.dart'
    show sharedPreferencesProvider;
import '../model/pivot_models.dart';

/// This device's side of the Daily Pivot: its own votes, the outcomes it has
/// resolved, and what each day paid. `shared_preferences`, like the rest of
/// the app's local state.
///
/// "Cache a day's price data locally rather than re-querying repeatedly"
/// (CLAUDE.md) — the strike and the outcome are stored once fetched, so a
/// day is only ever resolved against the exchange once.
class PivotStore {
  const PivotStore(this._prefs);

  static const String _votesKey = 'mn.pivot.votes.v1';
  static const String _outcomesKey = 'mn.pivot.outcomes.v1';
  static const String _awardsKey = 'mn.pivot.awards.v1';
  static const String _strikesKey = 'mn.pivot.strikes.v1';
  static const String _seenKey = 'mn.pivot.seen.v1';

  final SharedPreferences _prefs;

  Map<String, dynamic> _map(String key) {
    final String? raw = _prefs.getString(key);
    if (raw == null) return <String, dynamic>{};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on Object {
      return <String, dynamic>{};
    }
  }

  Future<void> _put(String key, String day, Object value) {
    final Map<String, dynamic> all = _map(key)..[day] = value;
    return _prefs.setString(key, jsonEncode(all));
  }

  PivotVote? vote(String day) {
    final Object? v = _map(_votesKey)[day];
    return v == null ? null : PivotVote.fromJson(v as Map<String, dynamic>);
  }

  Future<void> saveVote(PivotVote vote) =>
      _put(_votesKey, vote.dayKey, vote.toJson());

  /// The first day this device voted, for the "DAY n" counter.
  String? get firstVoteDay {
    final List<String> days = _map(_votesKey).keys.toList()..sort();
    return days.isEmpty ? null : days.first;
  }

  PivotOutcome? outcome(String day) {
    final Object? v = _map(_outcomesKey)[day];
    return v == null ? null : PivotOutcome.fromJson(v as Map<String, dynamic>);
  }

  Future<void> saveOutcome(PivotOutcome outcome) =>
      _put(_outcomesKey, outcome.dayKey, outcome.toJson());

  double? strike(String day) => (_map(_strikesKey)[day] as num?)?.toDouble();

  Future<void> saveStrike(String day, double strike) =>
      _put(_strikesKey, day, strike);

  PivotAward? award(String day) {
    final Map<String, dynamic>? v =
        _map(_awardsKey)[day] as Map<String, dynamic>?;
    if (v == null) return null;
    return PivotAward(
      base: v['base'] as int,
      contrarianBonus: v['bonus'] as int,
      multiplier: (v['mult'] as num).toDouble(),
    );
  }

  Future<void> saveAward(String day, PivotAward award) =>
      _put(_awardsKey, day, <String, dynamic>{
        'base': award.base,
        'bonus': award.contrarianBonus,
        'mult': award.multiplier,
      });

  /// Days this device voted on and has since resolved — right or wrong,
  /// both count as taking part.
  Set<String> get resolvedDays => _map(_awardsKey).keys.toSet();

  bool outcomeSeen(String day) => _map(_seenKey).containsKey(day);

  Future<void> markOutcomeSeen(String day) => _put(_seenKey, day, true);
}

final Provider<PivotStore> pivotStoreProvider = Provider<PivotStore>(
  (Ref ref) => PivotStore(ref.watch(sharedPreferencesProvider)),
);
