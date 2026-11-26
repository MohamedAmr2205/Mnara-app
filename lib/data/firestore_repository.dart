import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:assistant/data/models/enums.dart';
import 'package:assistant/data/models/models.dart';
import 'package:assistant/data/repository.dart';
import 'package:assistant/domain/new_student.dart';

/// Firestore-backed [DataRepository] for one teacher.
///
/// Reads come from the SDK cache first (offline persistence); writes are
/// applied locally at once and uploaded by the SDK when the network allows.
class FirestoreRepository implements DataRepository {
  /// Creates the repository for [teacherId] acting as user [uid].
  FirestoreRepository({
    required this.teacherId,
    required this.uid,
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  /// Teacher document id.
  final String teacherId;

  /// Signed-in user id.
  final String uid;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _teacher =>
      _db.collection('teachers').doc(teacherId);

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _teacher.collection(name);

  DocumentReference<Map<String, dynamic>> get _meta =>
      _col('meta').doc('app');

  Stream<QuerySnapshot<Map<String, dynamic>>> _snaps(
    Query<Map<String, dynamic>> q,
  ) => q.snapshots(includeMetadataChanges: true);

  @override
  Stream<Teacher?> watchTeacher() => _teacher.snapshots().map(
    (s) => s.exists ? Teacher.fromMap(s.id, s.data()!) : null,
  );

  @override
  Stream<List<Group>> watchGroups() => _snaps(_col('groups')).map((s) {
    final list = [
      for (final d in s.docs) Group.fromMap(d.id, d.data()),
    ].where((g) => g.active).toList();
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  });

  @override
  Stream<List<Student>> watchStudents() => _snaps(_col('students')).map(
    (s) => [
      for (final d in s.docs)
        Student.fromMap(d.id, d.data(), pending: d.metadata.hasPendingWrites),
    ],
  );

  @override
  Stream<List<Session>> watchSessions() => _snaps(_col('sessions')).map((s) {
    final list = [
      for (final d in s.docs)
        Session.fromMap(d.id, d.data(), pending: d.metadata.hasPendingWrites),
    ];
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  });

  @override
  Stream<List<SessionRecord>> watchRecords(String sessionId) =>
      _snaps(_col('sessions').doc(sessionId).collection('records')).map(
        (s) => [
          for (final d in s.docs)
            SessionRecord.fromMap(sessionId, d.id, d.data()),
        ],
      );

  @override
  Stream<List<SessionRecord>> watchStudentRecords(String studentId) => _snaps(
    _db
        .collectionGroup('records')
        .where('teacherId', isEqualTo: teacherId)
        .where('studentId', isEqualTo: studentId),
  ).map(
    (s) => [
      for (final d in s.docs)
        SessionRecord.fromMap(
          d.reference.parent.parent?.id ?? '',
          d.id,
          d.data(),
        ),
    ],
  );

  @override
  Stream<List<Payment>> watchPayments() => _snaps(_col('payments')).map(
    (s) => [
      for (final d in s.docs)
        Payment.fromMap(d.id, d.data(), pending: d.metadata.hasPendingWrites),
    ],
  );

  @override
  Stream<AppMeta> watchMeta() => _meta.snapshots().map(
    (s) => AppMeta(activeSessionId: s.data()?['activeSessionId'] as String?),
  );

  // ---------- writes ----------

  Map<String, dynamic> _sessionMap(Session s, {bool create = false}) => {
    'groupId': s.groupId,
    'date': s.date,
    'number': s.number,
    'monthNumber': s.monthNumber,
    'status': s.status.key,
    'maxExam': s.noExam ? null : s.maxExam,
    'noExam': s.noExam,
    'notes': s.notes,
    'editableUntil': Timestamp.fromDate(s.editableUntil),
    if (create) ...{
      'startedAt': FieldValue.serverTimestamp(),
      'createdBy': uid,
    },
    if (s.finishedAt != null) 'finishedAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'updatedBy': uid,
  };

  Map<String, dynamic> _recordMap(SessionRecord r) => {
    'studentId': r.studentId,
    'teacherId': teacherId,
    'attendance': r.attendance!.key,
    'homework': r.homework?.key,
    'examScore': r.examScore,
    'note': r.note,
    'kind': r.kind.key,
    if (r.makeupForSessionId != null) ...{
      'makeupForSessionId': r.makeupForSessionId,
      'makeupForNumber': r.makeupForNumber,
      'makeupForMonth': r.makeupForMonth,
    },
    if (r.newStudent != null) 'newStudent': r.newStudent!.toMap(),
    'updatedAt': FieldValue.serverTimestamp(),
    'updatedBy': uid,
  };

  Map<String, dynamic> _paymentMap(Payment p) => {
    'studentId': p.studentId,
    'groupId': p.groupId,
    'month': p.month,
    'amountEgp': p.amountEgp,
    'method': p.method.key,
    'paidOn': p.paidOn,
    'createdBy': uid,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'updatedBy': uid,
  };

  @override
  Future<void> startSession(Session session) {
    final batch = _db.batch();
    batch.set(_col('sessions').doc(session.id), _sessionMap(session, create: true));
    batch.set(_meta, {'activeSessionId': session.id});
    return batch.commit();
  }

  @override
  Future<void> saveRecord(String sessionId, SessionRecord record) => _col(
    'sessions',
  ).doc(sessionId).collection('records').doc(record.studentId).set(_recordMap(record));

  @override
  Future<void> deleteRecord(String sessionId, String studentId) => _col(
    'sessions',
  ).doc(sessionId).collection('records').doc(studentId).delete();

  @override
  Future<void> updateSessionDraft(Session session) =>
      _col('sessions').doc(session.id).update({
        'maxExam': session.noExam ? null : session.maxExam,
        'noExam': session.noExam,
        'notes': session.notes,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });

  @override
  Future<void> finishSession(FinishPlan plan) {
    final batch = _db.batch();
    final s = plan.session;
    batch.update(_col('sessions').doc(s.id), {
      'status': SessionStatus.finished.key,
      'maxExam': s.noExam ? null : s.maxExam,
      'noExam': s.noExam,
      'notes': s.notes,
      'finishedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    });
    for (final n in plan.newStudents) {
      if (!n.created) {
        batch.set(_col('students').doc(n.studentId), {
          'code': n.code,
          'isTempCode': true,
          'name': n.name,
          'phone': normalizePhoneForStore(n.phone),
          'parentPhone': normalizePhoneForStore(n.parentPhone),
          'groupId': plan.groupId,
          'status': 'active',
          'addedInSessionId': s.id,
          'createdBy': uid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
        });
        if (n.pay != NewStudentPay.none && n.amountEgp > 0) {
          batch.set(
            _col('payments').doc(),
            _paymentMap(
              Payment(
                id: '',
                studentId: n.studentId,
                groupId: plan.groupId,
                month: s.monthNumber,
                amountEgp: n.amountEgp,
                method: n.method,
                paidOn: s.date,
              ),
            ),
          );
        }
      }
    }
    batch.set(_meta, {'activeSessionId': null});
    return batch.commit();
  }

  /// Phone numbers are already normalized by the form; kept as a hook.
  String normalizePhoneForStore(String phone) => phone;

  @override
  Future<void> saveSessionEdits(Session session) =>
      _col('sessions').doc(session.id).update({
        'maxExam': session.noExam ? null : session.maxExam,
        'noExam': session.noExam,
        'notes': session.notes,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });

  @override
  Future<void> cancelSession(String sessionId) async {
    final records = await _col('sessions')
        .doc(sessionId)
        .collection('records')
        .get(const GetOptions(source: Source.cache));
    final batch = _db.batch();
    for (final d in records.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_col('sessions').doc(sessionId));
    batch.set(_meta, {'activeSessionId': null});
    return batch.commit();
  }

  @override
  Future<void> addPayment(Payment payment) =>
      _col('payments').doc(payment.id).set(_paymentMap(payment));

  @override
  Future<ReconcileResult> reconcileStudentCodes() async {
    // Needs the server (transaction); silently skipped when offline.
    final temps = await _col('students')
        .where('isTempCode', isEqualTo: true)
        .get(const GetOptions(source: Source.cache));
    final docs = temps.docs.where((d) => !d.metadata.hasPendingWrites).toList()
      ..sort((a, b) {
        final x = readTime(a.data()['createdAt']);
        final y = readTime(b.data()['createdAt']);
        if (x == null || y == null) return 0;
        return x.compareTo(y);
      });
    var converted = 0;
    for (var i = 0; i < docs.length; i += 20) {
      final chunk = docs.skip(i).take(20).toList();
      final done = await _db.runTransaction<int>((tx) async {
        final teacherSnap = await tx.get(_teacher);
        final counters = teacherSnap.data()?['counters'];
        final counter = counters is Map && counters['student'] is num
            ? (counters['student'] as num).toInt()
            : 1000;
        final fresh = <DocumentSnapshot<Map<String, dynamic>>>[];
        for (final d in chunk) {
          final s = await tx.get(d.reference);
          if (s.exists && s.data()?['isTempCode'] == true) fresh.add(s);
        }
        if (fresh.isEmpty) return 0;
        final codes = assignPermanentCodes(counter, [for (final s in fresh) s.id]);
        tx.update(_teacher, {'counters.student': counter + fresh.length});
        for (final s in fresh) {
          tx.update(s.reference, {
            'code': codes[s.id],
            'isTempCode': false,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': uid,
          });
        }
        return fresh.length;
      });
      converted += done;
    }
    return ReconcileResult(converted);
  }

  @override
  Future<void> setNetworkEnabled(bool enabled) =>
      enabled ? _db.enableNetwork() : _db.disableNetwork();

  @override
  Future<void> waitForPendingWrites() => _db.waitForPendingWrites();
}
