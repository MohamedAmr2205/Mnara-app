/// Attendance of a student in one session.
enum Attendance {
  present('حضر'),
  late('متأخر'),
  absent('غايب'),
  excused('بعذر');

  const Attendance(this.label);

  /// Arabic label shown on buttons and chips.
  final String label;

  /// Present or late: the student was in class (homework/exam apply).
  bool get attended => this == present || this == late;
}

/// Homework grade.
enum Homework {
  excellent('ممتاز'),
  veryGood('جيد جدا'),
  good('جيد'),
  acceptable('مقبول'),
  weak('ضعيف'),
  notSubmitted('لم يسلم');

  const Homework(this.label);

  /// Arabic label.
  final String label;
}

/// Payment method.
enum PayMethod {
  cash('كاش'),
  instapay('إنستاباي'),
  vodafoneCash('فودافون كاش');

  const PayMethod(this.label);

  /// Arabic label.
  final String label;
}

/// Lifecycle of a session.
enum SessionStatus { open, closed }

/// Color of a student's tag in the session list.
enum TagTone { amber, mint }

T? _byName<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) return null;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

/// Teacher info and default prices.
class Teacher {
  /// Creates a teacher.
  const Teacher({
    required this.name,
    required this.sessionPrice,
    required this.monthPrice,
  });

  /// Display name.
  final String name;

  /// Price of one session in EGP.
  final int sessionPrice;

  /// Price of a month in EGP.
  final int monthPrice;

  /// JSON map.
  Map<String, dynamic> toJson() => {
    'name': name,
    'sessionPrice': sessionPrice,
    'monthPrice': monthPrice,
  };

  /// Reads from JSON.
  factory Teacher.fromJson(Map<String, dynamic> j) => Teacher(
    name: j['name'] as String,
    sessionPrice: j['sessionPrice'] as int,
    monthPrice: j['monthPrice'] as int,
  );
}

/// A class group that meets weekly.
class Group {
  /// Creates a group.
  const Group({
    required this.id,
    required this.name,
    required this.weekday,
    required this.hour,
    required this.minute,
    required this.grade,
  });

  /// Unique id.
  final String id;

  /// Display name.
  final String name;

  /// [DateTime.weekday] (1 = Monday ... 7 = Sunday).
  final int weekday;

  /// Start hour (24h).
  final int hour;

  /// Start minute.
  final int minute;

  /// Grade level 1..3.
  final int grade;

  /// JSON map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'weekday': weekday,
    'hour': hour,
    'minute': minute,
    'grade': grade,
  };

  /// Reads from JSON.
  factory Group.fromJson(Map<String, dynamic> j) => Group(
    id: j['id'] as String,
    name: j['name'] as String,
    weekday: j['weekday'] as int,
    hour: j['hour'] as int,
    minute: j['minute'] as int,
    grade: j['grade'] as int,
  );
}

/// A student.
class Student {
  /// Creates a student.
  const Student({
    required this.id,
    required this.code,
    required this.name,
    required this.studentPhone,
    required this.parentPhone,
    required this.groupId,
    this.tempCode = false,
    this.syncedAt,
  });

  /// Unique id.
  final String id;

  /// Student code (`S101`, or temporary `N-4F2A` until uploaded).
  final String code;

  /// Full name.
  final String name;

  /// Student mobile.
  final String studentPhone;

  /// Parent mobile.
  final String parentPhone;

  /// Home group id.
  final String groupId;

  /// True while the code is temporary (created offline, not uploaded yet).
  final bool tempCode;

  /// Upload time in ms, or null when still pending (only new students).
  final int? syncedAt;

  /// Copy with a few fields replaced.
  Student copyWith({String? code, bool? tempCode, int? syncedAt}) => Student(
    id: id,
    code: code ?? this.code,
    name: name,
    studentPhone: studentPhone,
    parentPhone: parentPhone,
    groupId: groupId,
    tempCode: tempCode ?? this.tempCode,
    syncedAt: syncedAt ?? this.syncedAt,
  );

