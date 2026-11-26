import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:assistant/core/security/auth_controller.dart';
import 'package:assistant/core/security/key_value_store.dart';
import 'package:assistant/core/sync/connectivity.dart';
import 'package:assistant/core/sync/sync_tracker.dart';
import 'package:assistant/core/utils/cairo_time.dart';
import 'package:assistant/data/models/models.dart';
import 'package:assistant/data/providers.dart';
import 'package:assistant/data/repository.dart';

/// Single entry point for writes that must show up on the Sync screen.
class WriteService {
  /// Creates the service.
  WriteService(this._ref);

  final Ref _ref;

  DataRepository get _repo => _ref.read(dataRepositoryProvider);
  SyncTracker get _tracker => _ref.read(syncTrackerProvider.notifier);

  /// Starts a session (fire-and-forget; resolves when the server confirms).
  void startSession(Session session, String groupName) {
    _tracker.track([
      TrackSpec(
        key: 'session:${session.id}',
        kind: SyncKind.session,
        title: '${session.label.split(' · ').first} · $groupName',
        subtitle: formatDm(session.date),
      ),
    ], () => _repo.startSession(session));
  }

  /// Finishes a session atomically and tracks the session, new students and
  /// their payments as separate rows.
  void finishSession(FinishPlan plan, {required String groupName, required int rosterSize}) {
    final s = plan.session;
    final specs = <TrackSpec>[
      TrackSpec(
        key: 'session:${s.id}',
        kind: SyncKind.session,
        title: '${s.label.split(' · ').first} · $groupName',
        subtitle: '$rosterSize طالب · ${formatDm(s.date)}',
      ),
      for (final n in plan.newStudents)
        if (!n.created)
          TrackSpec(
            key: 'student:${n.studentId}',
            kind: SyncKind.student,
            title: 'طالب جديد · ${n.code}',
            subtitle: 'مضاف في ${s.label.split(' · ').first}',
          ),
    ];
    _tracker.track(specs, () => _repo.finishSession(plan));
  }

  /// Saves edits of a finished session.
  void saveSessionEdits(Session session, String groupName) {
    _tracker.track([
      TrackSpec(
        key: 'session:${session.id}',
        kind: SyncKind.session,
        title: '${session.label.split(' · ').first} · $groupName',
        subtitle: 'تعديل · ${formatDm(session.date)}',
      ),
    ], () => _repo.saveSessionEdits(session));
  }

  /// Records a payment.
  void addPayment(Payment payment, String studentName) {
    _tracker.track([
      TrackSpec(
        key: 'payment:${payment.id}',
        kind: SyncKind.payment,
        title: 'دفعة $studentName · ${payment.amountEgp} ج',
        subtitle: '${payment.method.label} · ${formatDm(payment.paidOn)}',
      ),
    ], () => _repo.addPayment(payment));
  }

  /// Fire-and-forget record write; a rejection is reported as a failed item.
  void saveRecord(String sessionId, SessionRecord record, {required String title}) {
    _repo.saveRecord(sessionId, record).catchError((Object _) {
      _tracker.track([
        TrackSpec(
          key: 'record:$sessionId:${record.studentId}',
          kind: SyncKind.session,
          title: title,
          subtitle: 'تسجيل طالب',
        ),
      ], () => _repo.saveRecord(sessionId, record));
    });
  }

  /// Fire-and-forget record removal.
  void deleteRecord(String sessionId, String studentId) {
    _repo.deleteRecord(sessionId, studentId).catchError((Object _) {});
  }
}

/// Write service.
final writeServiceProvider = Provider<WriteService>(WriteService.new);

/// Persisted "auto upload" switch (default on).
class AutoUploadNotifier extends Notifier<bool> {
  static const _key = 'cfg.autoUpload';

  @override
  bool build() {
    Future<void>.microtask(_load);
    return true;
  }

  Future<void> _load() async {
    final saved = await ref.read(keyValueStoreProvider).read(_key);
    if (saved == 'off') {
      state = false;
      await _apply();
    }
  }

  Future<void> _apply() async {
    try {
      await ref.read(dataRepositoryProvider).setNetworkEnabled(state);
    } catch (_) {}
  }

  /// Turns automatic upload on or off.
  Future<void> set(bool value) async {
    state = value;
    await ref.read(keyValueStoreProvider).write(_key, value ? 'on' : 'off');
    await _apply();
  }
}

/// Auto-upload switch.
final autoUploadProvider = NotifierProvider<AutoUploadNotifier, bool>(
  AutoUploadNotifier.new,
);

/// Manual upload used by the Sync screen.
class SyncService {
  /// Creates the service.
  SyncService(this._ref);

  final Ref _ref;

  /// Retries failed items and waits for the queue to drain.
  Future<void> uploadNow() async {
    final repo = _ref.read(dataRepositoryProvider);
    final auto = _ref.read(autoUploadProvider);
    await repo.setNetworkEnabled(true);
    for (final i in _ref.read(syncItemsProvider)) {
      if (i.state == SyncState.failed) {
        _ref.read(syncTrackerProvider.notifier).retry(i.key);
      }
    }
    try {
      await repo.waitForPendingWrites().timeout(const Duration(seconds: 45));
    } catch (_) {
      // Still pending: the rows keep their state.
    } finally {
      if (!auto) await repo.setNetworkEnabled(false);
    }
  }

  /// Whether a manual upload can run right now.
  bool get canUpload => _ref.read(isOnlineProvider);
}

/// Manual sync service.
final syncServiceProvider = Provider<SyncService>(SyncService.new);
