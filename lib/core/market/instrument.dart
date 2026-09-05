import 'package:meta/meta.dart';

/// Which market an instrument trades on.
///
/// Mirrors the Simulator's `AssetClass` deliberately rather than importing it:
/// that enum lives in a feature folder and carries campaign-specific meaning
/// (licence clearance, blind-mode short codes). This one is about live data —
/// session hours, currency and which provider to ask.
enum MarketRegion {
  usEquity('us_equity', 'US', r'$'),
  indiaEquity('india_equity', 'India', '₹'),
  crypto('crypto', 'Crypto', r'$');

  const MarketRegion(this.wireName, this.label, this.currencySymbol);

  final String wireName;
  final String label;

  /// Prefix for prices in this market. Indices have no currency, which the
  /// instrument overrides individually.
  final String currencySymbol;

  bool get isCrypto => this == MarketRegion.crypto;

  static MarketRegion fromWire(String value) => MarketRegion.values.firstWhere(
        (MarketRegion r) => r.wireName == value,
        orElse: () => MarketRegion.crypto,
      );

  /// Whether this market is open at [utcNow].
  ///
  /// Deliberately approximate: regular session only, weekends excluded, and
  /// no exchange holiday calendar. A holiday therefore reads as "open" with a
  /// stale price — which is why the quote tile shows the quote's own
  /// timestamp rather than trusting this. Getting it exactly right needs a
  /// holiday feed the app has no reason to carry.
  bool isOpenAt(DateTime utcNow) {
    switch (this) {
      case MarketRegion.crypto:
        return true;

      case MarketRegion.indiaEquity:
        // IST is UTC+5:30 year-round; India observes no DST.
        final DateTime ist = utcNow.add(const Duration(hours: 5, minutes: 30));
        if (ist.weekday > DateTime.friday) return false;
        final int mins = ist.hour * 60 + ist.minute;
        return mins >= 9 * 60 + 15 && mins <= 15 * 60 + 30;

      case MarketRegion.usEquity:
        final DateTime et =
            utcNow.subtract(Duration(hours: _usEasternOffsetHours(utcNow)));
        if (et.weekday > DateTime.friday) return false;
        final int mins = et.hour * 60 + et.minute;
        return mins >= 9 * 60 + 30 && mins <= 16 * 60;
    }
  }

  /// 4 during Eastern Daylight Time, 5 during Standard Time.
  ///
  /// US DST runs from the second Sunday in March to the first Sunday in
  /// November. Computed rather than table-driven so it does not expire.
  static int _usEasternOffsetHours(DateTime utc) {
    final int year = utc.year;

    DateTime nthSunday(int month, int n) {
      DateTime d = DateTime.utc(year, month);
      int found = 0;
      while (true) {
        if (d.weekday == DateTime.sunday) {
          found++;
          if (found == n) return d;
        }
        d = d.add(const Duration(days: 1));
      }
    }

    // Transitions happen at 2am local, i.e. 07:00 UTC either side.
    final DateTime start =
        nthSunday(3, 2).add(const Duration(hours: 7));
    final DateTime end = nthSunday(11, 1).add(const Duration(hours: 6));

    final bool isDst = !utc.isBefore(start) && utc.isBefore(end);
    return isDst ? 4 : 5;
  }
}

/// A tradeable or quotable symbol.
@immutable
class Instrument {
  const Instrument({
    required this.id,
    required this.symbol,
    required this.name,
    required this.region,
    this.displaySymbol,
    this.currencySymbolOverride,
    this.isIndex = false,
  });

  factory Instrument.fromJson(Map<String, dynamic> json) {
    return Instrument(
      id: json['id'] as String,
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      region: MarketRegion.fromWire(json['region'] as String),
      displaySymbol: json['display_symbol'] as String?,
      currencySymbolOverride: json['currency'] as String?,
      isIndex: json['is_index'] as bool? ?? false,
    );
  }

  /// Stable key for watchlists and caches. Independent of [symbol] so
  /// swapping Yahoo for Kotak later does not orphan a user's watchlist.
  final String id;

  /// The provider-native ticker, e.g. `^NSEI`, `AAPL`, `BTCUSDT`.
  final String symbol;

  final String name;
  final MarketRegion region;

  /// What the UI shows. Falls back to [symbol].
  final String? displaySymbol;

  /// Indices are unitless; a '₹' in front of "NIFTY 21,459" is wrong.
  final String? currencySymbolOverride;

  final bool isIndex;

  String get ticker => displaySymbol ?? symbol;

  String get currencySymbol =>
      currencySymbolOverride ?? (isIndex ? '' : region.currencySymbol);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'symbol': symbol,
        'name': name,
        'region': region.wireName,
        if (displaySymbol != null) 'display_symbol': displaySymbol,
        if (currencySymbolOverride != null) 'currency': currencySymbolOverride,
        if (isIndex) 'is_index': true,
      };

  @override
  bool operator ==(Object other) => other is Instrument && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Instrument($id)';
}

/// A point-in-time price.
@immutable
class Quote {
  const Quote({
    required this.instrument,
    required this.price,
    required this.previousClose,
    required this.asOf,
    required this.source,
    this.dayHigh,
    this.dayLow,
    this.dayOpen,
    this.volume,
  });

  final Instrument instrument;
  final double price;

  /// Prior session's close, the basis for the day's change. Equal to [price]
  /// when the provider gave us nothing to compare against, which renders as a
  /// flat 0.00% rather than a fabricated move.
  final double previousClose;

  /// When the *price* was current, per the provider — not when we fetched it.
  /// The two differ by minutes on a delayed feed, and the UI says which.
  final DateTime asOf;

  /// Human-readable attribution, shown in the UI. Every screen that prints a
  /// live number must be able to say where it came from.
  final String source;

  final double? dayHigh;
  final double? dayLow;
  final double? dayOpen;
  final double? volume;

  double get change => price - previousClose;

  double get changePercent =>
      previousClose == 0 ? 0 : (price / previousClose - 1) * 100;

  bool get isUp => change >= 0;

  Duration ageAt(DateTime now) => now.difference(asOf);
}
