import 'package:flutter_test/flutter_test.dart';
import 'package:histox/features/daily_pivot/model/pivot_models.dart';

/// The Pivot resolves real money-shaped questions against a fixed instant, so
/// the clock is the one place a quiet bug would corrupt every result: a
/// half-hour slip picks a different Binance bar and can flip Yes to No.
///
/// IST is UTC+5:30 and has never observed daylight saving, so a constant
/// offset is correct here — these tests pin the arithmetic that depends on it.
void main() {
  group('the IST instants map to the right UTC bars', () {
    test('09:00 IST is 03:30 UTC on the same date', () {
      expect(
        PivotClock.openUtc('2026-09-26'),
        DateTime.utc(2026, 9, 26, 3, 30),
      );
    });

    test('17:00 IST is 11:30 UTC on the same date', () {
      expect(
        PivotClock.closeUtc('2026-09-26'),
        DateTime.utc(2026, 9, 26, 11, 30),
      );
    });

    test('the resolution bar is the last full minute before the cutoff', () {
      // PivotPriceService reads the 16:59 IST bar's close, so the instant it
      // asks for must be exactly one minute before 17:00 IST.
      final DateTime lastMinute = PivotClock.closeUtc(
        '2026-09-26',
      ).subtract(const Duration(minutes: 1));
      expect(lastMinute, DateTime.utc(2026, 9, 26, 11, 29));
    });
  });

  group('the IST day rolls at 18:30 UTC', () {
    test('a minute before midnight IST is still the old day', () {
      expect(PivotClock.dayKey(DateTime.utc(2026, 9, 26, 18, 29)), '2026-09-26');
    });

    test('a minute after midnight IST is the new day', () {
      expect(PivotClock.dayKey(DateTime.utc(2026, 9, 26, 18, 31)), '2026-09-27');
    });

    test('the device timezone cannot change the day', () {
      // The same instant, expressed in whatever zone the phone is set to.
      final DateTime instant = DateTime.utc(2026, 9, 26, 18, 31);
      expect(PivotClock.dayKey(instant.toLocal()), '2026-09-27');
      expect(PivotClock.dayKey(instant), '2026-09-27');
    });
  });

  group('day arithmetic survives the awkward boundaries', () {
    test('the previous day crosses a month end', () {
      expect(PivotClock.previousDay('2026-10-01'), '2026-09-30');
    });

    test('the previous day crosses a year end', () {
      expect(PivotClock.previousDay('2027-01-01'), '2026-12-31');
    });

    test('the previous day handles a leap day', () {
      expect(PivotClock.previousDay('2028-03-01'), '2028-02-29');
    });
  });

  test('the clock reads back in IST, not in device time', () {
    // 03:30 UTC is 09:00 IST.
    expect(PivotClock.istClock(DateTime.utc(2026, 9, 26, 3, 30)), '09:00');
    expect(PivotClock.istClock(DateTime.utc(2026, 9, 26, 11, 29)), '16:59');
  });
}
