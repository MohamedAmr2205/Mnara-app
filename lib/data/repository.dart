import 'package:assistant/data/models/models.dart';

/// Everything staged by the finish screen, committed as one atomic batch.
class FinishPlan {
  /// Creates a plan.
  const FinishPlan({
    required this.session,
    required this.newStudents,
    required this.groupId,
  });

  /// Session with its final notes and exam settings.
  final Session session;

  /// Students to create (and optionally their first payment).
  final List<NewStudentDraft> newStudents;

  /// Group the new students join.
  final String groupId;
}

/// Outcome of a code reconciliation run.
class ReconcileResult {
  /// Creates a result.
  const ReconcileResult(this.converted);

  /// Number of students that received a permanent code.
  final int converted;
}

/// Data access used by the whole app. The Firestore implementation relies on
/// the SDK's offline persistence; tests use an in-memory fake.
abstract class DataRepository {
  /// Teacher settings.
  Stream<Teacher?> watchTeacher();

  /// All active groups.
  Stream<List<Group>> watchGroups();

  /// All students.
  Stream<List<Student>> watchStudents();

  /// All cached sessions.
  Stream<List<Session>> watchSessions();

  /// Records of one session.
  Stream<List<SessionRecord>> watchRecords(String sessionId);

  /// Records of one student across all sessions.
  Stream<List<SessionRecord>> watchStudentRecords(String studentId);

  /// All payments.
  Stream<List<Payment>> watchPayments();

  /// App metadata.
  Stream<AppMeta> watchMeta();

  /// Creates a session and marks it active. Resolves when the server confirms.
  Future<void> startSession(Session session);

  /// Writes (or overwrites) a record. Resolves when the server confirms.
  Future<void> saveRecord(String sessionId, SessionRecord record);

  /// Removes a record.
  Future<void> deleteRecord(String sessionId, String studentId);

  /// Persists draft session settings.
  Future<void> updateSessionDraft(Session session);

  /// Finishes a session atomically.
  Future<void> finishSession(FinishPlan plan);

  /// Saves notes/exam settings of an already finished session (edit mode).
  Future<void> saveSessionEdits(Session session);

  /// Deletes an unfinished session and its records and clears the active id.
  Future<void> cancelSession(String sessionId);

  /// Records a payment.
  Future<void> addPayment(Payment payment);

  /// Converts temporary student codes to permanent ones (idempotent).
  Future<ReconcileResult> reconcileStudentCodes();

  /// Enables or disables network use (auto-upload switch).
  Future<void> setNetworkEnabled(bool enabled);

  /// Completes when every local write has reached the server.
  Future<void> waitForPendingWrites();
}
