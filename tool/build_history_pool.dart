// Builds an Endless-mode history pool from Binance's public daily candles.
//
//   dart run tool/build_history_pool.dart crypto
//
// LEVELS.md asks for one long-run pool per market (~20 years), reused for
// every generated window. Only the crypto pool is buildable today: the US and
// India equity pools need the same per-market licence clearance as the
// campaign levels, and no index source here permits bundling.
//
// Honest limit: BTC/USDT on Binance begins 2017-08-17, so the crypto pool is
// roughly eight years, not twenty. That is the whole series that exists on
// this source — the shortfall is recorded in the file rather than padded.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class _Pool {
  const _Pool({
    required this.market,
    required this.symbol,
    required this.assetName,
    required this.from,
  });

  final String market;
  final String symbol;
  final String assetName;
  final DateTime from;
}

final Map<String, _Pool> _pools = <String, _Pool>{
  'crypto': _Pool(
    market: 'crypto',
    symbol: 'BTCUSDT',
    assetName: 'Bitcoin (BTC/USDT, Binance daily close)',
    // The first daily candle Binance publishes for this pair.
    from: DateTime.utc(2017, 8, 17),
  ),
};

Future<List<List<dynamic>>> _fetch(String symbol, DateTime from) async {
  final List<List<dynamic>> rows = <List<dynamic>>[];
  int cursor = from.millisecondsSinceEpoch;
  final int end = DateTime.now().toUtc().millisecondsSinceEpoch;

  while (cursor <= end) {
    final Uri uri = Uri.https(
      'data-api.binance.vision',
      '/api/v3/klines',
      <String, String>{
        'symbol': symbol,
        'interval': '1d',
        'startTime': cursor.toString(),
        'limit': '1000',
      },
    );
    final http.Response res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Binance ${res.statusCode}: ${res.body}');
    }
    final List<dynamic> page = jsonDecode(res.body) as List<dynamic>;
    if (page.isEmpty) break;

    for (final dynamic r in page) {
      rows.add(r as List<dynamic>);
    }
    final int last = page.last[0] as int;
    if (last <= cursor) break;
    cursor = last + const Duration(days: 1).inMilliseconds;
  }
  return rows;
}

double _r(String v) => double.parse(double.parse(v).toStringAsFixed(2));

Future<void> main(List<String> args) async {
  if (args.isEmpty || !_pools.containsKey(args.first)) {
    stderr.writeln('usage: dart run tool/build_history_pool.dart <market>');
    stderr.writeln('known: ${_pools.keys.join(', ')}');
    exitCode = 64;
    return;
  }

  final _Pool p = _pools[args.first]!;
  stdout.writeln('Fetching ${p.symbol} from ${p.from.toIso8601String()} ...');

  final List<List<dynamic>> rows = await _fetch(p.symbol, p.from);
  final List<Map<String, dynamic>> candles = <Map<String, dynamic>>[
    for (final List<dynamic> k in rows)
      <String, dynamic>{
        'date': DateTime.fromMillisecondsSinceEpoch(k[0] as int, isUtc: true)
            .toIso8601String()
            .split('T')
            .first,
        'open': _r(k[1] as String),
        'high': _r(k[2] as String),
        'low': _r(k[3] as String),
        'close': _r(k[4] as String),
      },
  ];

  final double years = candles.length / 365.0;
  final Map<String, dynamic> pool = <String, dynamic>{
    'asset_class': p.market,
    'real_asset_name': p.assetName,
    'source': 'Binance public market data (data-api.binance.vision), '
        '${p.symbol} 1d klines',
    'generated_by': 'tool/build_history_pool.dart',
    'coverage_note': 'LEVELS.md asks for ~20 years. ${p.symbol} on this '
        'source begins ${p.from.toIso8601String().split('T').first}, giving '
        '${years.toStringAsFixed(1)} years. This is the full series '
        'available; it has not been padded or extrapolated.',
    'candles': candles,
  };

  final Directory dir = Directory('data/simulator_endless');
  if (!dir.existsSync()) dir.createSync(recursive: true);

  const JsonEncoder enc = JsonEncoder.withIndent('  ');
  final File out = File('${dir.path}/history_pool_${p.market}.json');
  out.writeAsStringSync(enc.convert(pool));

  stdout
    ..writeln('  candles ${candles.length} '
        '(${candles.first['date']} -> ${candles.last['date']})')
    ..writeln('  ~${years.toStringAsFixed(1)} years')
    ..writeln('  wrote ${out.path} '
        '(${(out.lengthSync() / 1024).toStringAsFixed(0)} KB)');
}
