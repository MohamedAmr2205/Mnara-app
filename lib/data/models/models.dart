import 'package:assistant/core/utils/cairo_time.dart';
import 'package:assistant/data/models/enums.dart';

/// Reads a Firestore `Timestamp` (or `DateTime`) as a [DateTime].
DateTime? readTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  try {
    final converted = (value as dynamic).toDate();
    return converted is DateTime ? converted : null;
  } catch (_) {
    return null;
  }
}

int _int(Object? v, int fallback) => v is num ? v.toInt() : fallback;

/// Teacher settings document.
class Teacher {
  /// Creates a teacher.
  const Teacher({
    required this.id,
    required this.name,
    this.studentCounter = 1000,
    this.priceSession = 175,
    this.priceMonth = 700,
    this.maxPinAttempts = 10,
    this.idleLockMinutes = 5,
    this.sessionsPerMonth = 4,
  });

  /// Parses a document.
  factory Teacher.fromMap(String id, Map<String, dynamic> m) {
    final counters = m['counters'] is Map ? m['counters'] as Map : const {};
    final pricing = m['pricing'] is Map ? m['pricing'] as Map : const {};
    return Teacher(
      id: id,
      name: (m['name'] as String?) ?? '',
      studentCounter: _int(counters['student'], 1000),
      priceSession: _int(pricing['session'], 175),
      priceMonth: _int(pricing['month'], 700),
      maxPinAttempts: _int(m['maxPinAttempts'], 10),
      idleLockMinutes: _int(m['idleLockMinutes'], 5),
      sessionsPerMonth: _int(m['sessionsPerMonth'], 4),
    );
  }

  /// Document id.
  final String id;

  /// Display name.
  final String name;

  /// Last issued permanent student number.
  final int studentCounter;

  /// Price of one session.
  final int priceSession;

  /// Price of one month.
  final int priceMonth;

  /// Wrong PIN attempts before lockout.
  final int maxPinAttempts;

  /// Idle minutes before auto-lock.
  final int idleLockMinutes;

  /// Sessions per month used for numbering (D13).
  final int sessionsPerMonth;
}

/// A class group.
class Group {
  /// Creates a group.
  const Group({
    required this.id,
    required this.name,
    required this.gradeLabel,
    required this.dayOfWeek,
    required this.timeLabel,
    this.order = 0,
    this.priceSession,
    this.priceMonth,
    this.active = true,
  });

  /// Parses a document.
  factory Group.fromMap(String id, Map<String, dynamic> m) {
    final pricing = m['pricing'] is Map ? m['pricing'] as Map : const {};
    return Group(
      id: id,
      name: (m['name'] as String?) ?? '',
      gradeLabel: (m['gradeLabel'] as String?) ?? '',
      dayOfWeek: _int(m['dayOfWeek'], 1),
      timeLabel: (m['timeLabel'] as String?) ?? '',
      order: _int(m['order'], 0),
      priceSession: pricing['session'] is num
          ? (pricing['session'] as num).toInt()
          : null,
      priceMonth: pricing['month'] is num
          ? (pricing['month'] as num).toInt()
          : null,
      active: (m['active'] as bool?) ?? true,
    );
  }

  /// Document id.
  final String id;

  /// Group name.
  final String name;

  /// Grade label such as "أولى ثانوي".
  final String gradeLabel;

  /// ISO weekday, 1 = Monday .. 7 = Sunday.
  final int dayOfWeek;

  /// Time label such as "6:00 م".
  final String timeLabel;

  /// Sort order.
  final int order;

  /// Optional per-group session price.
  final int? priceSession;

  /// Optional per-group month price.
  final int? priceMonth;

  /// Whether the group is active.
  final bool active;

  /// `الأربعاء · 6:00 م`.
  String get when => '${weekdayName(dayOfWeek)} · $timeLabel';

