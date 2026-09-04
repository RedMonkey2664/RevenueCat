import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_nerve/features/simulator/campaign/level_repository.dart';
import 'package:market_nerve/features/simulator/engine/level_model.dart';
import 'package:market_nerve/features/simulator/engine/script_event_model.dart';

/// A bundle serving only what a test hands it, so these tests exercise the
/// parsing rules rather than the shipped manifest's current contents.
class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final String? body = files[key];
    if (body == null) throw StateError('missing asset: $key');
    final List<int> bytes = utf8.encode(body);
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final String? body = files[key];
    if (body == null) throw StateError('missing asset: $key');
    return body;
  }
}

String _manifest(List<Map<String, dynamic>> levels) =>
    jsonEncode(<String, dynamic>{'levels': levels});

Map<String, dynamic> _level({
  required String id,
  required int order,
  required String assetClass,
  String difficulty = 'beginner',
  String dataStatus = 'pending_source',
  bool free = false,
  bool? optional,
  String? openQuestion,
  int? cutRank,
}) {
  return <String, dynamic>{
    'id': id,
    'order': order,
    'difficulty': difficulty,
    'asset_class': assetClass,
    'free': free,
    'data_status': dataStatus,
    'reveal_title': 'Reveal for $id',
    if (optional case final bool v) 'optional': v,
    if (openQuestion case final String v) 'open_question': v,
    if (cutRank case final int v) 'cut_rank': v,
  };
}

LevelRepository _repoWith(String manifestJson) => LevelRepository(
      bundle: _FakeBundle(<String, String>{
        LevelRepository.manifestPath: manifestJson,
      }),
    );

