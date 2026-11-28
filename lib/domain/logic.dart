import 'package:assistant/core/util/date_utils.dart';
import 'package:assistant/core/util/text_utils.dart';
import 'package:assistant/domain/app_state.dart';
import 'package:assistant/domain/models.dart';

/// Sessions per month: a month counts 4 sessions (4 x 175 = 700).
const int sessionsPerMonth = 4;

/// Days a saved session stays editable (day 0..9 open, day 10 locked).
const int editWindowDays = 10;

/// Failed PIN attempts before the lock engages.
const int maxPinAttempts = 10;

/// Number/month of a group's next session.
({int number, int month}) nextSessionSlot(AppState s, String groupId) {
  Session? last;
  for (final x in s.sessions) {
    if (x.groupId != groupId) continue;
    if (last == null ||
        x.month > last.month ||
        (x.month == last.month && x.number > last.number)) {
      last = x;
    }
  }
  if (last == null) return (number: 1, month: 1);
  if (last.number >= sessionsPerMonth) {
    return (number: 1, month: last.month + 1);
  }
  return (number: last.number + 1, month: last.month);
}

/// Month the group is currently collecting payments for.
int currentMonthOf(AppState s, String groupId) =>
    nextSessionSlot(s, groupId).month;

/// Students whose home group is [groupId].
List<Student> studentsOfGroup(AppState s, String groupId) =>
    s.students.where((x) => x.groupId == groupId).toList();

/// Looks a student up by id.
Student? studentById(AppState s, String id) {
  for (final x in s.students) {
    if (x.id == id) return x;
  }
  return null;
}

/// Looks a group up by id.
Group? groupById(AppState s, String id) {
  for (final x in s.groups) {
    if (x.id == id) return x;
  }
  return null;
}

/// Looks a session up by id.
Session? sessionById(AppState s, String id) {
  for (final x in s.sessions) {
    if (x.id == id) return x;
  }
  return null;
}

/// Day and time of a group, e.g. `الأربعاء · 6:00 م`.
String groupWhen(Group g) =>
    '${arabicWeekdays[g.weekday - 1]} · ${formatTime12(g.hour, g.minute)}';

/// Grade label.
String gradeLabel(int grade) => switch (grade) {
  1 => 'أولى',
  2 => 'تانية',
  _ => 'تالتة',
};

// ---------------------------------------------------------------- payments

/// Payment state of a student for a month.
enum PayStatus { paid, partial, none, upcoming }

/// Total paid by [studentId] for [month].
int paidFor(AppState s, String studentId, int month) {
  var sum = 0;
  for (final p in s.payments) {
    if (p.studentId == studentId && p.month == month) sum += p.amount;
  }
  return sum;
}

/// Remaining amount for the month (never negative).
int remainingFor(AppState s, String studentId, int month) {
  final r = s.teacher.monthPrice - paidFor(s, studentId, month);
  return r < 0 ? 0 : r;
}

/// Status of [studentId] for [month] given the group's current month.
PayStatus payStatus(
  AppState s,
  String studentId,
  int month, {
  required int currentMonth,
}) {
  final paid = paidFor(s, studentId, month);
  if (paid >= s.teacher.monthPrice) return PayStatus.paid;
  if (paid > 0) return PayStatus.partial;
  if (month > currentMonth) return PayStatus.upcoming;
  return PayStatus.none;
}

/// Months shown for a student: at least 3, up to the group's current month.
List<int> monthsFor(AppState s, Student st) {
  final cur = currentMonthOf(s, st.groupId);
  final n = cur < 3 ? 3 : cur;
  return List<int>.generate(n, (i) => i + 1);
}

/// Aggregate payment state used by lists (month = the group's current).
PayStatus currentPayStatus(AppState s, Student st) {
  final m = currentMonthOf(s, st.groupId);
  return payStatus(s, st.id, m, currentMonth: m);
}

/// Pay summary for search results: paid / partial / none.
PayStatus overallPayStatus(AppState s, Student st) {
  final m = currentMonthOf(s, st.groupId);
  final paid = paidFor(s, st.id, m);
  if (paid >= s.teacher.monthPrice) return PayStatus.paid;
  if (paid > 0) return PayStatus.partial;
  return PayStatus.none;
}

// ------------------------------------------------------------ compensation

/// A past absence that can be linked to a make-up attendance.
class MissedSession {
  /// Creates the entry.
  const MissedSession({required this.session, required this.attendance});

