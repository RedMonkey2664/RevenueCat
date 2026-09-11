import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/progress_service.dart'
    show sharedPreferencesProvider;
import '../model/pivot_models.dart';

/// Where votes go and where the crowd split comes from.
///
/// The real backend is Firestore plus two scheduled Cloud Functions
/// (ARCHITECTURE.md, DAILY_PIVOT.md). It is not built: there is no Firebase
/// project config in this repository, and the web preview excludes Firebase
/// entirely (tool/publish_web.sh). So the app runs on [LocalPivotBackend].
abstract class PivotBackend {
  /// Shown on screen next to every count this backend produces.
  String get sourceLabel;

  Future<void> submitVote(PivotVote vote);

  Future<PivotTally> tally(String dayKey);
}

/// PLACEHOLDER — NOT THE CROWD.
///
/// CLAUDE.md: a stubbed crowd percentage must be labelled as a placeholder
/// in code and must not look finished on screen. This backend knows about
/// exactly one voter — this device — so it reports a tally of one and marks
/// it `isAggregate: false`. The screens never turn that into a percentage:
/// they show the low-vote variant ("TOO FEW VOTES YET") and name the source
/// as this device, which is the truth.
///
/// TODO(phase6): FirestorePivotBackend — vote write deduplicated by
/// anonymous UID, tally read at 17:00, per DAILY_PIVOT.md. Swapping it in is
/// a change to [pivotBackendProvider] only.
class LocalPivotBackend implements PivotBackend {
  const LocalPivotBackend(this._prefs);

  static const String _key = 'mn.pivot.local_tally.v1';

  final SharedPreferences _prefs;

  @override
  String get sourceLabel => 'THIS DEVICE · CROWD SERVER NOT CONNECTED';

  @override
  Future<void> submitVote(PivotVote vote) async {
    final Map<String, dynamic> all = _read();
    all[vote.dayKey] = vote.choice.name;
    await _prefs.setString(_key, jsonEncode(all));
  }

  @override
  Future<PivotTally> tally(String dayKey) async {
    final Object? mine = _read()[dayKey];
    return PivotTally(
      yes: mine == PivotChoice.yes.name ? 1 : 0,
      no: mine == PivotChoice.no.name ? 1 : 0,
      source: sourceLabel,
      isAggregate: false,
    );
  }

  Map<String, dynamic> _read() {
    final String? raw = _prefs.getString(_key);
    if (raw == null) return <String, dynamic>{};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on Object {
      return <String, dynamic>{};
    }
  }
}

final Provider<PivotBackend> pivotBackendProvider = Provider<PivotBackend>(
  (Ref ref) => LocalPivotBackend(ref.watch(sharedPreferencesProvider)),
);
