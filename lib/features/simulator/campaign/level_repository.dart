import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/level_model.dart';

/// Which market a level belongs to (LEVELS.md).
///
/// The engine does not care — one engine plays every level regardless
/// (ENGINE.md) — but the player-facing framing does: "International + Indian
/// + Bitcoin" is part of the pitch, so the map filters and badges on this.
///
/// It also selects which licence applies. LEVELS.md is explicit that
/// clearance is per market: a US source does not cover BSE/NSE data or a
/// crypto export.
enum AssetClass {
  usEquity('us_equity', 'International', 'INTL'),
  indiaEquity('india_equity', 'Indian', 'IND'),
  crypto('crypto', 'Bitcoin', 'BTC');

  const AssetClass(this.wireName, this.label, this.shortCode);

  final String wireName;

  /// Filter-chip label on the campaign home.
  final String label;

  /// Used in the blind-mode masked tile title, e.g. "INTL 03".
  final String shortCode;

  static AssetClass fromWire(String value) => AssetClass.values.firstWhere(
        (AssetClass a) => a.wireName == value,
        orElse: () => throw FormatException('Unknown asset_class: $value'),
      );
}

/// Whether a level's data is cleared to *ship*.
///
/// Deliberately separate from [LevelDataStatus]: a level can be fully built
/// and playable while its source still forbids redistribution. Conflating the
/// two would let an unshippable level look finished.
enum LevelLicence {
  /// Redistribution inside a published app is permitted.
  cleared,

  /// Plays fine; publishing it is not cleared.
  unverified;

  static LevelLicence fromWire(String? value) =>
      value == 'cleared' ? LevelLicence.cleared : LevelLicence.unverified;

  bool get isCleared => this == LevelLicence.cleared;
}

/// Whether a level's historical data actually exists yet.
///
/// LEVELS.md's schema has no such field; it is added because no level has a
/// licensed data source yet and the map must say so rather than offering a
/// tile that cannot load.
enum LevelDataStatus {
  /// Data and script files exist and are real.
  sourced,

  /// Waiting on a redistributable historical source for that market.
  pendingSource,

  /// A product or spec question must be answered before sourcing is worth
  /// doing — LEVELS.md's flagged/optional entries.
  needsDecision;

  static LevelDataStatus fromWire(String value) => switch (value) {
        'sourced' => LevelDataStatus.sourced,
        'needs_decision' => LevelDataStatus.needsDecision,
        _ => LevelDataStatus.pendingSource,
      };

  bool get isPlayable => this == LevelDataStatus.sourced;
}

enum LevelDifficulty {
  beginner,
  intermediate,
  advanced;

  static LevelDifficulty fromWire(String value) =>
      LevelDifficulty.values.firstWhere(
        (LevelDifficulty d) => d.name == value,
        orElse: () => LevelDifficulty.beginner,
      );

  String get label => switch (this) {
        LevelDifficulty.beginner => 'Beginner',
        LevelDifficulty.intermediate => 'Intermediate',
        LevelDifficulty.advanced => 'Advanced',
      };
}

/// One entry in `level_manifest.json`.
@immutable
class LevelManifestEntry {
  const LevelManifestEntry({
    required this.id,
    required this.order,
    required this.difficulty,
    required this.assetClass,
    required this.isFree,
    required this.dataStatus,
    required this.licence,
    required this.revealTitle,
    required this.description,
    required this.indexInMarket,
    this.isOptional = false,
    this.openQuestion,
    this.cutRank,
  });

  factory LevelManifestEntry.fromJson(
    Map<String, dynamic> json, {
    required int indexInMarket,
  }) {
    return LevelManifestEntry(
      id: json['id'] as String,
      order: json['order'] as int,
      difficulty: LevelDifficulty.fromWire(json['difficulty'] as String),
      assetClass: AssetClass.fromWire(json['asset_class'] as String),
      isFree: json['free'] as bool? ?? false,
      dataStatus: LevelDataStatus.fromWire(json['data_status'] as String),
      licence: LevelLicence.fromWire(json['licence'] as String?),
      revealTitle: json['reveal_title'] as String,
      description: json['description'] as String? ?? '',
      indexInMarket: indexInMarket,
      isOptional: json['optional'] as bool? ?? false,
      openQuestion: json['open_question'] as String?,
      cutRank: json['cut_rank'] as int?,
    );
  }