void main() {
  group('manifest parsing', () {
    test('reads the three markets LEVELS.md defines', () async {
      final LevelRepository repo = _repoWith(
        _manifest(<Map<String, dynamic>>[
          _level(id: 'a', order: 1, assetClass: 'us_equity'),
          _level(id: 'b', order: 2, assetClass: 'india_equity'),
          _level(id: 'c', order: 3, assetClass: 'crypto'),
        ]),
      );

      final List<LevelManifestEntry> entries = await repo.loadManifest();
      expect(
        entries.map((LevelManifestEntry e) => e.assetClass),
        <AssetClass>[
          AssetClass.usEquity,
          AssetClass.indiaEquity,
          AssetClass.crypto,
        ],
      );
    });

    test('rejects an unknown asset_class rather than silently defaulting',
        () async {
      final LevelRepository repo = _repoWith(
        _manifest(<Map<String, dynamic>>[
          _level(id: 'a', order: 1, assetClass: 'commodity'),
        ]),
      );

      // A typo'd market would otherwise land the level in the wrong filter
      // and under the wrong licence.
      expect(repo.loadManifest(), throwsA(isA<FormatException>()));
    });

    test('numbers levels within their own market, not globally', () async {
      final LevelRepository repo = _repoWith(
        _manifest(<Map<String, dynamic>>[
          _level(id: 'us1', order: 1, assetClass: 'us_equity'),
          _level(id: 'us2', order: 2, assetClass: 'us_equity'),
          _level(id: 'in1', order: 11, assetClass: 'india_equity'),
          _level(id: 'in2', order: 12, assetClass: 'india_equity'),
          _level(id: 'btc1', order: 20, assetClass: 'crypto'),
        ]),
      );

      final Map<String, LevelManifestEntry> byId = <String, LevelManifestEntry>{
        for (final LevelManifestEntry e in await repo.loadManifest()) e.id: e,
      };

      expect(byId['us2']!.indexInMarket, 2);
      expect(byId['in1']!.indexInMarket, 1, reason: 'India restarts at 1');
      expect(byId['in2']!.indexInMarket, 2);
      expect(byId['btc1']!.indexInMarket, 1);
    });

    test('masked titles are market-scoped and leak no event name', () async {
      final LevelRepository repo = _repoWith(
        _manifest(<Map<String, dynamic>>[
          _level(id: 'us1', order: 1, assetClass: 'us_equity'),
          _level(id: 'in1', order: 11, assetClass: 'india_equity'),
          _level(id: 'btc1', order: 20, assetClass: 'crypto'),
        ]),
      );

      final List<LevelManifestEntry> entries = await repo.loadManifest();
      expect(
        entries.map((LevelManifestEntry e) => e.maskedTitle),
        <String>['INTL 01', 'IND 01', 'BTC 01'],
      );
      for (final LevelManifestEntry e in entries) {
        expect(
          e.maskedTitle.contains(e.revealTitle),
          isFalse,
          reason: 'blind mode: the map must not name the event',
        );
      }
    });

    test('sorts by global order regardless of file order', () async {
      final LevelRepository repo = _repoWith(
        _manifest(<Map<String, dynamic>>[
          _level(id: 'c', order: 20, assetClass: 'crypto'),
          _level(id: 'a', order: 1, assetClass: 'us_equity'),
          _level(id: 'b', order: 11, assetClass: 'india_equity'),
        ]),
      );

      expect(
        (await repo.loadManifest()).map((LevelManifestEntry e) => e.id),
        <String>['a', 'b', 'c'],
      );
    });

    test('parses needs_decision, optional and cut_rank', () async {
      final LevelRepository repo = _repoWith(
        _manifest(<Map<String, dynamic>>[
          _level(
            id: 'gamestop',
            order: 10,
            assetClass: 'us_equity',
            dataStatus: 'needs_decision',
            optional: true,
            openQuestion: 'bubble, not a crash',
            cutRank: 1,
          ),
        ]),
      );

      final LevelManifestEntry e = (await repo.loadManifest()).single;
      expect(e.dataStatus, LevelDataStatus.needsDecision);
      expect(e.dataStatus.isPlayable, isFalse);
      expect(e.isOptional, isTrue);
      expect(e.openQuestion, 'bubble, not a crash');
      expect(e.cutRank, 1);
      expect(e.licence, LevelLicence.unverified);
    });
  });

  group('loadLevel', () {
    test('refuses a level whose data is not sourced, naming its market',
        () async {
      final LevelRepository repo = _repoWith(
        _manifest(<Map<String, dynamic>>[
          _level(id: 'in1', order: 11, assetClass: 'india_equity'),
        ]),
      );
      final LevelManifestEntry entry = (await repo.loadManifest()).single;

      // Loud, not a level that quietly plays with no candles.
      await expectLater(
        repo.loadLevel(entry),
        throwsA(
          isA<StateError>().having(
            (StateError e) => e.message,
            'message',
            contains('Indian'),
          ),
        ),
      );
    });
  });

  group('the shipped manifest', () {
    test('matches LEVELS.md: 20 core levels across three markets', () async {
      // Uses the real bundled asset, so a hand-edit that breaks the spec's
      // counts fails here rather than in review.
      TestWidgetsFlutterBinding.ensureInitialized();
      const LevelRepository repo = LevelRepository();
      final List<LevelManifestEntry> all = await repo.loadManifest();

      final List<LevelManifestEntry> core = all
          .where((LevelManifestEntry e) => !e.isOptional)
          .toList();

      int countOf(AssetClass m) =>
          core.where((LevelManifestEntry e) => e.assetClass == m).length;

      expect(core.length, 20, reason: 'LEVELS.md headline count');

      // Nothing may claim its data is cleared for release until a licensed
      // source replaces Yahoo/Binance. A level that plays is not a level
      // that ships, and the manifest must not blur the two.
      expect(
        all.where((LevelManifestEntry e) => e.licence.isCleared),
        isEmpty,
        reason: 'no data source is licence-cleared yet',
      );
      expect(countOf(AssetClass.usEquity), 9);
      expect(countOf(AssetClass.indiaEquity), 9);
      expect(countOf(AssetClass.crypto), 2);

      // Ids must be unique — a duplicate would collide in progress storage.
      expect(
        all.map((LevelManifestEntry e) => e.id).toSet().length,
        all.length,
      );

      // The real invariant: anything claiming to be sourced must actually
      // load, with candles and a script whose trigger dates resolve. A tile
      // that says "playable" and then throws is the worst outcome.
      final Iterable<LevelManifestEntry> sourced =
          all.where((LevelManifestEntry e) => e.dataStatus.isPlayable);
      expect(sourced, isNotEmpty, reason: 'the crypto levels are built');

      // Loaded once and reused: a second pass over 17 levels of candles was
      // the slowest thing in the suite.
      int deep = 0;
      for (final LevelManifestEntry e in sourced) {
        final SimulationLevel level = await repo.loadLevel(e);
        if (level.pausePoints.length >= 10) deep++;
        expect(level.candles.length, greaterThan(100), reason: e.id);
        // Not a flat "10+ everywhere". A mild event — a taper tantrum, a
        // demonetisation shock — contains only a handful of real decision
        // points, and manufacturing more would mean inventing moments the
        // series does not contain. The count follows the data; the deep
        // crashes carry the "usually more than 10" case, asserted below.
        expect(
          level.pausePoints.length,
          greaterThanOrEqualTo(3),
          reason: '${e.id}: too few moments to be a test of nerve',
        );
        for (final PausePoint p in level.pausePoints) {
          expect(p.triggerIndex, inInclusiveRange(0, level.candles.length - 1));
          expect(p.revealHeadline, isNotEmpty);
        }
        // Candles must be in ascending date order or the replay walks
        // backwards through time.
        for (int i = 1; i < level.candles.length; i++) {
          expect(
            level.candles[i].date.isAfter(level.candles[i - 1].date),
            isTrue,
            reason: '${e.id}: candle $i is out of order',
          );
        }
      }

      // The flagship crashes must still deliver the deep repeated test.
      expect(
        deep,
        greaterThanOrEqualTo(5),
        reason: 'the major crashes should each pose 10+ decisions',
      );

      // Every level briefs the player on what the event was...
      for (final LevelManifestEntry e in all) {
        expect(
          e.description.trim(),
          isNotEmpty,
          reason: '${e.id} has no event description',
        );
      }

      // Every market must offer at least one free level, so a free user can
      // sample all three (the three-market framing is the pitch).
      for (final AssetClass m in AssetClass.values) {
        expect(
          all.any((LevelManifestEntry e) => e.assetClass == m && e.isFree),
          isTrue,
          reason: '${m.label} has no free level',
        );
      }
    });
  });
}
