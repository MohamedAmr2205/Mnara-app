import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:assistant/core/design/theme.dart';
import 'package:assistant/core/firebase/cache_warmer.dart';
import 'package:assistant/core/security/auth_controller.dart';
import 'package:assistant/core/security/auth_gateway.dart';
import 'package:assistant/core/security/key_value_store.dart';
import 'package:assistant/core/sync/connectivity.dart';
import 'package:assistant/data/models/enums.dart';
import 'package:assistant/data/models/models.dart';
import 'package:assistant/data/providers.dart';
import 'package:assistant/data/repository.dart';

/// In-memory [DataRepository] used by widget and provider tests.
class FakeRepository implements DataRepository {
  /// Creates a repository with optional seed data.
  FakeRepository({
    this.teacher = const Teacher(id: 't1', name: 'مستر أحمد'),
    List<Group>? groups,
    List<Student>? students,
    List<Session>? sessions,
    List<Payment>? payments,
  }) : groups = groups ?? [],
       students = students ?? [],
       sessions = {for (final s in sessions ?? <Session>[]) s.id: s},
       payments = payments ?? [];

  Teacher teacher;
  final List<Group> groups;
  final List<Student> students;
  final Map<String, Session> sessions;
  final Map<String, Map<String, SessionRecord>> records = {};
  final List<Payment> payments;
  AppMeta meta = const AppMeta();
  bool networkEnabled = true;
  int finishCalls = 0;
  FinishPlan? lastPlan;

  final _changes = StreamController<void>.broadcast();

  void _notify() => _changes.add(null);

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  /// Seeds a record directly (tests).
  void seedRecord(String sessionId, SessionRecord r) {
    records.putIfAbsent(sessionId, () => {})[r.studentId] = r;
    _notify();
  }

  @override
  Stream<Teacher?> watchTeacher() => _watch(() => teacher);

  @override
  Stream<List<Group>> watchGroups() => _watch(() => List.of(groups));

  @override
  Stream<List<Student>> watchStudents() => _watch(() => List.of(students));

  @override
  Stream<List<Session>> watchSessions() => _watch(() {
    final list = sessions.values.toList()..sort((a, b) => b.date.compareTo(a.date));
    return list;
  });

  @override
  Stream<List<SessionRecord>> watchRecords(String sessionId) =>
      _watch(() => (records[sessionId] ?? {}).values.toList());

  @override
  Stream<List<SessionRecord>> watchStudentRecords(String studentId) => _watch(() {
    final out = <SessionRecord>[];
    records.forEach((sid, map) {
      final r = map[studentId];
      if (r != null) out.add(SessionRecord(studentId: r.studentId, sessionId: sid, attendance: r.attendance, homework: r.homework, examScore: r.examScore, note: r.note, kind: r.kind, makeupForSessionId: r.makeupForSessionId, makeupForNumber: r.makeupForNumber, makeupForMonth: r.makeupForMonth));
    });
    return out;
  });

  @override
  Stream<List<Payment>> watchPayments() => _watch(() => List.of(payments));

  @override
  Stream<AppMeta> watchMeta() => _watch(() => meta);

  @override
  Future<void> startSession(Session session) async {
    sessions[session.id] = session;
    meta = AppMeta(activeSessionId: session.id);
    _notify();
  }

  @override
  Future<void> saveRecord(String sessionId, SessionRecord record) async {
    records.putIfAbsent(sessionId, () => {})[record.studentId] = record;
    _notify();
  }

  @override
  Future<void> deleteRecord(String sessionId, String studentId) async {
    records[sessionId]?.remove(studentId);
    _notify();
  }

  @override
  Future<void> updateSessionDraft(Session session) async {
    sessions[session.id] = session;
    _notify();
  }

  @override
  Future<void> saveSessionEdits(Session session) async {
    sessions[session.id] = session;
    _notify();
  }

  @override
  Future<void> finishSession(FinishPlan plan) async {
    finishCalls++;
    lastPlan = plan;
    sessions[plan.session.id] = plan.session;
    for (final n in plan.newStudents) {
      students.add(
        Student(
          id: n.studentId,
          code: n.code,
          isTempCode: true,
          name: n.name,
          phone: n.phone,
          parentPhone: n.parentPhone,
          groupId: plan.groupId,
          addedInSessionId: plan.session.id,
        ),
      );
      if (n.pay != NewStudentPay.none) {
        payments.add(
          Payment(
            id: 'p-${n.studentId}',
            studentId: n.studentId,
            groupId: plan.groupId,
            month: plan.session.monthNumber,
            amountEgp: n.amountEgp,
            method: n.method,
            paidOn: plan.session.date,
          ),
        );
      }
    }
    meta = const AppMeta();
    _notify();
  }

