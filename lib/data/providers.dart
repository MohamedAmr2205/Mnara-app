import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:assistant/core/security/auth_controller.dart';
import 'package:assistant/data/firestore_repository.dart';
import 'package:assistant/data/models/models.dart';
import 'package:assistant/data/repository.dart';

/// Repository for the signed-in teacher (overridden in tests).
final dataRepositoryProvider = Provider<DataRepository>((ref) {
  final auth = ref.watch(authControllerProvider);
  final tid = auth.teacherId;
  final uid = auth.uid;
  if (tid == null || uid == null) {
    throw StateError('Repository requested before sign-in');
  }
  return FirestoreRepository(teacherId: tid, uid: uid);
});

/// Teacher document.
final teacherProvider = StreamProvider<Teacher?>(
  (ref) => ref.watch(dataRepositoryProvider).watchTeacher(),
);

/// Active groups.
final groupsProvider = StreamProvider<List<Group>>(
  (ref) => ref.watch(dataRepositoryProvider).watchGroups(),
);

/// All students.
final studentsProvider = StreamProvider<List<Student>>(
  (ref) => ref.watch(dataRepositoryProvider).watchStudents(),
);

/// All cached sessions (newest date first).
final sessionsProvider = StreamProvider<List<Session>>(
  (ref) => ref.watch(dataRepositoryProvider).watchSessions(),
);

/// All payments.
final paymentsProvider = StreamProvider<List<Payment>>(
  (ref) => ref.watch(dataRepositoryProvider).watchPayments(),
);

/// App metadata.
final metaProvider = StreamProvider<AppMeta>(
  (ref) => ref.watch(dataRepositoryProvider).watchMeta(),
);

/// Records of one session.
final sessionRecordsProvider =
    StreamProvider.family<List<SessionRecord>, String>(
      (ref, sessionId) =>
          ref.watch(dataRepositoryProvider).watchRecords(sessionId),
    );

/// Records of one student across all sessions.
final studentRecordsProvider =
    StreamProvider.family<List<SessionRecord>, String>(
      (ref, studentId) =>
          ref.watch(dataRepositoryProvider).watchStudentRecords(studentId),
    );

/// Whether the user dismissed the Resume card during this launch.
class ResumeDismissed extends Notifier<bool> {
  @override
  bool build() => false;

  /// Marks the card as handled.
  void dismiss() => state = true;
}

/// Resume card dismissal flag.
final resumeDismissedProvider = NotifierProvider<ResumeDismissed, bool>(
  ResumeDismissed.new,
);