  /// Year bucket for the filter chips: 1, 2, 3 or 0 when unknown.
  int get year {
    if (gradeLabel.contains('أولى') || gradeLabel.contains('اولى')) return 1;
    if (gradeLabel.contains('تانية') ||
        gradeLabel.contains('ثانية') ||
        gradeLabel.contains('تانيه')) {
      return 2;
    }
    if (gradeLabel.contains('تالتة') ||
        gradeLabel.contains('ثالثة') ||
        gradeLabel.contains('تالته')) {
      return 3;
    }
    return 0;
  }

  /// Whether the group meets on the weekday of [iso].
  bool meetsOn(String iso) => parseIso(iso)?.weekday == dayOfWeek;
}

/// A student.
class Student {
  /// Creates a student.
  const Student({
    required this.id,
    required this.code,
    required this.isTempCode,
    required this.name,
    required this.phone,
    required this.parentPhone,
    required this.groupId,
    this.active = true,
    this.createdAt,
    this.addedInSessionId,
    this.pending = false,
  });

  /// Parses a document.
  factory Student.fromMap(
    String id,
    Map<String, dynamic> m, {
    bool pending = false,
  }) {
    return Student(
      id: id,
      code: (m['code'] as String?) ?? '',
      isTempCode: (m['isTempCode'] as bool?) ?? false,
      name: (m['name'] as String?) ?? '',
      phone: (m['phone'] as String?) ?? '',
      parentPhone: (m['parentPhone'] as String?) ?? '',
      groupId: (m['groupId'] as String?) ?? '',
      active: (m['status'] as String?) != 'inactive',
      createdAt: readTime(m['createdAt']),
      addedInSessionId: m['addedInSessionId'] as String?,
      pending: pending,
    );
  }

  /// Document id.
  final String id;

  /// Student code (`S1001`, or `N-AB12` while temporary).
  final String code;

  /// Whether [code] is still temporary.
  final bool isTempCode;

  /// Full name.
  final String name;

  /// Student phone.
  final String phone;

  /// Parent phone.
  final String parentPhone;

  /// Home group id.
  final String groupId;

  /// Whether the student is active.
  final bool active;

  /// Creation time.
  final DateTime? createdAt;

  /// Session in which the student was added.
  final String? addedInSessionId;

  /// True while the write is not yet on the server.
  final bool pending;
}

/// Session lifecycle.
enum SessionStatus {
  open('open'),
  finished('finished');

  const SessionStatus(this.key);

  /// Stored value.
  final String key;
}

/// A class session.
class Session {
  /// Creates a session.
  const Session({
    required this.id,
    required this.groupId,
    required this.date,
    required this.number,
    required this.monthNumber,
    required this.status,
    required this.editableUntil,
    this.maxExam = 20,
    this.noExam = false,
    this.notes = '',
    this.startedAt,
    this.finishedAt,
    this.pending = false,
  });

  /// Parses a document.
  factory Session.fromMap(
    String id,
    Map<String, dynamic> m, {
    bool pending = false,
  }) {
    return Session(
      id: id,
      groupId: (m['groupId'] as String?) ?? '',
      date: (m['date'] as String?) ?? '',
      number: _int(m['number'], 1),
      monthNumber: _int(m['monthNumber'], 1),
      status: m['status'] == 'finished'
          ? SessionStatus.finished
          : SessionStatus.open,
      maxExam: m['maxExam'] is num ? (m['maxExam'] as num).toInt() : null,
      noExam: (m['noExam'] as bool?) ?? false,
      notes: (m['notes'] as String?) ?? '',
      startedAt: readTime(m['startedAt']),
      finishedAt: readTime(m['finishedAt']),
      editableUntil: readTime(m['editableUntil']) ?? DateTime.now(),
      pending: pending,
    );
  }

  /// Document id.
  final String id;

  /// Group id.
  final String groupId;

  /// ISO date in Cairo.
  final String date;

