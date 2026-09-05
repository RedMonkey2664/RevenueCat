import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:market_nerve/core/indicators/indicators.dart';

/// A deterministic wave, so expectations are about the maths rather than
/// about a particular random draw.
List<double> wave(int n) => <double>[
      for (int i = 0; i < n; i++) 100 + 10 * math.sin(i / 4),
    ];

void main() {
  group('exponentialMovingAverage', () {
    test('is null until the seed window is full, then never again', () {
      final List<double?> ema = exponentialMovingAverage(wave(40), 10);
      for (int i = 0; i < 9; i++) {
        expect(ema[i], isNull, reason: 'index $i precedes the seed');
      }
      expect(ema[9], isNotNull, reason: 'seeded at period - 1');
      expect(ema.skip(9).every((double? v) => v != null), isTrue);
    });

    test('seeds with the simple average of the first period', () {
      final List<double> closes = <double>[1, 2, 3, 4, 5, 6];
      final List<double?> ema = exponentialMovingAverage(closes, 3);
      expect(ema[2], closeTo(2, 1e-12), reason: '(1+2+3)/3');
    });

    test('tracks a constant series exactly', () {
      final List<double> flat = List<double>.filled(30, 42);
      final List<double?> ema = exponentialMovingAverage(flat, 10);
      expect(ema.last, closeTo(42, 1e-9));
    });

    test('reacts faster than the SMA to a step change', () {
      final List<double> closes = <double>[
        ...List<double>.filled(20, 100),
        ...List<double>.filled(5, 200),
      ];
      final double ema = exponentialMovingAverage(closes, 10).last!;
      final double sma = simpleMovingAverage(closes, 10).last!;
      expect(ema, greaterThan(sma));
    });

    test('returns all nulls when there is not enough data', () {
      expect(
        exponentialMovingAverage(<double>[1, 2], 10).every((double? v) => v == null),
        isTrue,
      );
    });

    test('rejects a non-positive period', () {
      expect(() => exponentialMovingAverage(wave(10), 0), throwsArgumentError);
    });
  });

  group('bollingerBands', () {
    test('the middle band is the SMA', () {
      final List<double> closes = wave(40);
      final BollingerBands bb = bollingerBands(closes, 20);
      final List<double?> sma = simpleMovingAverage(closes, 20);
      for (int i = 0; i < closes.length; i++) {
        expect(bb.middle[i], sma[i]);
      }
    });

    test('upper is above lower, symmetric about the middle', () {
      final BollingerBands bb = bollingerBands(wave(40), 20);
      for (int i = 19; i < 40; i++) {
        expect(bb.upper[i]!, greaterThan(bb.lower[i]!));
        expect(
          bb.upper[i]! - bb.middle[i]!,
          closeTo(bb.middle[i]! - bb.lower[i]!, 1e-9),
        );
      }
    });

    test('a flat series collapses the bands onto the middle', () {
      final BollingerBands bb =
          bollingerBands(List<double>.filled(30, 7), 20);
      expect(bb.upper.last, closeTo(7, 1e-9));
      expect(bb.lower.last, closeTo(7, 1e-9));
    });

    test('uses the population deviation, matching other charting tools', () {
      // Closes 1..5, SMA = 3, population sd = sqrt(2) exactly.
      final BollingerBands bb =
          bollingerBands(<double>[1, 2, 3, 4, 5], 5, stdDevs: 1);
      expect(bb.middle[4], closeTo(3, 1e-12));
      expect(bb.upper[4], closeTo(3 + math.sqrt(2), 1e-12));
    });
  });

  group('macd', () {
    test('the line is fast EMA minus slow EMA', () {
      final List<double> closes = wave(120);
      final MacdResult m = macd(closes);
      final List<double?> fast = exponentialMovingAverage(closes, 12);
      final List<double?> slow = exponentialMovingAverage(closes, 26);

      for (int i = 0; i < closes.length; i++) {
        if (fast[i] == null || slow[i] == null) {
          expect(m.macd[i], isNull);
        } else {
          expect(m.macd[i], closeTo(fast[i]! - slow[i]!, 1e-9));
        }
      }
    });

    test('histogram is line minus signal wherever both exist', () {
      final MacdResult m = macd(wave(120));
      for (int i = 0; i < 120; i++) {
        if (m.signal[i] == null) {
          expect(m.histogram[i], isNull);
        } else {
          expect(
            m.histogram[i],
            closeTo(m.macd[i]! - m.signal[i]!, 1e-9),
          );
        }
      }
    });

    test('the signal starts later than the line, never before', () {
      final MacdResult m = macd(wave(120));
      final int firstLine =
          m.macd.indexWhere((double? v) => v != null);
      final int firstSignal =
          m.signal.indexWhere((double? v) => v != null);
      expect(firstLine, greaterThanOrEqualTo(0));
      expect(firstSignal, greaterThan(firstLine));
    });

    test('a short series yields no signal rather than throwing', () {
      final MacdResult m = macd(wave(10));
      expect(m.signal.every((double? v) => v == null), isTrue);
      expect(m.histogram.every((double? v) => v == null), isTrue);
    });
  });
}
