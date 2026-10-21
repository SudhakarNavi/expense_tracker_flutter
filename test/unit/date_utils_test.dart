import 'package:expense_tracker/utils/date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('month ranges are half-open and handle month/year rollover', () {
    final dec = DateRange.month(2025, 12);
    expect(dec.start, DateTime(2025, 12, 1));
    expect(dec.end, DateTime(2026, 1, 1));
    expect(dec.contains(DateTime(2025, 12, 31, 23, 59, 59)), isTrue);
    expect(dec.contains(DateTime(2026, 1, 1)), isFalse);
    expect(dec.contains(DateTime(2025, 11, 30, 23, 59)), isFalse);
    expect(dec.lastDay, DateTime(2025, 12, 31));

    // Month arithmetic below 1 rolls back into the previous year.
    expect(DateRange.month(2026, 0).start, DateTime(2025, 12, 1));
  });

  test('leap years', () {
    expect(DateRange.month(2024, 2).lastDay, DateTime(2024, 2, 29));
    expect(DateRange.month(2025, 2).lastDay, DateTime(2025, 2, 28));
    expect(DateRange.month(2000, 2).lastDay, DateTime(2000, 2, 29));
    expect(DateRange.month(2100, 2).lastDay, DateTime(2100, 2, 28));
  });

  test('day ranges are inclusive of the whole last day', () {
    final r = DateRange.days(DateTime(2026, 3, 5, 14), DateTime(2026, 3, 7, 8));
    expect(r.start, DateTime(2026, 3, 5));
    expect(r.contains(DateTime(2026, 3, 7, 23, 59)), isTrue);
    expect(r.contains(DateTime(2026, 3, 8)), isFalse);
  });

  test('year range', () {
    final y = DateRange.year(2026);
    expect(y.contains(DateTime(2026, 12, 31, 23, 59)), isTrue);
    expect(y.contains(DateTime(2027, 1, 1)), isFalse);
  });

  test('formatting', () {
    expect(formatDate(DateTime(2026, 10, 21)), '21 Oct 2026');
    expect(formatMonthYear(DateTime(2026, 2, 3)), 'February 2026');
    final now = DateTime(2026, 10, 21, 10);
    expect(formatDayHeader(DateTime(2026, 10, 21, 23), now: now), 'Today');
    expect(formatDayHeader(DateTime(2026, 10, 20, 1), now: now), 'Yesterday');
    expect(formatDayHeader(DateTime(2026, 10, 19), now: now), 'Mon, 19 Oct');
    expect(
      formatDayHeader(DateTime(2025, 10, 19), now: now),
      'Sun, 19 Oct 2025',
    );
    // Yesterday across a month boundary.
    expect(
      formatDayHeader(DateTime(2026, 2, 28), now: DateTime(2026, 3, 1)),
      'Yesterday',
    );
    expect(formatRange(DateRange.month(2026, 10)), 'October 2026');
    expect(formatRange(DateRange.year(2026)), '2026');
    expect(
      formatRange(DateRange.days(DateTime(2026, 1, 5), DateTime(2026, 1, 9))),
      '5 Jan 2026 – 9 Jan 2026',
    );
  });
}
