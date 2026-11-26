import 'package:flutter_test/flutter_test.dart';

import 'package:assistant/data/models/enums.dart';
import 'package:assistant/data/models/models.dart';
import 'package:assistant/domain/session_logic.dart';

Session _session(String id, int number, int month, String date) => Session(
  id: id,
  groupId: 'g1',
  date: date,
  number: number,
  monthNumber: month,
  status: SessionStatus.finished,
  editableUntil: DateTime.utc(2030),
);

SessionRecord _rec(String sessionId, Attendance a, {RecordKind kind = RecordKind.regular, String? makeupFor}) =>
    SessionRecord(studentId: 's1', sessionId: sessionId, attendance: a, kind: kind, makeupForSessionId: makeupFor);

void main() {
  group('session numbering', () {
    test('starts at 1 / month 1', () {
      final n = nextSessionFor(const []);
      expect((n.number, n.monthNumber), (1, 1));
    });

    test('continues inside the month and rolls over after the last session', () {
      expect(nextSessionFor([_session('a', 2, 2, '2026-11-18')]).number, 3);
      final roll = nextSessionFor([_session('a', 4, 2, '2026-11-18')]);
      expect((roll.number, roll.monthNumber), (1, 3));
    });

    test('uses the latest session regardless of list order', () {
      final n = nextSessionFor([_session('b', 1, 2, '2026-11-04'), _session('a', 3, 2, '2026-11-18')]);
      expect((n.number, n.monthNumber), (4, 2));
    });
  });

  group('makeup coverage', () {
    final sessions = {
      'a': _session('a', 1, 1, '2026-10-01'),
      'b': _session('b', 2, 1, '2026-10-08'),
      'c': _session('c', 3, 1, '2026-10-15'),
    };

    test('lists absent and excused sessions, newest first', () {
      final missed = uncoveredAbsences(
        studentRecords: [_rec('a', Attendance.absent), _rec('b', Attendance.excused), _rec('c', Attendance.present)],
        sessionsById: sessions,
      );
      expect(missed.map((m) => m.sessionId), ['b', 'a']);
      expect(missed.first.attendance, Attendance.excused);
    });

    test('an absence is covered once a later makeup links to it', () {
      final missed = uncoveredAbsences(
        studentRecords: [
          _rec('a', Attendance.absent),
          _rec('b', Attendance.absent),
          _rec('c', Attendance.present, kind: RecordKind.makeup, makeupFor: 'a'),
        ],
        sessionsById: sessions,
      );
      expect(missed.map((m) => m.sessionId), ['b']);
    });

    test('records of unknown sessions are ignored', () {
      expect(uncoveredAbsences(studentRecords: [_rec('zzz', Attendance.absent)], sessionsById: sessions), isEmpty);
    });
  });

  group('tally and summary', () {
    test('counts marks and unmarked rows', () {
      final t = Tally.of([
        _rec('x', Attendance.present),
        _rec('x', Attendance.late),
        _rec('x', Attendance.absent),
        const SessionRecord(studentId: 's9'),
      ], 6);
      expect((t.present, t.late, t.absent, t.excused), (1, 1, 1, 0));
      expect(t.unmarked, 3);
      expect(t.attended, 2);
      expect(t.progress, closeTo(0.5, 0.0001));
    });

    test('summary averages exam scores against the maximum', () {
      final s = summarize(
        records: [
          const SessionRecord(studentId: 'a', attendance: Attendance.present, homework: Homework.good, examScore: 18),
          const SessionRecord(studentId: 'b', attendance: Attendance.present, homework: Homework.notSubmitted, examScore: 12),
          const SessionRecord(studentId: 'c', attendance: Attendance.absent),
        ],
        total: 3,
        maxExam: 20,
        owingCount: 1,
      );
      expect(s.homeworkRated, 2);
      expect(s.homeworkNotSubmitted, 1);
      expect(s.examCount, 2);
      expect(s.examAverage, 15);
      expect(s.examAveragePercent, 75);
    });

    test('summary has no average without scores or without a maximum', () {
      final none = summarize(records: const [], total: 0, maxExam: 20, owingCount: 0);
      expect(none.examAverage, isNull);
      final noMax = summarize(
        records: const [SessionRecord(studentId: 'a', attendance: Attendance.present, examScore: 5)],
        total: 1,
        maxExam: null,
        owingCount: 0,
      );
      expect(noMax.examAveragePercent, isNull);
    });
  });
}
