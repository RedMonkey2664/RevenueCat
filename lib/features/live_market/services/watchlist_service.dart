import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/market/instrument.dart';
import '../../../core/market/instrument_catalog.dart';
import '../../../core/services/progress_service.dart'
    show sharedPreferencesProvider;

/// The user's watchlist.
///
/// Stores the whole [Instrument] rather than just its id, because a symbol
/// found through provider search is not in the bundled catalog and would
/// otherwise vanish on the next launch.
class WatchlistService {
  const WatchlistService(this._prefs);

  static const String _key = 'watchlist_v1';

  /// A watchlist is polled on a timer; an unbounded one would hammer the
  /// providers' rate limits.
  static const int maxEntries = 30;

  final SharedPreferences _prefs;

  List<Instrument> load() {
    final String? raw = _prefs.getString(_key);
    if (raw == null) return _defaults();

    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      final List<Instrument> out = <Instrument>[
        for (final dynamic e in list)
          Instrument.fromJson(e as Map<String, dynamic>),
      ];
      // An empty saved list is a real state (the user removed everything) and
      // must not silently repopulate with defaults.
      return out;
    } on Object catch (error) {
      debugPrint('Watchlist could not be read, falling back: $error');
      return _defaults();
    }
  }

  static List<Instrument> _defaults() => <Instrument>[
        for (final String id in InstrumentCatalog.defaultWatchlistIds)
          if (InstrumentCatalog.byId(id) != null)
            InstrumentCatalog.byId(id)!,
      ];

  Future<void> save(List<Instrument> instruments) {
    return _prefs.setString(
      _key,
      jsonEncode(<Map<String, dynamic>>[
        for (final Instrument i in instruments) i.toJson(),
      ]),
    );
  }
}

final Provider<WatchlistService> watchlistServiceProvider =
    Provider<WatchlistService>(
  (Ref ref) => WatchlistService(ref.watch(sharedPreferencesProvider)),
);

final NotifierProvider<WatchlistNotifier, List<Instrument>>
    watchlistProvider =
    NotifierProvider<WatchlistNotifier, List<Instrument>>(
  WatchlistNotifier.new,
);

class WatchlistNotifier extends Notifier<List<Instrument>> {
  @override
  List<Instrument> build() => ref.watch(watchlistServiceProvider).load();

  bool contains(Instrument i) =>
      state.any((Instrument e) => e.id == i.id);

  Future<void> add(Instrument instrument) async {
    if (contains(instrument)) return;
    if (state.length >= WatchlistService.maxEntries) return;
    state = <Instrument>[...state, instrument];
    await _persist();
  }

  Future<void> remove(Instrument instrument) async {
    state = state
        .where((Instrument e) => e.id != instrument.id)
        .toList(growable: false);
    await _persist();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final List<Instrument> next = List<Instrument>.of(state);
    // ReorderableListView reports an insertion index measured before the
    // item is removed, so it has to be corrected when moving downward.
    final int target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    next.insert(target, next.removeAt(oldIndex));
    state = next;
    await _persist();
  }

  Future<void> _persist() =>
      ref.read(watchlistServiceProvider).save(state);
}
