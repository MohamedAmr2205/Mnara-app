import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:assistant/core/utils/cairo_time.dart';
import 'package:assistant/data/models/models.dart';

/// Settings read from the teacher document during the first online run.
class TeacherSettings {
  /// Creates the settings.
  const TeacherSettings({this.maxPinAttempts = 10, this.idleLockMinutes = 5});

  /// Wrong PIN attempts before lockout.
  final int maxPinAttempts;

  /// Idle minutes before the app locks itself.
  final int idleLockMinutes;
}

/// Fills the offline cache after the first sign-in and wipes it on logout.
abstract class CacheWarmer {
  /// Downloads the working set; throws when the server cannot be reached.
  Future<TeacherSettings> warm(String teacherId);

  /// Deletes every locally cached document.
  Future<void> wipe();
}

/// Firestore implementation.
class FirestoreCacheWarmer implements CacheWarmer {
  /// Creates the warmer.
  FirestoreCacheWarmer([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const _server = GetOptions(source: Source.server);

  @override
  Future<TeacherSettings> warm(String teacherId) async {
    final teacherRef = _db.collection('teachers').doc(teacherId);
    final teacherSnap = await teacherRef.get(_server);
    final teacher = Teacher.fromMap(teacherSnap.id, teacherSnap.data() ?? {});
    final cutoff = todayIso(DateTime.now().subtract(const Duration(days: 60)));
    await Future.wait([
      teacherRef.collection('groups').get(_server),
      teacherRef.collection('students').get(_server),
      teacherRef
          .collection('sessions')
          .where('date', isGreaterThanOrEqualTo: cutoff)
          .get(_server),
      teacherRef.collection('payments').get(_server),
      teacherRef.collection('meta').doc('app').get(_server),
      _db
          .collectionGroup('records')
          .where('teacherId', isEqualTo: teacherId)
          .get(_server),
    ]);
    return TeacherSettings(
      maxPinAttempts: teacher.maxPinAttempts,
      idleLockMinutes: teacher.idleLockMinutes,
    );
  }

  @override
  Future<void> wipe() async {
    await _db.terminate();
    await _db.clearPersistence();
  }
}
