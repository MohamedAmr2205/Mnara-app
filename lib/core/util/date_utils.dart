import 'package:assistant/core/util/text_utils.dart';

/// Arabic weekday names indexed by [DateTime.weekday] - 1 (Monday first).
const List<String> arabicWeekdays = [
  'الإثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

String _two(int v) => v.toString().padLeft(2, '0');

/// `yyyy-MM-dd` key used for storage.
String dateKey(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// Parses a `yyyy-MM-dd` key into a local date at midnight.
DateTime parseDateKey(String key) {
  final p = key.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// `dd/MM/yyyy`.
String formatDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

/// `dd/MM` (short date for session lists).
String formatDateShort(DateTime d) => '${_two(d.day)}/${_two(d.month)}';

/// `الأربعاء 25/11/2026`.
String formatDateWithDay(DateTime d) =>
    '${arabicWeekdays[d.weekday - 1]} ${formatDate(d)}';

/// `6:00 م` from a 24h [hour] and [minute].
String formatTime12(int hour, int minute) {
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  final suffix = hour < 12 ? 'ص' : 'م';
  return '$h12:${_two(minute)} $suffix';
}

/// Strips the time part.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whole calendar days from [from] to [to] (negative when [to] is earlier).
int daysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// Parses `dd/MM/yyyy` (also `-` or `.` separators, Arabic digits).
/// Returns null when the text is not a real calendar date.
DateTime? parseUserDate(String input) {
  final s = normalizeDigits(input).trim();
  final parts = s.split(RegExp(r'[/\-.]'));
  if (parts.length != 3) return null;
  final d = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final y = int.tryParse(parts[2]);
  if (d == null || m == null || y == null) return null;
  if (y < 2000 || y > 2100 || m < 1 || m > 12 || d < 1 || d > 31) return null;
  final date = DateTime(y, m, d);
  if (date.year != y || date.month != m || date.day != d) return null;
  return date;
}

/// Next date on or after [from] that falls on [weekday] (1 = Monday).
DateTime nextOccurrence(DateTime from, int weekday) {
  final d = dateOnly(from);
  final diff = (weekday - d.weekday) % 7;
  return d.add(Duration(days: diff));
}
