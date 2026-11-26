import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:assistant/core/sync/sync_tracker.dart';
import 'package:assistant/data/models/enums.dart';
import 'package:assistant/features/history/history_screen.dart';
import 'package:assistant/features/sync/sync_screen.dart';

import '../support/fakes.dart';

Future<void> _pump(WidgetTester tester, Widget screen, FakeRepository repo, {FakeConnectivity? conn}) async {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(testApp(screen, overrides: testOverrides(repo: repo, connectivity: conn)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('history: sessions inside the window can be edited, older ones are locked', (tester) async {
    final now = DateTime.now();
    final repo = FakeRepository(
      groups: [sampleGroup()],
      sessions: [
        sampleSession(id: 'new', status: SessionStatus.finished, editableUntil: now.add(const Duration(days: 4))),
        sampleSession(id: 'old', date: '2020-01-01', number: 1, month: 1, status: SessionStatus.finished, editableUntil: DateTime.utc(2020, 1, 11)),
      ],
    );
    await _pump(tester, const HistoryScreen(), repo);
    expect(find.text('تعديل'), findsOneWidget);
    expect(find.text('مقفولة · عدّى عليها أكتر من 10 أيام'), findsOneWidget);
    expect(find.textContaining('أيام للتعديل'), findsOneWidget);
  });

  testWidgets('history: pending sessions show the waiting chip', (tester) async {
    final repo = FakeRepository(
      groups: [sampleGroup()],
      sessions: [sampleSession(status: SessionStatus.finished, pending: true)],
    );
    await _pump(tester, const HistoryScreen(), repo);
    expect(find.text('مستنية النت'), findsOneWidget);
  });

  testWidgets('sync: offline with pending items', (tester) async {
    final repo = FakeRepository(groups: [sampleGroup()], sessions: [sampleSession(pending: true)]);
    await _pump(tester, const SyncScreen(), repo, conn: FakeConnectivity(online: false));
    expect(find.text('مفيش نت'), findsOneWidget);
    expect(find.text('1 مستنيين الرفع. كمّل شغلك عادي.'), findsOneWidget);
    expect(find.text('مستني النت'), findsOneWidget);
    expect(find.text('مستني النت عشان يرفع'), findsOneWidget);
  });

  testWidgets('sync: online with pending items offers to upload now', (tester) async {
    final repo = FakeRepository(groups: [sampleGroup()], sessions: [sampleSession(pending: true)]);
    await _pump(tester, const SyncScreen(), repo);
    expect(find.text('متصل'), findsOneWidget);
    expect(find.text('جاهز للرفع'), findsOneWidget);
    await tester.tap(find.text('ارفع دلوقتي'));
    await tester.pumpAndSettle();
    expect(repo.networkEnabled, isTrue);
  });

  testWidgets('sync: everything uploaded', (tester) async {
    final repo = FakeRepository(groups: [sampleGroup()]);
    await _pump(tester, const SyncScreen(), repo);
    expect(find.text('متصل · كله متزامن'), findsOneWidget);
    expect(find.text('مفيش حاجة للرفع'), findsOneWidget);
  });

  testWidgets('sync: a failed item shows the retry button and recovers', (tester) async {
    final repo = FakeRepository(groups: [sampleGroup()]);
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: testOverrides(repo: repo));
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: testAppBody(const SyncScreen())),
    );
    var attempts = 0;
    container.read(syncTrackerProvider.notifier).track(
      const [TrackSpec(key: 'payment:p1', kind: SyncKind.payment, title: 'دفعة يوسف · 300 ج', subtitle: 'كاش · 25/11')],
      () async {
        attempts++;
        if (attempts == 1) throw Exception('denied');
      },
    );
    await tester.pumpAndSettle();
    expect(find.text('فيه حاجة فشلت'), findsOneWidget);
    expect(find.text('فشل الرفع: السيرفر ما ردش. بياناتك سليمة على الموبايل.'), findsOneWidget);

    await tester.tap(find.text('حاول تاني').first);
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('فيه حاجة فشلت'), findsNothing);
  });
}
