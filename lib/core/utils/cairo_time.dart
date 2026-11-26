import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:assistant/core/utils/arabic_text.dart';

bool _initialized = false;

/// Loads the time-zone database once (idempotent).
void initCairoTime() {
  if (_initialized) return;
  tzdata.initializeTimeZones();
  _initialized = true;
}

tz.Location get _cairo {
  initCairoTime();
  return tz.getLocation('Africa/Cairo');
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Edit window length in days (D9).
const int editWindowDays = 10;

/// The Cairo calendar date (`YYYY-MM-DD`) of an instant.
String cairoDateIso(DateTime instant) {
  final t = tz.TZDateTime.from(instant, _cairo);
  return '${t.year.toString().padLeft(4, '0')}-${_two(t.month)}-${_two(t.day)}';
}

/// Today's Cairo date.
String todayIso([DateTime? now]) => cairoDateIso(now ?? DateTime.now());

/// Parses `YYYY-MM-DD` into a plain UTC calendar date, or null.
DateTime? parseIso(String iso) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(iso);
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  final date = DateTime.utc(y, mo, d);
  if (date.month != mo || date.day != d) return null;
  return date;
}

/// Midnight (Cairo) at the start of `date + 10 days`, as a UTC instant.
///
/// Day 0..9 after the session are editable, day 10 is locked (D9).
DateTime editableUntilFor(String dateIso, {int days = editWindowDays}) {
  final d = parseIso(dateIso)!;
  return tz.TZDateTime(_cairo, d.year, d.month, d.day + days).toUtc();
}

/// Whole Cairo calendar days between [dateIso] and today (never negative).
int daysSince(String dateIso, [DateTime? now]) {
  final d = parseIso(dateIso)!;
  final today = parseIso(todayIso(now))!;
  final diff = today.difference(d).inDays;
  return diff < 0 ? 0 : diff;
}

/// Whether an instant is still before the closing time of the window.
bool isEditable(DateTime editableUntil, [DateTime? now]) =>
    (now ?? DateTime.now()).toUtc().isBefore(editableUntil.toUtc());

/// Days left to edit a session dated [dateIso] (prototype: `10 - age`).
int editDaysLeft(String dateIso, [DateTime? now]) =>
    editWindowDays - daysSince(dateIso, now);

const List<String> _weekdays = [
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

/// Arabic weekday name for ISO weekday 1 (Monday) .. 7 (Sunday).
String weekdayName(int isoWeekday) => _weekdays[(isoWeekday - 1) % 7];

/// Arabic weekday of an ISO date.
String weekdayOfIso(String iso) => weekdayName(parseIso(iso)!.weekday);

/// `25/11/2026` from `2026-11-25`.
String formatDmy(String iso) {
  final d = parseIso(iso);
  if (d == null) return iso;
  return '${_two(d.day)}/${_two(d.month)}/${d.year}';
}

/// `25/11` from `2026-11-25`.
String formatDm(String iso) {
  final d = parseIso(iso);
  if (d == null) return iso;
  return '${_two(d.day)}/${_two(d.month)}';
}

/// Parses `d/m/yyyy` (Arabic or Latin digits, `/`, `-` or `.`) to ISO or null.
String? parseDmyInput(String input) {
  final text = normalizeDigits(input.trim());
  final m = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})$').firstMatch(text);
  if (m == null) return null;
  final d = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final y = int.parse(m.group(3)!);
  final date = DateTime.utc(y, mo, d);
  if (date.month != mo || date.day != d) return null;
  return '${y.toString().padLeft(4, '0')}-${_two(mo)}-${_two(d)}';
}

/// `6:40` style time from an instant in Cairo.
String formatClock(DateTime instant) {
  final t = tz.TZDateTime.from(instant, _cairo);
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${_two(t.minute)}';
}