  /// Running session number.
  final int number;

  /// Month number.
  final int monthNumber;

  /// Open or finished.
  final SessionStatus status;

  /// Edit window end (UTC instant).
  final DateTime editableUntil;

  /// Maximum exam score (null when there is no exam).
  final int? maxExam;

  /// Whether the session has no exam.
  final bool noExam;

  /// Free-form notes.
  final String notes;

  /// Start time.
  final DateTime? startedAt;

  /// Finish time.
  final DateTime? finishedAt;

  /// True while the write is not yet on the server.
  final bool pending;

  /// Whether the session is still open.
  bool get isOpen => status == SessionStatus.open;

  /// `حصة 3 · شهر 2`.
  String get label => 'حصة $number · شهر $monthNumber';

  /// Copy with changes.
  Session copyWith({
    int? maxExam,
    bool? noExam,
    String? notes,
    SessionStatus? status,
    DateTime? finishedAt,
    bool clearMaxExam = false,
  }) {
    return Session(
      id: id,
      groupId: groupId,
      date: date,
      number: number,
      monthNumber: monthNumber,
      status: status ?? this.status,
      editableUntil: editableUntil,
      maxExam: clearMaxExam ? null : (maxExam ?? this.maxExam),
      noExam: noExam ?? this.noExam,
      notes: notes ?? this.notes,
      startedAt: startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      pending: pending,
    );
  }
}

/// Details of a student created inside a session, staged until finish.
class NewStudentDraft {
  /// Creates a draft.
  const NewStudentDraft({
    required this.studentId,
    required this.name,
    required this.phone,
    required this.parentPhone,
    required this.code,
    required this.pay,
    this.amountEgp = 0,
    this.method = PayMethod.cash,
    this.created = false,
  });

  /// Parses the embedded map.
  factory NewStudentDraft.fromMap(Map<String, dynamic> m) {
    return NewStudentDraft(
      studentId: (m['studentId'] as String?) ?? '',
      name: (m['name'] as String?) ?? '',
      phone: (m['phone'] as String?) ?? '',
      parentPhone: (m['parentPhone'] as String?) ?? '',
      code: (m['code'] as String?) ?? '',
      pay: NewStudentPay.fromKey(m['pay']),
      amountEgp: _int(m['amountEgp'], 0),
      method: PayMethod.fromKey(m['method']),
      created: (m['created'] as bool?) ?? false,
    );
  }

  /// Pre-generated student document id.
  final String studentId;

  /// Name.
  final String name;

  /// Student phone.
  final String phone;

  /// Parent phone.
  final String parentPhone;

  /// Temporary code.
  final String code;

  /// Payment choice.
  final NewStudentPay pay;

  /// Amount paid.
  final int amountEgp;

  /// Payment method.
  final PayMethod method;

  /// Whether the student document has already been created.
  final bool created;

  /// Map form for embedding in a record.
  Map<String, dynamic> toMap() => {
    'studentId': studentId,
    'name': name,
    'phone': phone,
    'parentPhone': parentPhone,
    'code': code,
    'pay': pay.key,
    'amountEgp': amountEgp,
    'method': method.key,
    'created': created,
  };
}

/// One student's row in a session.
class SessionRecord {
  /// Creates a record.
  const SessionRecord({
    required this.studentId,
    this.sessionId = '',
    this.attendance,
    this.homework,
    this.examScore,
    this.note = '',
    this.kind = RecordKind.regular,
    this.makeupForSessionId,
    this.makeupForNumber,
    this.makeupForMonth,
    this.newStudent,
    this.updatedAt,
  });

