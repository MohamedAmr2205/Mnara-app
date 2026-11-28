import 'dart:math' as math;

import 'package:assistant/core/util/date_utils.dart';
import 'package:assistant/domain/app_state.dart';
import 'package:assistant/domain/models.dart';

const List<String> _first = [
  'يوسف',
  'مريم',
  'عمر',
  'نور',
  'أحمد',
  'فرح',
  'كريم',
  'سلمى',
  'مصطفى',
  'هنا',
  'آدم',
  'جنى',
  'زياد',
  'ليلى',
  'مالك',
  'ملك',
  'حمزة',
  'رنا',
  'بلال',
  'ياسمين',
];

const List<String> _father = [
  'عادل',
  'خالد',
  'محمد',
  'سامي',
  'حسن',
  'إبراهيم',
  'طارق',
  'علي',
  'ياسر',
  'وائل',
  'هشام',
  'عمرو',
  'رامي',
  'سعيد',
  'ناصر',
  'كمال',
  'فتحي',
  'عصام',
  'محمود',
  'صلاح',
];

const List<String> _grand = ['حسين', 'مصطفى', 'عبد الله', 'سليمان', 'فؤاد'];

/// Demo data: 3 groups, 12 students each, 6 past sessions and payments.
///
/// The first group meets today so the "today" badge and the start-session
/// flow are visible right away. Deterministic for a given [now].
AppState buildSeedState(DateTime now, {AppState? keep}) {
  final rng = math.Random(7);
  final today = dateOnly(now);

  final weekdays = <int>[
    today.weekday,
    today.weekday % 7 + 1,
    (today.weekday + 2) % 7 + 1,
  ];
  const hours = <int>[18, 16, 20];
  const grades = <int>[1, 2, 3];
  const labels = <String>['لغات أولى', 'لغات تانية', 'لغات تالتة'];

  final groups = <Group>[
    for (var i = 0; i < 3; i++)
      Group(
        id: 'g${i + 1}',
        name: '${labels[i]} ${arabicWeekdays[weekdays[i] - 1]}',
        weekday: weekdays[i],
        hour: hours[i],
        minute: 0,
        grade: grades[i],
      ),
  ];

  String phone() {
    final tail = List<int>.generate(8, (_) => rng.nextInt(10)).join();
    return '01${[0, 1, 2, 5][rng.nextInt(4)]}$tail';
  }

  final students = <Student>[];
  var idx = 0;
  for (final g in groups) {
    for (var k = 0; k < 12; k++) {
      final first = _first[(idx + k * 3) % _first.length];
      final father = _father[(idx * 7 + 3) % _father.length];
      final grand = _grand[(idx + k) % _grand.length];
      students.add(
        Student(
          id: 's${idx + 1}',
          code: 'S${101 + idx}',
          name: '$first $father $grand',
          studentPhone: phone(),
          parentPhone: phone(),
          groupId: g.id,
        ),
      );
      idx++;
    }
  }

  final nowMs = now.millisecondsSinceEpoch;
  final sessions = <Session>[];
  final payments = <Payment>[];

  for (final g in groups) {
    var back = (today.weekday - g.weekday) % 7;
    if (back == 0) back = 7;
    final roster = students.where((x) => x.groupId == g.id).toList();
    for (var i = 0; i < 6; i++) {
      final date = today.subtract(Duration(days: back + 7 * (5 - i)));
      final number = i < 4 ? i + 1 : i - 3;
      final month = i < 4 ? 1 : 2;
      final hasExam = i == 3 || i == 5;
      final records = <String, SessionRecord>{};
      for (final st in roster) {
        final r = rng.nextDouble();
        final att = r < 0.72
            ? Attendance.present
            : r < 0.82
            ? Attendance.late
            : r < 0.94
            ? Attendance.absent
            : Attendance.excused;
        Homework? hw;
        double? exam;
        if (att.attended) {
          final h = rng.nextDouble();
          hw = h < 0.3
              ? Homework.excellent
              : h < 0.55
              ? Homework.veryGood
              : h < 0.75
              ? Homework.good
              : h < 0.88
              ? Homework.acceptable
              : h < 0.95
              ? Homework.weak
              : Homework.notSubmitted;
          if (hasExam) exam = 8 + rng.nextInt(25) * 0.5;
        }
        records[st.id] = SessionRecord(
          attendance: att,
          homework: hw,
          exam: exam,
        );
      }
      sessions.add(
        Session(
          id: '${g.id}-x${i + 1}',
          groupId: g.id,
          date: dateKey(date),
          number: number,
          month: month,
          status: SessionStatus.closed,
          order: roster.map((e) => e.id).toList(),
          records: records,
          createdAtMs: date.millisecondsSinceEpoch,
          noExam: !hasExam,
          syncedAt: nowMs,
        ),
      );
    }
    for (final st in roster) {
      final m1 = rng.nextDouble();
      if (m1 < 0.85) {
        payments.add(
          Payment(
            id: 'p-${st.id}-1',
            studentId: st.id,
            month: 1,
            amount: 700,
            method: PayMethod.values[rng.nextInt(3)],
            date: sessions.firstWhere((x) => x.groupId == g.id).date,
            createdAtMs: nowMs - 86400000 * 30,
            syncedAt: nowMs,
          ),
        );
      } else if (m1 < 0.95) {
        payments.add(
          Payment(
            id: 'p-${st.id}-1',
            studentId: st.id,
            month: 1,
            amount: 350,
            method: PayMethod.cash,
            date: sessions.firstWhere((x) => x.groupId == g.id).date,
            createdAtMs: nowMs - 86400000 * 30,
            syncedAt: nowMs,
          ),
        );
      }
      final m2 = rng.nextDouble();
      if (m2 < 0.5) {
        payments.add(
          Payment(
            id: 'p-${st.id}-2',
            studentId: st.id,
            month: 2,
            amount: 700,
            method: PayMethod.values[rng.nextInt(3)],
            date: dateKey(today.subtract(const Duration(days: 8))),
            createdAtMs: nowMs - 86400000 * 8,
            syncedAt: nowMs,
          ),
        );
      } else if (m2 < 0.65) {
        payments.add(
          Payment(
            id: 'p-${st.id}-2',
            studentId: st.id,
            month: 2,
            amount: 350,
            method: PayMethod.instapay,
            date: dateKey(today.subtract(const Duration(days: 8))),
            createdAtMs: nowMs - 86400000 * 8,
            syncedAt: nowMs,
          ),
        );
      }
    }
  }

  return AppState(
    teacher: const Teacher(
      name: 'أ. محمد',
      sessionPrice: 175,
      monthPrice: 700,
    ),
    groups: groups,
    students: students,
    sessions: sessions,
    payments: payments,
    // Keep the user's PIN, preferences and lock counter when reloading demo
    // data from the "no groups" screen.
    pin: keep?.pin,
    autoUpload: keep?.autoUpload ?? true,
    online: keep?.online ?? true,
    failedAttempts: keep?.failedAttempts ?? 0,
    studentCounter: 1000,
  );
}
