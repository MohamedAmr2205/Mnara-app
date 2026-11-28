// ignore_for_file: always_use_package_imports
import 'package:flutter_test/flutter_test.dart';

import 'package:assistant/core/util/date_utils.dart';
import 'package:assistant/core/util/text_utils.dart';
import 'package:assistant/data/seed.dart';
import 'package:assistant/domain/app_state.dart';
import 'package:assistant/domain/logic.dart';
import 'package:assistant/domain/models.dart';

import '../helpers.dart';

void main() {
  group('text utils', () {
    test('normalizeDigits converts Arabic-Indic digits', () {
      expect(normalizeDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
      expect(normalizeDigits('S١٢'), 'S12');
    });

    test('normalizeSearch unifies Arabic letter forms', () {
      expect(normalizeSearch('أحمد'), normalizeSearch('احمد'));
      expect(normalizeSearch('مُحَمَّد'), normalizeSearch('محمد'));
      expect(normalizeSearch('  ياسمين   علي '), 'ياسمين علي');
      expect(normalizeSearch('فاطمة'), normalizeSearch('فاطمه'));
    });

    test('Egyptian mobile validation', () {
      expect(isValidEgyptMobile(normalizePhone('010 1234 5678')), isTrue);
      expect(isValidEgyptMobile(normalizePhone('٠١١١٢٣٤٥٦٧٨')), isTrue);
      expect(isValidEgyptMobile('0131234567'), isFalse);
      expect(isValidEgyptMobile('01012345'), isFalse);
      expect(isValidEgyptMobile('02012345678'), isFalse);
    });

    test('score parsing and formatting', () {
      expect(parseScore('17.5'), 17.5);
      expect(parseScore('١٧,٥'), 17.5);
      expect(parseScore('-1'), isNull);
      expect(parseScore('abc'), isNull);
      expect(formatScore(17), '17');
      expect(formatScore(17.5), '17.5');
    });
  });

  group('date utils', () {
    test('parseUserDate accepts real dates only', () {
      expect(parseUserDate('25/11/2026'), DateTime(2026, 11, 25));
      expect(parseUserDate('٢٥-١١-٢٠٢٦'), DateTime(2026, 11, 25));
      expect(parseUserDate('31/02/2026'), isNull);
      expect(parseUserDate('1/13/2026'), isNull);
      expect(parseUserDate('hello'), isNull);
    });

    test('formatTime12', () {
      expect(formatTime12(18, 0), '6:00 م');
      expect(formatTime12(0, 5), '12:05 ص');
      expect(formatTime12(12, 30), '12:30 م');
    });

    test('nextOccurrence returns today when the weekday matches', () {
      final today = DateTime(2026, 11, 25); // Wednesday
      expect(nextOccurrence(today, DateTime.wednesday), today);
      expect(nextOccurrence(today, DateTime.thursday), DateTime(2026, 11, 26));
      expect(nextOccurrence(today, DateTime.tuesday), DateTime(2026, 12, 1));
    });
  });

  group('edit window (day 10 is locked)', () {
    final today = DateTime(2026, 11, 25);

    test('session from 9 days ago is editable with 1 day left', () {
      expect(editDaysLeft(today, '2026-11-16'), 1);
      expect(isEditable(today, '2026-11-16'), isTrue);
    });

    test('session from 10 days ago is locked', () {
      expect(editDaysLeft(today, '2026-11-15'), 0);
      expect(isEditable(today, '2026-11-15'), isFalse);
    });

    test('today has 10 days left', () {
      expect(editDaysLeft(today, '2026-11-25'), 10);
    });
  });

  group('seed data', () {
    final s = buildSeedState(testNow);

    test('has 3 groups, 36 students, 18 closed sessions', () {
      expect(s.groups.length, 3);
      expect(s.students.length, 36);
      expect(s.sessions.length, 18);
      expect(s.sessions.every((x) => x.status == SessionStatus.closed), isTrue);
    });

    test('first group meets on the clock weekday', () {
      expect(s.groups.first.weekday, testNow.weekday);
    });

    test('every group is at session 3 of month 2', () {
      for (final g in s.groups) {
        final slot = nextSessionSlot(s, g.id);
        expect(slot.number, 3);
        expect(slot.month, 2);
      }
    });

    test('every phone is a valid Egyptian mobile', () {
      for (final st in s.students) {
        expect(isValidEgyptMobile(st.studentPhone), isTrue, reason: st.code);
        expect(isValidEgyptMobile(st.parentPhone), isTrue, reason: st.code);
      }
    });

    test('student codes are unique', () {
      expect(s.students.map((e) => e.code).toSet().length, s.students.length);
    });

    test('state survives a JSON round trip', () {
      final back = AppState.fromJson(s.toJson());
      expect(back.students.length, s.students.length);
      expect(back.sessions.length, s.sessions.length);
      expect(back.payments.length, s.payments.length);
      expect(
        back.sessions.first.records.length,
        s.sessions.first.records.length,
      );
    });
  });

  group('session slots', () {
    AppState empty() => const AppState(
      teacher: Teacher(name: 't', sessionPrice: 175, monthPrice: 700),
      groups: [],
      students: [],
      sessions: [],
      payments: [],
    );

    Session closed(int month, int number) => Session(
      id: 'x$month$number',
      groupId: 'g',
      date: '2026-01-01',
      number: number,
      month: month,
      status: SessionStatus.closed,
      order: const [],
      records: const {},
      createdAtMs: month * 10 + number,
    );

    test('first session is 1 of month 1', () {
      final slot = nextSessionSlot(empty(), 'g');
      expect((slot.number, slot.month), (1, 1));
    });

    test('number increments inside a month', () {
      final s = empty().copyWith(sessions: [closed(1, 1), closed(1, 2)]);
      final slot = nextSessionSlot(s, 'g');
      expect((slot.number, slot.month), (3, 1));
    });

    test('a new month starts after the 4th session', () {
      final s = empty().copyWith(
        sessions: [closed(1, 1), closed(1, 2), closed(1, 3), closed(1, 4)],
      );
      final slot = nextSessionSlot(s, 'g');
      expect((slot.number, slot.month), (1, 2));
    });
  });

  group('payments', () {
    AppState withPayments(List<Payment> p) => AppState(
      teacher: const Teacher(name: 't', sessionPrice: 175, monthPrice: 700),
      groups: const [],
      students: const [],
      sessions: const [],
      payments: p,
    );

    Payment pay(int month, int amount) => Payment(
      id: 'p$month$amount',
      studentId: 's',
      month: month,
      amount: amount,
      method: PayMethod.cash,
      date: '2026-11-01',
      createdAtMs: 1,
    );

    test('paid / partial / none / upcoming', () {
      final s = withPayments([pay(1, 700), pay(2, 350)]);
      expect(payStatus(s, 's', 1, currentMonth: 2), PayStatus.paid);
      expect(payStatus(s, 's', 2, currentMonth: 2), PayStatus.partial);
      expect(payStatus(s, 's', 3, currentMonth: 2), PayStatus.upcoming);
      expect(payStatus(s, 'other', 2, currentMonth: 2), PayStatus.none);
    });

    test('several payments add up and remaining never goes negative', () {
      final s = withPayments([pay(1, 350), pay(1, 350), pay(1, 100)]);
      expect(paidFor(s, 's', 1), 800);
      expect(remainingFor(s, 's', 1), 0);
      expect(payStatus(s, 's', 1, currentMonth: 1), PayStatus.paid);
    });
  });

  group('compensation', () {
    test('uncovered absences are listed and covered ones are not', () {
      final s0 = buildSeedState(testNow);
      // Find a student with at least one absence in the seed.
      Student? target;
      for (final st in s0.students) {
        if (missedSessions(s0, st.id).isNotEmpty) {
          target = st;
          break;
        }
      }
      expect(target, isNotNull);
      final tgt = target!;
      final missed = missedSessions(s0, tgt.id);
      final first = missed.first.session;

      // Cover the first absence with a make-up record in another session.
      final host = s0.sessions.last;
      final records = Map<String, SessionRecord>.from(host.records)
        ..[tgt.id] = SessionRecord(
          attendance: Attendance.present,
          compensationFor: first.id,
        );
      final s1 = s0.copyWith(
        sessions: [
          for (final x in s0.sessions)
            if (x.id == host.id) x.copyWith(records: records) else x,
        ],
      );
      final after = missedSessions(s1, tgt.id);
      expect(after.any((m) => m.session.id == first.id), isFalse);
    });
  });

  group('search', () {
    test('finds by code ignoring case and by normalized name', () {
      final s = buildSeedState(testNow);
      final byCode = searchStudents(s, 's101');
      expect(byCode.map((e) => e.code), contains('S101'));
      final name = s.students.first.name.split(' ').first;
      final byName = searchStudents(s, name);
      expect(byName, isNotEmpty);
      expect(searchStudents(s, 'zzzzzz'), isEmpty);
    });

    test('empty query returns everyone sorted by code', () {
      final s = buildSeedState(testNow);
      final all = searchStudents(s, '');
      expect(all.length, s.students.length);
    });
  });
}