  /// JSON map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'studentPhone': studentPhone,
    'parentPhone': parentPhone,
    'groupId': groupId,
    'tempCode': tempCode,
    'syncedAt': syncedAt,
  };

  /// Reads from JSON.
  factory Student.fromJson(Map<String, dynamic> j) => Student(
    id: j['id'] as String,
    code: j['code'] as String,
    name: j['name'] as String,
    studentPhone: j['studentPhone'] as String,
    parentPhone: j['parentPhone'] as String,
    groupId: j['groupId'] as String,
    tempCode: (j['tempCode'] as bool?) ?? false,
    syncedAt: j['syncedAt'] as int?,
  );
}

const Object _keep = Object();

/// What was recorded for one student in one session.
class SessionRecord {
  /// Creates a record.
  const SessionRecord({
    this.attendance,
    this.homework,
    this.exam,
    this.note = '',
    this.tag,
    this.tagTone,
    this.isNew = false,
    this.compensationFor,
  });

  /// Attendance, or null when not marked yet.
  final Attendance? attendance;

  /// Homework grade (only for attended students).
  final Homework? homework;

  /// Exam score (only for attended students).
  final double? exam;

  /// Free note about the student.
  final String note;

  /// Tag text for compensation/new students.
  final String? tag;

  /// Tag color.
  final TagTone? tagTone;

  /// New student added during this session.
  final bool isNew;

  /// Session id this compensation covers, if any.
  final String? compensationFor;

  /// Copy; pass `null` explicitly to clear a nullable field.
  SessionRecord copyWith({
    Object? attendance = _keep,
    Object? homework = _keep,
    Object? exam = _keep,
    String? note,
    Object? tag = _keep,
    Object? tagTone = _keep,
    bool? isNew,
    Object? compensationFor = _keep,
  }) {
    return SessionRecord(
      attendance: identical(attendance, _keep)
          ? this.attendance
          : attendance as Attendance?,
      homework: identical(homework, _keep)
          ? this.homework
          : homework as Homework?,
      exam: identical(exam, _keep) ? this.exam : exam as double?,
      note: note ?? this.note,
      tag: identical(tag, _keep) ? this.tag : tag as String?,
      tagTone: identical(tagTone, _keep) ? this.tagTone : tagTone as TagTone?,
      isNew: isNew ?? this.isNew,
      compensationFor: identical(compensationFor, _keep)
          ? this.compensationFor
          : compensationFor as String?,
    );
  }

  /// JSON map.
  Map<String, dynamic> toJson() => {
    'attendance': attendance?.name,
    'homework': homework?.name,
    'exam': exam,
    'note': note,
    'tag': tag,
    'tagTone': tagTone?.name,
    'isNew': isNew,
    'compensationFor': compensationFor,
  };

  /// Reads from JSON.
  factory SessionRecord.fromJson(Map<String, dynamic> j) => SessionRecord(
    attendance: _byName(Attendance.values, j['attendance']),
    homework: _byName(Homework.values, j['homework']),
    exam: (j['exam'] as num?)?.toDouble(),
    note: (j['note'] as String?) ?? '',
    tag: j['tag'] as String?,
    tagTone: _byName(TagTone.values, j['tagTone']),
    isNew: (j['isNew'] as bool?) ?? false,
    compensationFor: j['compensationFor'] as String?,
  );
}

/// One class meeting of a group.
class Session {
  /// Creates a session.
  const Session({
    required this.id,
    required this.groupId,
    required this.date,
    required this.number,
    required this.month,
    required this.status,
    required this.order,
    required this.records,
    required this.createdAtMs,
    this.noExam = false,
    this.examMax = 20,
    this.notes = '',
    this.syncedAt,
  });

  /// Unique id.
  final String id;

  /// Group id.
  final String groupId;

  /// `yyyy-MM-dd`.
  final String date;

  /// Number within the month (1..4).
  final int number;

  /// Month counter of the group (1, 2, 3, ...).
  final int month;

  /// Open (in progress) or closed (saved).
  final SessionStatus status;

  /// Student ids in display order.
  final List<String> order;

  /// Records keyed by student id.
  final Map<String, SessionRecord> records;

  /// Creation time in ms.
  final int createdAtMs;

  /// No exam in this session.
  final bool noExam;

  /// Maximum exam score.
  final int examMax;

  /// Session-level notes.
  final String notes;

