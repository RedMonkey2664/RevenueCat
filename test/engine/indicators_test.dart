import 'package:flutter_test/flutter_test.dart';
import 'package:market_nerve/features/simulator/engine/indicators.dart';

void main() {
  group('simpleMovingAverage', () {
    test('is null until the window is full, then averages it', () {
      final List<double?> out =
          simpleMovingAverage(<double>[1, 2, 3, 4, 5], 3);

      expect(out[0], isNull);
      expect(out[1], isNull);
      expect(out[2], closeTo(2, 1e-9)); // (1+2+3)/3
      expect(out[3], closeTo(3, 1e-9)); // (2+3+4)/3
      expect(out[4], closeTo(4, 1e-9)); // (3+4+5)/3
    });

    test('a flat series averages to itself', () {
      final List<double?> out =
          simpleMovingAverage(List<double>.filled(30, 42), 20);
      expect(out[19], closeTo(42, 1e-9));
      expect(out.last, closeTo(42, 1e-9));
    });

    test('rejects a non-positive period rather than dividing by zero', () {
      expect(() => simpleMovingAverage(<double>[1, 2], 0), throwsArgumentError);
    });
  });

  group('relativeStrengthIndex', () {
    test('a series that only rises pins at 100', () {
      final List<double> closes =
          List<double>.generate(40, (int i) => 100 + i.toDouble());
      final List<double?> out = relativeStrengthIndex(closes, 14);

      expect(out[14], closeTo(100, 1e-9));
      expect(out.last, closeTo(100, 1e-9));
    });

    test('a series that only falls pins at 0', () {
      final List<double> closes =
          List<double>.generate(40, (int i) => 200 - i.toDouble());
      final List<double?> out = relativeStrengthIndex(closes, 14);

      expect(out[14], closeTo(0, 1e-9));
      expect(out.last, closeTo(0, 1e-9));
    });

    test('stays within 0..100 on a noisy series', () {
      final List<double> closes = <double>[];
      double price = 100;
      for (int i = 0; i < 200; i++) {
        // Deterministic zig-zag with drift; no RNG so the test cannot flake.
        price += (i % 3 == 0 ? -1.7 : 1.1) * (1 + (i % 7) / 10);
        closes.add(price);
      }

      final List<double?> out = relativeStrengthIndex(closes, 14);
      for (final double? v in out) {
        if (v == null) continue;
        expect(v, inInclusiveRange(0, 100));
      }
    });

    test('is null before enough history exists', () {
      final List<double> closes =
          List<double>.generate(20, (int i) => 100 + i.toDouble());
      final List<double?> out = relativeStrengthIndex(closes, 14);

      for (int i = 0; i < 14; i++) {
        expect(out[i], isNull, reason: 'index $i should have no RSI yet');
      }
      expect(out[14], isNotNull);
    });

    test('a series shorter than the period yields nothing at all', () {
      final List<double?> out =
          relativeStrengthIndex(<double>[1, 2, 3], 14);
      expect(out.every((double? v) => v == null), isTrue);
    });

    test('an unchanged series is neutral rather than a divide-by-zero', () {
      final List<double?> out =
          relativeStrengthIndex(List<double>.filled(40, 50), 14);
      expect(out[14], closeTo(50, 1e-9));
    });

    test('uses Wilder smoothing, not a plain rolling mean', () {
      // 14 up moves of +1, then one down move of -1. A plain rolling mean
      // would drop a gain out of the window; Wilder's decays it instead, so
      // RSI stays high rather than falling to ~93.
      final List<double> closes = <double>[
        for (int i = 0; i <= 14; i++) 100 + i.toDouble(),
        113,
      ];
      final List<double?> out = relativeStrengthIndex(closes, 14);

      final double avgGain = (14 / 14) * 13 / 14; // decayed gain
      final double avgLoss = 1 / 14;
      final double expected = 100 - 100 / (1 + avgGain / avgLoss);

      expect(out.last, closeTo(expected, 1e-9));
    });
  });
}
