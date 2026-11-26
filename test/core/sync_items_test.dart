import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:assistant/core/sync/sync_tracker.dart';
import 'package:assistant/data/models/enums.dart';
import 'package:assistant/data/models/models.dart';
import 'package:assistant/data/providers.dart';

import '../support/fakes.dart';

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

ProviderContainer _make(FakeRepository repo, FakeConnectivity conn) {
  final c = ProviderContainer(overrides: testOverrides(repo: repo, connectivity: conn));
  addTearDown(c.dispose);
  return c;
}

Future<void> _prime(ProviderContainer c) async {
  c.listen(syncItemsProvider, (_, __) {});
  await _settle();
}

void main() {
  test('leftover pending sessions show as ready online and waiting offline', () async {
    final repo = FakeRepository(
      groups: [sampleGroup()],
      sessions: [sampleSession(pending: true), sampleSession(id: 'x2', pending: false)],
    );
    final conn = FakeConnectivity(online: true);
    final c = _make(repo, conn);
    await _prime(c);
    var items = c.read(syncItemsProvider);
    expect(items, hasLength(1));
    expect(items.single.state, SyncState.ready);
    expect(items.single.title, contains('لغات أولى'));
    expect(c.read(pendingCountProvider), 1);

    conn.set(false);
    await _settle();
    items = c.read(syncItemsProvider);
    expect(items.single.state, SyncState.waiting);
  });

  test('pending payments and students are listed with their details', () async {
    final repo = FakeRepository(
      groups: [sampleGroup()],
      students: [sampleStudent('s1', 'يوسف عادل', code: 'S1001')],
      payments: [
        const Payment(
          id: 'p1',
          studentId: 's1',
          groupId: 'g1',
          month: 2,
          amountEgp: 300,
          method: PayMethod.cash,
          paidOn: '2026-11-25',
          pending: true,
        ),
      ],
    );
    final c = _make(repo, FakeConnectivity());
    await _prime(c);
    final items = c.read(syncItemsProvider);
    expect(items.single.title, 'دفعة يوسف عادل · 300 ج');
    expect(items.single.subtitle, 'كاش · 25/11');
  });

  test('a tracked write moves waiting -> uploaded, and failed writes can be retried', () async {
    final repo = FakeRepository(groups: [sampleGroup()]);
    final c = _make(repo, FakeConnectivity());
    await _prime(c);
    final tracker = c.read(syncTrackerProvider.notifier);

    var attempts = 0;
    tracker.track(
      const [TrackSpec(key: 'payment:p9', kind: SyncKind.payment, title: 'دفعة', subtitle: 'x')],
      () async {
        attempts++;
        if (attempts == 1) throw Exception('permission-denied');
      },
    );
    await _settle();
    expect(c.read(syncItemsProvider).single.state, SyncState.failed);
    expect(c.read(pendingCountProvider), 1);

    tracker.retry('payment:p9');
    await _settle();
    expect(attempts, 2);
    expect(c.read(syncItemsProvider).single.state, SyncState.uploaded);
    expect(c.read(pendingCountProvider), 0);
  });

  test('a hanging write (offline) stays pending', () async {
    final repo = FakeRepository();
    final c = _make(repo, FakeConnectivity(online: false));
    await _prime(c);
    final never = Completer<void>().future;
    c.read(syncTrackerProvider.notifier).track(
      const [TrackSpec(key: 'session:x', kind: SyncKind.session, title: 'حصة', subtitle: 'x')],
      () => never,
    );
    await _settle();
    expect(c.read(syncItemsProvider).single.state, SyncState.waiting);
  });
}
