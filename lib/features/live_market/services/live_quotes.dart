import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/market/instrument.dart';
import '../../../core/market/market_data_service.dart';
import 'watchlist_service.dart';

/// Polled quotes for everything on the watchlist.
///
/// Polling rather than a websocket: the public sources here are REST-only,
/// and a socket would only pay off with the broker feed, which is not wired
/// yet. [MarketDataService] caches and de-duplicates underneath, so a poll
/// that finds nothing stale costs no network traffic.
class LiveQuotes extends Notifier<LiveQuotesState> {
  Timer? _timer;
  bool _polling = false;

  /// Fast enough to feel live, slow enough to stay well inside the free
  /// rate limits with a 30-symbol watchlist.
  static const Duration interval = Duration(seconds: 15);

  @override
  LiveQuotesState build() {
    ref.onDispose(() => _timer?.cancel());
    // Re-fetch whenever the watchlist itself changes.
    ref.listen<List<Instrument>>(
      watchlistProvider,
      (List<Instrument>? _, List<Instrument> next) => refresh(),
    );

    scheduleMicrotask(refresh);
    return const LiveQuotesState();
  }

  /// Starts or stops the timer.
  ///
  /// Driven by the screen's lifecycle so a backgrounded app is not quietly
  /// polling a market API every 15 seconds on someone's mobile data.
  void setPolling(bool on) {
    if (on == _polling) return;
    _polling = on;
    _timer?.cancel();
    if (on) {
      _timer = Timer.periodic(interval, (_) => refresh());
      refresh();
    }
  }

  Future<void> refresh({bool force = false}) async {
    final List<Instrument> instruments = ref.read(watchlistProvider);
    if (instruments.isEmpty) {
      state = const LiveQuotesState(loading: false);
      return;
    }

    state = state.copyWith(loading: true);
    try {
      final Map<String, Quote> quotes = await ref
          .read(marketDataServiceProvider)
          .quotesFor(instruments, force: force);

      state = LiveQuotesState(
        quotes: quotes,
        loading: false,
        updatedAt: DateTime.now(),
        // Every symbol failing is a connectivity problem worth naming; a few
        // failing is a bad symbol, and the tile shows that individually.
        error: quotes.isEmpty
            ? 'Could not reach the market data service.'
            : null,
      );
    } on Object catch (error) {
      debugPrint('Quote refresh failed: $error');
      state = state.copyWith(loading: false, error: error.toString());
    }
  }
}

@immutable
class LiveQuotesState {
  const LiveQuotesState({
    this.quotes = const <String, Quote>{},
    this.loading = true,
    this.updatedAt,
    this.error,
  });

  /// Keyed by [Instrument.id]. A missing entry means that one symbol failed,
  /// which the tile renders as an explicit dash rather than a stale price.
  final Map<String, Quote> quotes;

  final bool loading;
  final DateTime? updatedAt;
  final String? error;

  LiveQuotesState copyWith({
    Map<String, Quote>? quotes,
    bool? loading,
    DateTime? updatedAt,
    String? error,
  }) {
    return LiveQuotesState(
      quotes: quotes ?? this.quotes,
      loading: loading ?? this.loading,
      updatedAt: updatedAt ?? this.updatedAt,
      error: error,
    );
  }
}

final NotifierProvider<LiveQuotes, LiveQuotesState> liveQuotesProvider =
    NotifierProvider<LiveQuotes, LiveQuotesState>(LiveQuotes.new);
