import 'package:assistant/domain/models.dart';

const Object _keep = Object();

/// Everything the app stores (local-only mode).
class AppState {
  /// Creates the state.
  const AppState({
    required this.teacher,
    required this.groups,
    required this.students,
    required this.sessions,
    required this.payments,
    this.activeSessionId,
    this.pin,
    this.failedAttempts = 0,
    this.autoUpload = true,
    this.online = true,
    this.lastUploadAtMs,
    this.studentCounter = 1000,
    this.recentStudentIds = const [],
  });

  /// Teacher info and prices.
  final Teacher teacher;

  /// Groups.
  final List<Group> groups;

  /// All students (including those of other groups).
  final List<Student> students;

  /// All sessions (open and closed).
  final List<Session> sessions;

  /// All payments.
  final List<Payment> payments;

  /// Open session to resume after an app restart.
  final String? activeSessionId;

  /// PIN verifier; null until the first PIN is chosen.
  final PinData? pin;

  /// Consecutive wrong PIN attempts.
  final int failedAttempts;

  /// Upload automatically when the connection returns.
  final bool autoUpload;

  /// Simulated connectivity (local mode has no server).
  final bool online;

  /// Last upload time in ms.
  final int? lastUploadAtMs;

  /// Counter used to mint permanent student codes.
  final int studentCounter;

  /// Recently searched/opened student ids (newest first).
  final List<String> recentStudentIds;

  /// Copy with a few fields replaced; `Object?` fields accept explicit null.
  AppState copyWith({
    Teacher? teacher,
    List<Group>? groups,
    List<Student>? students,
    List<Session>? sessions,
    List<Payment>? payments,
    Object? activeSessionId = _keep,
    Object? pin = _keep,
    int? failedAttempts,
    bool? autoUpload,
    bool? online,
    Object? lastUploadAtMs = _keep,
    int? studentCounter,
    List<String>? recentStudentIds,
  }) {
    return AppState(
      teacher: teacher ?? this.teacher,
      groups: groups ?? this.groups,
      students: students ?? this.students,
      sessions: sessions ?? this.sessions,
      payments: payments ?? this.payments,
      activeSessionId: identical(activeSessionId, _keep)
          ? this.activeSessionId
          : activeSessionId as String?,
      pin: identical(pin, _keep) ? this.pin : pin as PinData?,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      autoUpload: autoUpload ?? this.autoUpload,
      online: online ?? this.online,
      lastUploadAtMs: identical(lastUploadAtMs, _keep)
          ? this.lastUploadAtMs
          : lastUploadAtMs as int?,
      studentCounter: studentCounter ?? this.studentCounter,
      recentStudentIds: recentStudentIds ?? this.recentStudentIds,
    );
  }

  /// JSON map.
  Map<String, dynamic> toJson() => {
    'teacher': teacher.toJson(),
    'groups': groups.map((g) => g.toJson()).toList(),
    'students': students.map((s) => s.toJson()).toList(),
    'sessions': sessions.map((s) => s.toJson()).toList(),
    'payments': payments.map((p) => p.toJson()).toList(),
    'activeSessionId': activeSessionId,
    'pin': pin?.toJson(),
    'failedAttempts': failedAttempts,
    'autoUpload': autoUpload,
    'online': online,
    'lastUploadAtMs': lastUploadAtMs,
    'studentCounter': studentCounter,
    'recentStudentIds': recentStudentIds,
  };

  /// Reads from JSON.
  factory AppState.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) read) =>
        (j[key] as List<dynamic>)
            .map((e) => read(e as Map<String, dynamic>))
            .toList();
    final pinJson = j['pin'] as Map<String, dynamic>?;
    return AppState(
      teacher: Teacher.fromJson(j['teacher'] as Map<String, dynamic>),
      groups: list('groups', Group.fromJson),
      students: list('students', Student.fromJson),
      sessions: list('sessions', Session.fromJson),
      payments: list('payments', Payment.fromJson),
      activeSessionId: j['activeSessionId'] as String?,
      pin: pinJson == null ? null : PinData.fromJson(pinJson),
      failedAttempts: (j['failedAttempts'] as int?) ?? 0,
      autoUpload: (j['autoUpload'] as bool?) ?? true,
      online: (j['online'] as bool?) ?? true,
      lastUploadAtMs: j['lastUploadAtMs'] as int?,
      studentCounter: (j['studentCounter'] as int?) ?? 1000,
      recentStudentIds:
          ((j['recentStudentIds'] as List<dynamic>?) ?? const <dynamic>[])
              .cast<String>(),
    );
  }
}
