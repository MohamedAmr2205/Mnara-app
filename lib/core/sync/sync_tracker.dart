import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:assistant/core/sync/connectivity.dart';
import 'package:assistant/core/utils/cairo_time.dart';
import 'package:assistant/data/models/models.dart';
import 'package:assistant/data/providers.dart';

/// Kind of item shown on the Sync screen.
enum SyncKind { session, payment, student }

/// Upload state of an item.
enum SyncState { ready, waiting, uploaded, failed }

/// One row on the Sync screen.
class SyncItem {
  /// Creates an item.
  const SyncItem({
    required this.key,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.state,
  });

  /// Stable key such as `session:<id>`.
  final String key;

  /// What the item is.
  final SyncKind kind;

  /// Main line.
  final String title;

  /// Secondary line.
  final String subtitle;

  /// Upload state.
  final SyncState state;

  /// Whether the item still needs to reach the server.
  bool get isPending => state != SyncState.uploaded;
}

/// Describes one item created by a tracked write.
class TrackSpec {
  /// Creates a spec.
  const TrackSpec({
    required this.key,
    required this.kind,
    required this.title,
    required this.subtitle,
  });

  /// Item key.
  final String key;

  /// Item kind.
  final SyncKind kind;

  /// Main line.
  final String title;

  /// Secondary line.
  final String subtitle;
}

enum TrackPhase { waiting, uploaded, failed }

class TrackedWrite {
  TrackedWrite(this.spec, this.phase, this.retry);

  final TrackSpec spec;
  final TrackPhase phase;
  final void Function() retry;
}

/// Tracks writes submitted during this app run.
///
/// A Firestore write future completes only when the server acknowledges it and
/// fails when the rules reject it, which is what drives the states here.
/// Writes left over from an earlier run are picked up through
/// `metadata.hasPendingWrites` in [syncItemsProvider].
class SyncTracker extends Notifier<List<TrackedWrite>> {
  @override
  List<TrackedWrite> build() => [];

  void _put(TrackSpec spec, TrackPhase phase, void Function() retry) {
    final next = [
      for (final t in state)
        if (t.spec.key != spec.key) t,
      TrackedWrite(spec, phase, retry),
    ];
    state = next;
  }

  /// Registers [specs] and runs [action] (not awaited by callers).
  void track(List<TrackSpec> specs, Future<void> Function() action) {
    void run() {
      for (final s in specs) {
        _put(s, TrackPhase.waiting, run);
      }
      action().then(
        (_) {
          for (final s in specs) {
            _put(s, TrackPhase.uploaded, run);
          }
        },
        onError: (Object _) {
          for (final s in specs) {
            _put(s, TrackPhase.failed, run);
          }
        },
      );
    }

    run();
  }

  /// Retries a failed item.
  void retry(String key) {
    for (final t in state) {
      if (t.spec.key == key && t.phase == TrackPhase.failed) {
        t.retry();
        return;
      }
    }
  }
}

/// Write tracker.
final syncTrackerProvider = NotifierProvider<SyncTracker, List<TrackedWrite>>(
  SyncTracker.new,
);

/// All items for the Sync screen: this run's writes plus leftovers.
final syncItemsProvider = Provider<List<SyncItem>>((ref) {
  final tracked = ref.watch(syncTrackerProvider);
  final online = ref.watch(isOnlineProvider);
  final sessions = ref.watch(sessionsProvider).valueOrNull ?? const <Session>[];
  final students = ref.watch(studentsProvider).valueOrNull ?? const <Student>[];
  final payments = ref.watch(paymentsProvider).valueOrNull ?? const <Payment>[];
  final groups = ref.watch(groupsProvider).valueOrNull ?? const <Group>[];

  final items = <SyncItem>[];
  final keys = <String>{};
  SyncState pendingState() => online ? SyncState.ready : SyncState.waiting;

  for (final t in tracked) {
    keys.add(t.spec.key);
    items.add(
      SyncItem(
        key: t.spec.key,
        kind: t.spec.kind,
        title: t.spec.title,
        subtitle: t.spec.subtitle,
        state: switch (t.phase) {
          TrackPhase.waiting => pendingState(),
          TrackPhase.uploaded => SyncState.uploaded,
          TrackPhase.failed => SyncState.failed,
        },
      ),
    );
  }

  String groupName(String id) {
    for (final g in groups) {
      if (g.id == id) return g.name;
    }
    return '';
  }

  String studentName(String id) {
    for (final s in students) {
      if (s.id == id) return s.name;
    }
    return '';
  }

  for (final s in sessions) {
    final key = 'session:${s.id}';
    if (s.pending && !keys.contains(key)) {
      items.add(
        SyncItem(
          key: key,
          kind: SyncKind.session,
          title: '${s.label.split(' · ').first} · ${groupName(s.groupId)}',
          subtitle: formatDm(s.date),
          state: pendingState(),
        ),
      );
    }
  }
  for (final p in payments) {
    final key = 'payment:${p.id}';
    if (p.pending && !keys.contains(key)) {
      items.add(
        SyncItem(
          key: key,
          kind: SyncKind.payment,
          title: 'دفعة ${studentName(p.studentId)} · ${p.amountEgp} ج',
          subtitle: '${p.method.label} · ${formatDm(p.paidOn)}',
          state: pendingState(),
        ),
      );
    }
  }
  for (final s in students) {
    final key = 'student:${s.id}';
    if (s.pending && !keys.contains(key)) {
      items.add(
        SyncItem(
          key: key,
          kind: SyncKind.student,
          title: 'طالب جديد · ${s.code}',
          subtitle: 'مضاف في الحصة',
          state: pendingState(),
        ),
      );
    }
  }
  return items;
});

/// Number of items that still need the server (including failed ones).
final pendingCountProvider = Provider<int>(
  (ref) => ref.watch(syncItemsProvider).where((i) => i.isPending).length,
);

/// Keys (`session:<id>`) of items not yet uploaded.
final pendingKeysProvider = Provider<Set<String>>(
  (ref) => {
    for (final i in ref.watch(syncItemsProvider))
      if (i.isPending) i.key,
  },
);
