/// Calendar helpers. All dates are local calendar dates; ranges are half-open
/// `[start, end)` so month and year boundaries never double count.

const List<String> monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

const List<String> _weekdays = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

String shortMonth(int month) => monthNames[month - 1].substring(0, 3);

class DateRange {
  final DateTime start;
  final DateTime end; // exclusive

  const DateRange(this.start, this.end);

  factory DateRange.month(int year, int month) =>
      DateRange(DateTime(year, month, 1), DateTime(year, month + 1, 1));

  factory DateRange.year(int year) =>
      DateRange(DateTime(year, 1, 1), DateTime(year + 1, 1, 1));

  /// Inclusive calendar days [first]..[last].
  factory DateRange.days(DateTime first, DateTime last) => DateRange(
    DateTime(first.year, first.month, first.day),
    DateTime(last.year, last.month, last.day + 1),
  );

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);

  /// Last day included in the range.
  DateTime get lastDay => DateTime(end.year, end.month, end.day - 1);

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// "21 Oct 2026"
String formatDate(DateTime d) => '${d.day} ${shortMonth(d.month)} ${d.year}';

/// "October 2026"
String formatMonthYear(DateTime d) => '${monthNames[d.month - 1]} ${d.year}';

/// "Today", "Yesterday", "Mon, 19 Oct", or "Mon, 19 Oct 2025" for other years.
String formatDayHeader(DateTime d, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  final day = dateOnly(d);
  if (day == today) return 'Today';
  if (day == DateTime(today.year, today.month, today.day - 1)) {
    return 'Yesterday';
  }
  final base = '${_weekdays[d.weekday - 1]}, ${d.day} ${shortMonth(d.month)}';
  return d.year == today.year ? base : '$base ${d.year}';
}

String formatRange(DateRange r) {
  final last = r.lastDay;
  if (r.start.day == 1 &&
      r.end == DateTime(r.start.year, r.start.month + 1, 1)) {
    return formatMonthYear(r.start);
  }
  if (r.start == DateTime(r.start.year, 1, 1) &&
      r.end == DateTime(r.start.year + 1, 1, 1)) {
    return '${r.start.year}';
  }
  return '${formatDate(r.start)} – ${formatDate(last)}';
}