  /// Parses a document.
  factory SessionRecord.fromMap(
    String sessionId,
    String studentId,
    Map<String, dynamic> m,
  ) {
    return SessionRecord(
      sessionId: sessionId,
      studentId: studentId,
      attendance: Attendance.fromKey(m['attendance']),
      homework: Homework.fromKey(m['homework']),
      examScore: m['examScore'] is num ? m['examScore'] as num : null,
      note: (m['note'] as String?) ?? '',
      kind: RecordKind.fromKey(m['kind']),
      makeupForSessionId: m['makeupForSessionId'] as String?,
      makeupForNumber: m['makeupForNumber'] is num
          ? (m['makeupForNumber'] as num).toInt()
          : null,
      makeupForMonth: m['makeupForMonth'] is num
          ? (m['makeupForMonth'] as num).toInt()
          : null,
      newStudent: m['newStudent'] is Map
          ? NewStudentDraft.fromMap(
              Map<String, dynamic>.from(m['newStudent'] as Map),
            )
          : null,
      updatedAt: readTime(m['updatedAt']),
    );
  }

  /// Student document id (also the record document id).
  final String studentId;

  /// Parent session id.
  final String sessionId;

  /// Attendance (null = not marked yet).
  final Attendance? attendance;

  /// Homework grade.
  final Homework? homework;

  /// Exam score.
  final num? examScore;

  /// Note about the student.
  final String note;

  /// Row kind.
  final RecordKind kind;

  /// Missed session this makeup covers.
  final String? makeupForSessionId;

  /// Number of the missed session.
  final int? makeupForNumber;

  /// Month of the missed session.
  final int? makeupForMonth;

  /// Staged new-student details.
  final NewStudentDraft? newStudent;

  /// Last update time.
  final DateTime? updatedAt;

  /// Copy with changes; use the `clear*` flags to null a field.
  SessionRecord copyWith({
    Attendance? attendance,
    Homework? homework,
    num? examScore,
    String? note,
    NewStudentDraft? newStudent,
    bool clearAttendance = false,
    bool clearHomework = false,
    bool clearExam = false,
  }) {
    return SessionRecord(
      studentId: studentId,
      sessionId: sessionId,
      attendance: clearAttendance ? null : (attendance ?? this.attendance),
      homework: clearHomework ? null : (homework ?? this.homework),
      examScore: clearExam ? null : (examScore ?? this.examScore),
      note: note ?? this.note,
      kind: kind,
      makeupForSessionId: makeupForSessionId,
      makeupForNumber: makeupForNumber,
      makeupForMonth: makeupForMonth,
      newStudent: newStudent ?? this.newStudent,
      updatedAt: updatedAt,
    );
  }
}

/// A payment.
class Payment {
  /// Creates a payment.
  const Payment({
    required this.id,
    required this.studentId,
    required this.groupId,
    required this.month,
    required this.amountEgp,
    required this.method,
    required this.paidOn,
    this.createdAt,
    this.pending = false,
  });

  /// Parses a document.
  factory Payment.fromMap(
    String id,
    Map<String, dynamic> m, {
    bool pending = false,
  }) {
    return Payment(
      id: id,
      studentId: (m['studentId'] as String?) ?? '',
      groupId: (m['groupId'] as String?) ?? '',
      month: _int(m['month'], 1),
      amountEgp: _int(m['amountEgp'], 0),
      method: PayMethod.fromKey(m['method']),
      paidOn: (m['paidOn'] as String?) ?? '',
      createdAt: readTime(m['createdAt']),
      pending: pending,
    );
  }

  /// Document id.
  final String id;

  /// Student id.
  final String studentId;

  /// Group id.
  final String groupId;

  /// Month number.
  final int month;

  /// Whole pounds.
  final int amountEgp;

  /// Payment method.
  final PayMethod method;

  /// ISO date.
  final String paidOn;

  /// Creation time.
  final DateTime? createdAt;

  /// True while the write is not yet on the server.
  final bool pending;
}

/// Per-teacher app metadata.
class AppMeta {
  /// Creates metadata.
  const AppMeta({this.activeSessionId});

  /// Id of the open session that was not finished, if any.
  final String? activeSessionId;
}