  /// Upload time in ms, or null while pending (closed sessions only).
  final int? syncedAt;

  /// Record of [studentId] (empty when none).
  SessionRecord recordOf(String studentId) =>
      records[studentId] ?? const SessionRecord();

  /// Copy with a few fields replaced.
  Session copyWith({
    SessionStatus? status,
    List<String>? order,
    Map<String, SessionRecord>? records,
    bool? noExam,
    int? examMax,
    String? notes,
    Object? syncedAt = _keep,
  }) {
    return Session(
      id: id,
      groupId: groupId,
      date: date,
      number: number,
      month: month,
      status: status ?? this.status,
      order: order ?? this.order,
      records: records ?? this.records,
      createdAtMs: createdAtMs,
      noExam: noExam ?? this.noExam,
      examMax: examMax ?? this.examMax,
      notes: notes ?? this.notes,
      syncedAt: identical(syncedAt, _keep) ? this.syncedAt : syncedAt as int?,
    );
  }

  /// JSON map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'groupId': groupId,
    'date': date,
    'number': number,
    'month': month,
    'status': status.name,
    'order': order,
    'records': records.map((k, v) => MapEntry(k, v.toJson())),
    'createdAtMs': createdAtMs,
    'noExam': noExam,
    'examMax': examMax,
    'notes': notes,
    'syncedAt': syncedAt,
  };

  /// Reads from JSON.
  factory Session.fromJson(Map<String, dynamic> j) => Session(
    id: j['id'] as String,
    groupId: j['groupId'] as String,
    date: j['date'] as String,
    number: j['number'] as int,
    month: j['month'] as int,
    status: _byName(SessionStatus.values, j['status']) ?? SessionStatus.closed,
    order: (j['order'] as List<dynamic>).cast<String>(),
    records: (j['records'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, SessionRecord.fromJson(v as Map<String, dynamic>)),
    ),
    createdAtMs: j['createdAtMs'] as int,
    noExam: (j['noExam'] as bool?) ?? false,
    examMax: (j['examMax'] as int?) ?? 20,
    notes: (j['notes'] as String?) ?? '',
    syncedAt: j['syncedAt'] as int?,
  );
}

/// A payment made by a student for one month.
class Payment {
  /// Creates a payment.
  const Payment({
    required this.id,
    required this.studentId,
    required this.month,
    required this.amount,
    required this.method,
    required this.date,
    required this.createdAtMs,
    this.syncedAt,
  });

  /// Unique id.
  final String id;

  /// Student id.
  final String studentId;

  /// Month counter this payment covers.
  final int month;

  /// Positive whole EGP.
  final int amount;

  /// Method.
  final PayMethod method;

  /// `yyyy-MM-dd`.
  final String date;

  /// Creation time in ms.
  final int createdAtMs;

  /// Upload time in ms, or null while pending.
  final int? syncedAt;

  /// Copy marking the upload time.
  Payment withSyncedAt(int? ms) => Payment(
    id: id,
    studentId: studentId,
    month: month,
    amount: amount,
    method: method,
    date: date,
    createdAtMs: createdAtMs,
    syncedAt: ms,
  );

  /// JSON map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'studentId': studentId,
    'month': month,
    'amount': amount,
    'method': method.name,
    'date': date,
    'createdAtMs': createdAtMs,
    'syncedAt': syncedAt,
  };

  /// Reads from JSON.
  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
    id: j['id'] as String,
    studentId: j['studentId'] as String,
    month: j['month'] as int,
    amount: j['amount'] as int,
    method: _byName(PayMethod.values, j['method']) ?? PayMethod.cash,
    date: j['date'] as String,
    createdAtMs: j['createdAtMs'] as int,
    syncedAt: j['syncedAt'] as int?,
  );
}

/// Stored PIN verifier.
class PinData {
  /// Creates the verifier.
  const PinData({required this.salt, required this.hash});

  /// Hex salt.
  final String salt;

  /// Hex hash.
  final String hash;

  /// JSON map.
  Map<String, dynamic> toJson() => {'salt': salt, 'hash': hash};

  /// Reads from JSON.
  factory PinData.fromJson(Map<String, dynamic> j) =>
      PinData(salt: j['salt'] as String, hash: j['hash'] as String);
}