  @override
  Future<void> cancelSession(String sessionId) async {
    records.remove(sessionId);
    sessions.remove(sessionId);
    meta = const AppMeta();
    _notify();
  }

  @override
  Future<void> addPayment(Payment payment) async {
    payments.add(payment);
    _notify();
  }

  @override
  Future<ReconcileResult> reconcileStudentCodes() async => const ReconcileResult(0);

  @override
  Future<void> setNetworkEnabled(bool enabled) async => networkEnabled = enabled;

  @override
  Future<void> waitForPendingWrites() async {}
}

/// Connectivity source with a controllable value.
class FakeConnectivity implements ConnectivitySource {
  /// Creates the source.
  FakeConnectivity({this.online = true});

  bool online;
  final _controller = StreamController<bool>.broadcast();

  @override
  Stream<bool> get changes => _controller.stream;

  @override
  Future<bool> check() async => online;

  /// Changes reachability and notifies listeners.
  void set(bool value) {
    online = value;
    _controller.add(value);
  }
}

/// Auth gateway with scripted behaviour.
class FakeAuthGateway implements AuthGateway {
  /// Creates the gateway.
  FakeAuthGateway({this.user, this.password = 'secret123', this.teacherId = 't1'});

  AuthUser? user;
  String password;
  String? teacherId;
  bool signedOut = false;

  @override
  AuthUser? get currentUser => user;

  @override
  Future<AuthUser> signIn(String email, String pass) async {
    if (pass != password) throw const AuthFailure('الإيميل أو الباسورد غلط');
    user = AuthUser(uid: 'u1', email: email);
    return user!;
  }

  @override
  Future<void> reauthenticate(String pass) async {
    if (pass != password) throw const AuthFailure('الإيميل أو الباسورد غلط');
  }

  @override
  Future<String?> fetchTeacherId(String uid) async => teacherId;

  @override
  Future<void> signOut() async {
    signedOut = true;
    user = null;
  }
}

/// Cache warmer that records calls.
class FakeCacheWarmer implements CacheWarmer {
  int warmCalls = 0;
  bool fail = false;
  bool wiped = false;

  @override
  Future<TeacherSettings> warm(String teacherId) async {
    warmCalls++;
    if (fail) throw Exception('offline');
    return const TeacherSettings();
  }

  @override
  Future<void> wipe() async => wiped = true;
}

/// Provider overrides for tests.
List<Override> testOverrides({
  FakeRepository? repo,
  FakeConnectivity? connectivity,
  FakeAuthGateway? gateway,
  FakeCacheWarmer? warmer,
  MemoryKeyValueStore? store,
}) {
  return [
    if (repo != null) dataRepositoryProvider.overrideWithValue(repo),
    connectivitySourceProvider.overrideWithValue(connectivity ?? FakeConnectivity()),
    keyValueStoreProvider.overrideWithValue(store ?? MemoryKeyValueStore()),
    authGatewayProvider.overrideWithValue(gateway ?? FakeAuthGateway()),
    cacheWarmerProvider.overrideWithValue(warmer ?? FakeCacheWarmer()),
  ];
}

/// Wraps [child] in an Arabic, dark-themed MaterialApp inside a ProviderScope.
Widget testApp(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: buildMnaraTheme(),
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [Locale('ar', 'EG')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

/// Like [testApp] but without its own ProviderScope (for UncontrolledProviderScope).
Widget testAppBody(Widget child) {
  return MaterialApp(
    theme: buildMnaraTheme(),
    locale: const Locale('ar', 'EG'),
    supportedLocales: const [Locale('ar', 'EG')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}

/// A group on Wednesdays.
Group sampleGroup({String id = 'g1', String name = 'لغات أولى'}) => Group(
  id: id,
  name: name,
  gradeLabel: 'أولى ثانوي',
  dayOfWeek: 3,
  timeLabel: '6:00 م',
);

/// A student of [groupId].
Student sampleStudent(String id, String name, {String groupId = 'g1', String? code}) => Student(
  id: id,
  code: code ?? 'S${1000 + id.hashCode.abs() % 1000}',
  isTempCode: false,
  name: name,
  phone: '01012345678',
  parentPhone: '01112345678',
  groupId: groupId,
);

/// A session of group `g1`.
Session sampleSession({
  String id = 'x1',
  String date = '2026-11-25',
  int number = 3,
  int month = 2,
  SessionStatus status = SessionStatus.open,
  DateTime? editableUntil,
  bool pending = false,
}) => Session(
  id: id,
  groupId: 'g1',
  date: date,
  number: number,
  monthNumber: month,
  status: status,
  editableUntil: editableUntil ?? DateTime.now().add(const Duration(days: 5)),
  pending: pending,
);
