import 'package:assistant/data/models/enums.dart';
import 'package:assistant/data/models/models.dart';

/// Number and month of the next session of a group.
class NextSession {
  /// Creates the pair.
  const NextSession(this.number, this.monthNumber);

  /// Number inside the month.
  final int number;

  /// Month number.
  final int monthNumber;
}

/// Computes the next session from the group's existing sessions (D13).
///
/// Numbers run 1..[perMonth] inside a month; after the last one the month
/// advances and numbering restarts.
NextSession nextSessionFor(
  Iterable<Session> groupSessions, {
  int perMonth = 4,
}) {
  Session? last;
  for (final s in groupSessions) {
    if (last == null ||
        s.monthNumber > last.monthNumber ||
        (s.monthNumber == last.monthNumber && s.number > last.number)) {
      last = s;
    }
  }
  if (last == null) return const NextSession(1, 1);
  if (last.number >= perMonth) return NextSession(1, last.monthNumber + 1);
  return NextSession(last.number + 1, last.monthNumber);
}

/// Current month of a group (month of its latest session, 1 when none).
int currentMonthOf(Iterable<Session> groupSessions) {
  var month = 1;
  for (final s in groupSessions) {
    if (s.monthNumber > month) month = s.monthNumber;
  }
  return month;
}

/// A past absence a makeup can be linked to.
class MissedSession {
  /// Creates a missed-session descriptor.
  const MissedSession({
    required this.sessionId,
    required this.number,
    required this.month,
    required this.date,
    required this.attendance,
  });

  /// Session id.
  final String sessionId;

  /// Session number.
  final int number;

  /// Session month.
  final int month;

  /// ISO date.
  final String date;

  /// `absent` or `excused`.
  final Attendance attendance;
}

/// Absences of a student that no makeup record covers yet.
///
/// An absence is covered when any record of the same student has
/// `makeupForSessionId` equal to that session (the original is never mutated).
List<MissedSession> uncoveredAbsences({
  required Iterable<SessionRecord> studentRecords,
  required Map<String, Session> sessionsById,
}) {
  final covered = <String>{
    for (final r in studentRecords)
      if (r.makeupForSessionId != null) r.makeupForSessionId!,
  };
  final result = <MissedSession>[];
  for (final r in studentRecords) {
    final a = r.attendance;
    if (a != Attendance.absent && a != Attendance.excused) continue;
    if (r.kind == RecordKind.makeup) continue;
    final session = sessionsById[r.sessionId];
    if (session == null || covered.contains(session.id)) continue;
    result.add(
      MissedSession(
        sessionId: session.id,
        number: session.number,
        month: session.monthNumber,
        date: session.date,
        attendance: a!,
      ),
    );
  }
  result.sort((x, y) => y.date.compareTo(x.date));
  return result;
}

/// Live counters of a session.
class Tally {
  /// Creates a tally.
  const Tally({
    required this.present,
    required this.late,
    required this.absent,
    required this.excused,
    required this.unmarked,
    required this.total,
  });

  /// Counts [records] against a roster of [total] rows.
  factory Tally.of(Iterable<SessionRecord> records, int total) {
    var p = 0, l = 0, a = 0, e = 0;
    for (final r in records) {
      switch (r.attendance) {
        case Attendance.present:
          p++;
        case Attendance.late:
          l++;
        case Attendance.absent:
          a++;
        case Attendance.excused:
          e++;
        case null:
          break;
      }
    }
    final marked = p + l + a + e;
    return Tally(
      present: p,
      late: l,
      absent: a,
      excused: e,
      unmarked: total - marked < 0 ? 0 : total - marked,
      total: total,
    );
  }

  /// Present count.
  final int present;

  /// Late count.
  final int late;

  /// Absent count.
  final int absent;

  /// Excused count.
  final int excused;

  /// Rows still unmarked.
  final int unmarked;

  /// Roster size.
  final int total;

  /// Rows that have an attendance mark.
  int get marked => total - unmarked;

  /// Progress 0..1.
  double get progress => total == 0 ? 0 : marked / total;

  /// Present + late.
  int get attended => present + late;
}

/// Figures of the finish screen.
class SessionSummary {
  /// Creates a summary.
  const SessionSummary({
    required this.tally,
    required this.homeworkRated,
    required this.homeworkNotSubmitted,
    required this.examCount,
    required this.examAverage,
    required this.examAveragePercent,
    required this.owingCount,
  });

  /// Attendance tally.
  final Tally tally;

  /// Students with a homework grade.
  final int homeworkRated;

  /// Students whose homework was not submitted.
  final int homeworkNotSubmitted;

  /// Students with an exam score.
  final int examCount;

  /// Average exam score (null when none).
  final double? examAverage;

  /// Average as a percentage of the maximum (null when none).
  final int? examAveragePercent;

  /// Students who still owe the current month.
  final int owingCount;
}

/// Builds the summary of a session.
SessionSummary summarize({
  required Iterable<SessionRecord> records,
  required int total,
  required int? maxExam,
  required int owingCount,
}) {
  final list = records.toList();
  var rated = 0, notSubmitted = 0, exams = 0;
  var sum = 0.0;
  for (final r in list) {
    if (r.homework != null) {
      rated++;
      if (r.homework == Homework.notSubmitted) notSubmitted++;
    }
    if (r.examScore != null) {
      exams++;
      sum += r.examScore!.toDouble();
    }
  }
  final avg = exams == 0 ? null : sum / exams;
  final pct = (avg == null || maxExam == null || maxExam <= 0)
      ? null
      : ((avg / maxExam) * 100).round();
  return SessionSummary(
    tally: Tally.of(list, total),
    homeworkRated: rated,
    homeworkNotSubmitted: notSubmitted,
    examCount: exams,
    examAverage: avg,
    examAveragePercent: pct,
    owingCount: owingCount,
  );
}
