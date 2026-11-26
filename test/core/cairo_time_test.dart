import 'package:flutter_test/flutter_test.dart';

import 'package:assistant/core/utils/cairo_time.dart';

void main() {
  setUpAll(initCairoTime);

  test('Cairo date follows UTC+2 in winter and UTC+3 in summer', () {
    expect(cairoDateIso(DateTime.utc(2026, 11, 25, 21, 30)), '2026-11-25');
    expect(cairoDateIso(DateTime.utc(2026, 11, 25, 22, 30)), '2026-11-26');
    expect(cairoDateIso(DateTime.utc(2026, 7, 1, 20, 30)), '2026-07-01');
    expect(cairoDateIso(DateTime.utc(2026, 7, 1, 21, 30)), '2026-07-02');
  });

  test('editableUntil is Cairo midnight of date + 10 days (winter and summer)', () {
    expect(editableUntilFor('2026-01-05'), DateTime.utc(2026, 1, 14, 22));
    expect(editableUntilFor('2026-07-01'), DateTime.utc(2026, 7, 10, 21));
  });

  group('edit window boundary (D9)', () {
    const date = '2026-11-01';
    final until = editableUntilFor(date);

    test('day 9 is still open, day 10 and 11 are locked', () {
      final day9 = DateTime.utc(2026, 11, 10, 10); // noon Cairo
      final day10 = DateTime.utc(2026, 11, 11, 10);
      final day11 = DateTime.utc(2026, 11, 12, 10);
      expect(isEditable(until, day9), isTrue);
      expect(isEditable(until, day10), isFalse);
      expect(isEditable(until, day11), isFalse);
    });

    test('the last second before midnight is open, midnight is locked', () {
      expect(isEditable(until, until.subtract(const Duration(seconds: 1))), isTrue);
      expect(isEditable(until, until), isFalse);
    });

    test('days left matches the prototype (10 - age)', () {
      expect(editDaysLeft(date, DateTime.utc(2026, 11, 1, 10)), 10);
      expect(editDaysLeft(date, DateTime.utc(2026, 11, 10, 10)), 1);
      expect(editDaysLeft(date, DateTime.utc(2026, 11, 11, 10)), 0);
    });
  });

  test('formatting and parsing', () {
    expect(formatDmy('2026-11-25'), '25/11/2026');
    expect(formatDm('2026-11-05'), '05/11');
    expect(weekdayOfIso('2026-11-25'), 'الأربعاء');
    expect(parseDmyInput('٢٥/١١/٢٠٢٦'), '2026-11-25');
    expect(parseDmyInput('5-1-2026'), '2026-01-05');
    expect(parseDmyInput('31/02/2026'), isNull);
    expect(parseDmyInput('abc'), isNull);
  });
}