  final String id;

  /// Global position across all markets.
  final int order;

  /// 1-based position within this level's own market, which is what the
  /// masked tile shows — "IND 04" reads better than a global "Level 14"
  /// when the map is filtered to one market.
  final int indexInMarket;

  final LevelDifficulty difficulty;
  final AssetClass assetClass;

  /// Free tier per MONETIZATION.md. The entitlement check itself lands in
  /// Phase 8; the repository only exposes the flag.
  final bool isFree;

  final LevelDataStatus dataStatus;

  /// Whether this level's source permits shipping it.
  final LevelLicence licence;

  /// The real event name. Shown ONLY once the level has been cleared —
  /// naming it on the map would defeat blind mode (ENGINE.md §3).
  final String revealTitle;

  /// A few sentences on what the event actually was. Same blind-mode rule as
  /// [revealTitle]: Debrief and cleared tiles only.
  final String description;

  /// LEVELS.md's "flag rather than default in" entries (GameStop, the India
  /// reserve slot). They are not part of the headline 20.
  final bool isOptional;

  /// What must be decided or sourced before this level can be built.
  final String? openQuestion;

  /// LEVELS.md's per-market cut order — 1 is cut first. Null means "do not
  /// cut this one before the ranked ones".
  final int? cutRank;

  /// What the map shows before the level has been cleared.
  String get maskedTitle =>
      '${assetClass.shortCode} ${indexInMarket.toString().padLeft(2, '0')}';
}

/// Loads campaign levels from bundled assets.
///
/// Everything here is local and offline by design (ARCHITECTURE.md): blind
/// mode has to work with no network.
class LevelRepository {
  const LevelRepository({AssetBundle? bundle}) : _bundle = bundle;

  static const String manifestPath =
      'data/simulator_levels/level_manifest.json';

  final AssetBundle? _bundle;

  AssetBundle get _assets => _bundle ?? rootBundle;

  Future<List<LevelManifestEntry>> loadManifest() async {
    final String raw = await _assets.loadString(manifestPath);
    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;

    final List<Map<String, dynamic>> rows =
        (json['levels'] as List<dynamic>).cast<Map<String, dynamic>>().toList()
          ..sort(
            (Map<String, dynamic> a, Map<String, dynamic> b) =>
                (a['order'] as int).compareTo(b['order'] as int),
          );

    // Per-market numbering is derived, not stored, so reordering a market in
    // the manifest cannot leave stale indices behind.
    final Map<String, int> seen = <String, int>{};
    final List<LevelManifestEntry> entries = <LevelManifestEntry>[];
    for (final Map<String, dynamic> row in rows) {
      final String market = row['asset_class'] as String;
      final int next = (seen[market] ?? 0) + 1;
      seen[market] = next;
      entries.add(LevelManifestEntry.fromJson(row, indexInMarket: next));
    }

    return List<LevelManifestEntry>.unmodifiable(entries);
  }

  /// Loads a level's data and script.
  ///
  /// Throws [StateError] for a level whose data has not been sourced. The map
  /// never offers those tiles, so reaching here means a genuine bug — better
  /// loud than a level that silently plays with no candles.
  Future<SimulationLevel> loadLevel(LevelManifestEntry entry) async {
    if (!entry.dataStatus.isPlayable) {
      throw StateError(
        'Level ${entry.id} has no sourced data (${entry.dataStatus.name}). '
        'See LEVELS.md — ${entry.assetClass.label} market data must be '
        'licensed before this level can ship.',
      );
    }

    final String levelRaw = await _assets.loadString(
      'data/simulator_levels/${entry.id}.json',
    );
    final String scriptRaw = await _assets.loadString(
      'data/simulator_levels/${entry.id}_script.json',
    );

    return SimulationLevel.fromJson(
      levelJson: jsonDecode(levelRaw) as Map<String, dynamic>,
      scriptJson: jsonDecode(scriptRaw) as Map<String, dynamic>,
      description: entry.description,
    );
  }
}

final Provider<LevelRepository> levelRepositoryProvider =
    Provider<LevelRepository>((Ref ref) => const LevelRepository());

final FutureProvider<List<LevelManifestEntry>> levelManifestProvider =
    FutureProvider<List<LevelManifestEntry>>(
  (Ref ref) => ref.watch(levelRepositoryProvider).loadManifest(),
);
