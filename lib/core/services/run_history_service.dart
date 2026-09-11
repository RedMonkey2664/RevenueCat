import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'progress_service.dart' show sharedPreferencesProvider;

/// One behavioural sample from a run: a moment where the player's nerve was
/// tested, and what they did with it.
///
/// Everything here is *measured from the run* — the drawdown is read off the
/// level's own candles at the moment of the decision, the time is the time
/// the player actually took. Nothing is inferred about players in general.
@immutable
class DecisionSample {
  const DecisionSample({
    required this.action,
    required this.drawdown,
    required this.crashSpeed,
    required this.credit,
    this.seconds,
  });

  factory DecisionSample.fromJson(Map<String, dynamic> json) {
    return DecisionSample(
      action: json['a'] as String,
      drawdown: (json['dd'] as num).toDouble(),
      crashSpeed: (json['cs'] as num).toDouble(),
      credit: (json['cr'] as num).toDouble(),
      seconds: (json['s'] as num?)?.toDouble(),
    );
  }

  /// Beginner: `hold`, `sell` or `buy_dip`. Advanced: `hold`, `trim` (sold
  /// into the fall) or `add` (bought into it).
  final String action;

  /// Fall from the running peak at that moment, 0..1.
  final double drawdown;

  /// How fast the fall came: drawdown per trading day since the peak.
  final double crashSpeed;

  /// Discipline credit the moment earned, 0..1.
  final double credit;

  /// Seconds spent on the halted tape. Beginner mode only.
  final double? seconds;

  bool get isSell => action == 'sell' || action == 'trim';

  bool get isBuy => action == 'buy_dip' || action == 'add';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'a': action,
    'dd': drawdown,
    'cs': crashSpeed,
    'cr': credit,
    if (seconds != null) 's': seconds,
  };
}

/// One finished run, as the Nerve Profile reads it.
@immutable
class RunRecord {
  const RunRecord({
    required this.levelId,
    required this.title,
    required this.mode,
    required this.score,
    required this.playedAt,
    required this.samples,
  });

  factory RunRecord.fromJson(Map<String, dynamic> json) {
    return RunRecord(
      levelId: json['id'] as String,
      title: json['title'] as String,
      mode: json['mode'] as String,
      score: json['score'] as int?,
      playedAt: DateTime.parse(json['at'] as String),
      samples: <DecisionSample>[
        for (final dynamic s in json['samples'] as List<dynamic>)
          DecisionSample.fromJson(s as Map<String, dynamic>),
      ],
    );
  }

  final String levelId;

  /// A short, *revealed* name — the run is over, so blind mode no longer
  /// applies. e.g. "The Dot-Com Crash".
  final String title;

  final String mode;

  /// Null when nothing in the run was gradeable.
  final int? score;
  final DateTime playedAt;
  final List<DecisionSample> samples;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': levelId,
    'title': title,
    'mode': mode,
    'score': score,
    'at': playedAt.toIso8601String(),
    'samples': <Map<String, dynamic>>[
      for (final DecisionSample s in samples) s.toJson(),
    ],
  };
}

/// Stores finished runs locally, oldest first. Same storage rule as
/// [ProgressService]: `shared_preferences`, no backend, no account.
class RunHistoryService {
  const RunHistoryService(this._prefs);

  static const String _key = 'mn.run_history.v1';

  /// Enough history for a stable profile; old runs age out rather than the
  /// store growing without bound.
  static const int maxRuns = 200;

  final SharedPreferences _prefs;

  List<RunRecord> load() {
    final String? raw = _prefs.getString(_key);
    if (raw == null) return const <RunRecord>[];
    try {
      return List<RunRecord>.unmodifiable(<RunRecord>[
        for (final dynamic r in jsonDecode(raw) as List<dynamic>)
          RunRecord.fromJson(r as Map<String, dynamic>),
      ]);
    } on Object catch (error) {
      // Corrupt local data must never block play: start clean instead.
      debugPrint('Run history unreadable, starting fresh: $error');
      return const <RunRecord>[];
    }
  }

  Future<void> save(List<RunRecord> runs) => _prefs.setString(
    _key,
    jsonEncode(<Map<String, dynamic>>[
      for (final RunRecord r in runs) r.toJson(),
    ]),
  );
}

final Provider<RunHistoryService> runHistoryServiceProvider =
    Provider<RunHistoryService>(
      (Ref ref) => RunHistoryService(ref.watch(sharedPreferencesProvider)),
    );

final NotifierProvider<RunHistoryNotifier, List<RunRecord>> runHistoryProvider =
    NotifierProvider<RunHistoryNotifier, List<RunRecord>>(
      RunHistoryNotifier.new,
    );

class RunHistoryNotifier extends Notifier<List<RunRecord>> {
  @override
  List<RunRecord> build() => ref.watch(runHistoryServiceProvider).load();

  Future<void> add(RunRecord run) async {
    final List<RunRecord> next = <RunRecord>[...state, run];
    state = List<RunRecord>.unmodifiable(
      next.length > RunHistoryService.maxRuns
          ? next.sublist(next.length - RunHistoryService.maxRuns)
          : next,
    );
    await ref.read(runHistoryServiceProvider).save(state);
  }
}