  /// The session that was missed.
  final Session session;

  /// `absent` or `excused`.
  final Attendance attendance;
}

/// Absences of [studentId] not yet covered by a make-up record.
List<MissedSession> missedSessions(AppState s, String studentId) {
  final covered = <String>{};
  for (final x in s.sessions) {
    final c = x.records[studentId]?.compensationFor;
    if (c != null) covered.add(c);
  }
  final out = <MissedSession>[];
  for (final x in s.sessions) {
    if (x.status != SessionStatus.closed) continue;
    final a = x.records[studentId]?.attendance;
    if (a == Attendance.absent || a == Attendance.excused) {
      if (!covered.contains(x.id)) {
        out.add(MissedSession(session: x, attendance: a!));
      }
    }
  }
  out.sort((a, b) => a.session.date.compareTo(b.session.date));
  return out;
}

// ------------------------------------------------------------- edit window

/// Days left to edit a session dated [dateKeyStr] (<= 0 means locked).
int editDaysLeft(DateTime today, String dateKeyStr) {
  return editWindowDays - daysBetween(parseDateKey(dateKeyStr), today);
}

/// Whether a session dated [dateKeyStr] can still be edited today.
bool isEditable(DateTime today, String dateKeyStr) =>
    editDaysLeft(today, dateKeyStr) > 0;

// ------------------------------------------------------------------ search

/// Students matching [query] by code or name (normalized); all when empty.
List<Student> searchStudents(AppState s, String query) {
  final q = normalizeSearch(query);
  final list = s.students.toList()
    ..sort((a, b) => a.code.toLowerCase().compareTo(b.code.toLowerCase()));
  if (q.isEmpty) return list;
  return list.where((st) {
    return st.code.toLowerCase().contains(q) ||
        normalizeSearch(st.name).contains(q);
  }).toList();
}

// ---------------------------------------------------------- session counts

/// Counters for the header card of the session screen.
class SessionCounts {
  /// Creates counters.
  const SessionCounts({
    required this.present,
    required this.late,
    required this.absent,
    required this.excused,
    required this.unmarked,
    required this.total,
  });

  /// Present.
  final int present;

  /// Late.
  final int late;

  /// Absent.
  final int absent;

  /// Excused.
  final int excused;

  /// Not marked yet.
  final int unmarked;

  /// Roster size.
  final int total;

  /// Marked students.
  int get marked => total - unmarked;
}

/// Counts attendance across the session roster.
SessionCounts countsOf(Session x) {
  var p = 0, l = 0, a = 0, e = 0, u = 0;
  for (final id in x.order) {
    switch (x.recordOf(id).attendance) {
      case Attendance.present:
        p++;
      case Attendance.late:
        l++;
      case Attendance.absent:
        a++;
      case Attendance.excused:
        e++;
      case null:
        u++;
    }
  }
  return SessionCounts(
    present: p,
    late: l,
    absent: a,
    excused: e,
    unmarked: u,
    total: x.order.length,
  );
}

/// Summary tiles of the finish screen.
class SessionSummary {
  /// Creates the summary.
  const SessionSummary({
    required this.counts,
    required this.homeworkGraded,
    required this.homeworkMissing,
    required this.examCount,
    required this.examAverage,
    required this.examPercent,
    required this.unpaid,
  });

  /// Attendance counters.
  final SessionCounts counts;

  /// Graded homework (excluding "not submitted").
  final int homeworkGraded;

  /// Not submitted.
  final int homeworkMissing;

  /// Number of recorded exam scores.
  final int examCount;

  /// Average exam score (0 when none).
  final double examAverage;

  /// Average as a percentage of the maximum (0 when none).
  final int examPercent;

  /// Students who have not completed this month's payment.
  final int unpaid;
}

/// Builds the finish-screen summary.
SessionSummary summaryOf(AppState s, Session x) {
  var graded = 0, missing = 0, exams = 0;
  var total = 0.0;
  var unpaid = 0;
  for (final id in x.order) {
    final r = x.recordOf(id);
    if (r.homework != null) {
      if (r.homework == Homework.notSubmitted) {
        missing++;
      } else {
        graded++;
      }
    }
    if (r.exam != null) {
      exams++;
      total += r.exam!;
    }
    final st = studentById(s, id);
    if (st != null && paidFor(s, id, x.month) < s.teacher.monthPrice) {
      unpaid++;
    }
  }
  final avg = exams == 0 ? 0.0 : total / exams;
  final pct = (exams == 0 || x.examMax == 0)
      ? 0
      : (avg / x.examMax * 100).round();
  return SessionSummary(
    counts: countsOf(x),
    homeworkGraded: graded,
    homeworkMissing: missing,
    examCount: exams,
    examAverage: avg,
    examPercent: pct,
    unpaid: unpaid,
  );
}

