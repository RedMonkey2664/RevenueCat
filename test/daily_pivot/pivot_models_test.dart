import 'package:flutter_test/flutter_test.dart';
import 'package:market_nerve/features/daily_pivot/model/pivot_models.dart';

void main() {
  group('PivotClock', () {
    test('keys days by the IST calendar, whatever the UTC date', () {
      // 20:00 UTC on 6 Sep is 01:30 IST on 7 Sep.
      expect(PivotClock.dayKey(DateTime.utc(2026, 9, 6, 20)), '2026-09-07');
      expect(PivotClock.dayKey(DateTime.utc(2026, 9, 7, 10)), '2026-09-07');
    });

    test('opens at 09:00 IST and closes at 17:00 IST', () {
      expect(PivotClock.openUtc('2026-09-07'), DateTime.utc(2026, 9, 7, 3, 30));
      expect(
        PivotClock.closeUtc('2026-09-07'),
        DateTime.utc(2026, 9, 7, 11, 30),
      );
      expect(PivotClock.previousDay('2026-09-01'), '2026-08-31');
    });

    test('windows turn over at exactly the two instants', () {
      expect(
        PivotWindow.at(DateTime.utc(2026, 9, 7, 3, 29, 59)),
        PivotWindow.beforeOpen,
      );
      expect(PivotWindow.at(DateTime.utc(2026, 9, 7, 3, 30)), PivotWindow.open);
      expect(
        PivotWindow.at(DateTime.utc(2026, 9, 7, 11, 29, 59)),
        PivotWindow.open,
      );
      expect(
        PivotWindow.at(DateTime.utc(2026, 9, 7, 11, 30)),
        PivotWindow.closed,
      );
    });
  });

  group('PivotScoring', () {
    test('a wrong call earns nothing and costs nothing', () {
      final PivotAward a = PivotScoring.award(
        correct: false,
        contrarian: true,
        streak: 9,
      );
      expect(a.total, 0);
    });

    test('a right call earns the base', () {
      final PivotAward a = PivotScoring.award(
        correct: true,
        contrarian: false,
        streak: 1,
      );
      expect(a.base, 10);
      expect(a.contrarianBonus, 0);
      expect(a.total, 10);
    });

    test('a right call against the crowd pays 2.4x', () {
      final PivotAward a = PivotScoring.award(
        correct: true,
        contrarian: true,
        streak: 1,
      );
      expect(a.total, 24);
    });

    test('the streak multiplier applies from day 7', () {
      expect(
        PivotScoring.award(correct: true, contrarian: false, streak: 6).total,
        10,
      );
      expect(
        PivotScoring.award(correct: true, contrarian: false, streak: 7).total,
        15,
      );
    });

    test('a streak counts back only through consecutive days', () {
      const Set<String> days = <String>{
        '2026-09-07',
        '2026-09-06',
        '2026-09-05',
        '2026-09-03',
      };
      expect(PivotScoring.streakEndingOn('2026-09-07', days), 3);
      expect(PivotScoring.streakEndingOn('2026-09-04', days), 0);
    });
  });

  group('PivotTally', () {
    test('a local, one-device tally is never readable as a crowd', () {
      const PivotTally mine = PivotTally(
        yes: 1,
        no: 0,
        source: 'THIS DEVICE',
        isAggregate: false,
      );
      expect(mine.isReadable, isFalse);
      expect(mine.majority, isNull);
    });

    test('an aggregate is readable only above the minimum sample', () {
      const PivotTally small = PivotTally(
        yes: 30,
        no: 11,
        source: 'SERVER',
        isAggregate: true,
      );
      const PivotTally big = PivotTally(
        yes: 819,
        no: 385,
        source: 'SERVER',
        isAggregate: true,
      );
      expect(small.isReadable, isFalse);
      expect(big.isReadable, isTrue);
      expect(big.majority, PivotChoice.yes);
      expect((big.yesShare * 100).round(), 68);
    });
  });

  test('an outcome resolves YES only strictly above the strike', () {
    expect(
      const PivotOutcome(dayKey: 'd', strike: 100, close: 100.01).winner,
      PivotChoice.yes,
    );
    expect(
      const PivotOutcome(dayKey: 'd', strike: 100, close: 100).winner,
      PivotChoice.no,
    );
  });
}