// --------------------------------------------------------- student profile

/// Per-student statistics for the profile screen.
class StudentStats {
  /// Creates stats.
  const StudentStats({
    required this.attended,
    required this.total,
    required this.examPercent,
    required this.notSubmitted,
  });

  /// Sessions attended (present or late).
  final int attended;

  /// Sessions with a record.
  final int total;

  /// Average exam percentage, or null when no exams.
  final int? examPercent;

  /// Homework "not submitted" count.
  final int notSubmitted;
}

/// Closed sessions in which [studentId] has a record, newest first.
List<Session> sessionsOfStudent(AppState s, String studentId) {
  final list = s.sessions
      .where(
        (x) =>
            x.status == SessionStatus.closed &&
            x.records[studentId]?.attendance != null,
      )
      .toList();
  list.sort((a, b) => b.date.compareTo(a.date));
  return list;
}

/// Statistics over the student's closed sessions.
StudentStats statsOf(AppState s, String studentId) {
  final sessions = sessionsOfStudent(s, studentId);
  var attended = 0, missing = 0, exams = 0;
  var pctSum = 0.0;
  for (final x in sessions) {
    final r = x.recordOf(studentId);
    if (r.attendance?.attended ?? false) attended++;
    if (r.homework == Homework.notSubmitted) missing++;
    if (r.exam != null && x.examMax > 0) {
      exams++;
      pctSum += r.exam! / x.examMax * 100;
    }
  }
  return StudentStats(
    attended: attended,
    total: sessions.length,
    examPercent: exams == 0 ? null : (pctSum / exams).round(),
    notSubmitted: missing,
  );
}

// -------------------------------------------------------------------- sync

/// Kind of an upload item.
enum SyncKind { session, payment, student }

/// One row of the Sync screen.
class SyncItem {
  /// Creates the row.
  const SyncItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.syncedAt,
  });

  /// Kind.
  final SyncKind kind;

  /// Entity id.
  final String id;

  /// Title line.
  final String title;

  /// Subtitle line.
  final String subtitle;

  /// Upload time in ms, or null when pending.
  final int? syncedAt;

  /// Pending upload.
  bool get pending => syncedAt == null;
}

/// All sync rows (sessions, payments, new students), newest first.
List<SyncItem> syncItems(AppState s) {
  final items = <(int, SyncItem)>[];
  for (final x in s.sessions) {
    if (x.status != SessionStatus.closed) continue;
    final g = groupById(s, x.groupId);
    final d = parseDateKey(x.date);
    items.add((
      x.createdAtMs,
      SyncItem(
        kind: SyncKind.session,
        id: x.id,
        title: 'حصة ${x.number} · ${g?.name ?? ''}',
        subtitle: '${x.order.length} طالب · ${formatDateShort(d)}',
        syncedAt: x.syncedAt,
      ),
    ));
  }
  for (final p in s.payments) {
    final st = studentById(s, p.studentId);
    final d = parseDateKey(p.date);
    items.add((
      p.createdAtMs,
      SyncItem(
        kind: SyncKind.payment,
        id: p.id,
        title: 'دفعة ${st?.name ?? ''} · ${p.amount} ج',
        subtitle: '${p.method.label} · ${formatDateShort(d)}',
        syncedAt: p.syncedAt,
      ),
    ));
  }
  for (final st in s.students) {
    if (!st.tempCode && st.syncedAt == null) continue;
    items.add((
      st.syncedAt ?? 0,
      SyncItem(
        kind: SyncKind.student,
        id: st.id,
        title: 'طالب جديد · ${st.code}',
        subtitle: st.name,
        syncedAt: st.syncedAt,
      ),
    ));
  }
  items.sort((a, b) {
    if (a.$2.pending != b.$2.pending) return a.$2.pending ? -1 : 1;
    return b.$1.compareTo(a.$1);
  });
  return items.map((e) => e.$2).toList();
}

/// Number of items waiting for upload.
int pendingCount(AppState s) => syncItems(s).where((i) => i.pending).length;
