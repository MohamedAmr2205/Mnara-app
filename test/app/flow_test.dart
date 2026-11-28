// ignore_for_file: always_use_package_imports
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:assistant/data/app_controller.dart';
import 'package:assistant/domain/logic.dart';
import 'package:assistant/domain/models.dart';

import 'router_test.dart' show pumpApp;

void main() {
  testWidgets('groups list shows the demo groups, today first', (tester) async {
    final c = await pumpApp(tester, unlock: true);
    final s = c.read(appProvider);
    expect(find.text('النهارده'), findsOneWidget);
    for (final g in s.groups) {
      expect(find.text(g.name), findsOneWidget);
    }
  });

  testWidgets('start, mark, finish and save a session', (tester) async {
    final c = await pumpApp(tester, unlock: true);
    final s0 = c.read(appProvider);
    final g = s0.groups.first;

    await tester.tap(find.text(g.name));
    await tester.pumpAndSettle();
    expect(find.text('ابدأ الحصة'), findsOneWidget);

    await tester.tap(find.text('ابدأ الحصة'));
    await tester.pumpAndSettle();
    expect(find.text('بدء حصة جديدة'), findsOneWidget);
    expect(find.textContaining('الحصة 3 · شهر 2'), findsOneWidget);

    await tester.tap(find.text('ابدأ الحصة دلوقتي'));
    await tester.pumpAndSettle();
    expect(find.text('إنهاء الحصة'), findsOneWidget);

    final xid = c.read(appProvider).activeSessionId!;
    final ctl = c.read(appProvider.notifier);
    final order = sessionById(c.read(appProvider), xid)!.order;
    ctl.setAttendance(xid, order[0], Attendance.present);
    ctl.setHomework(xid, order[0], Homework.good);
    ctl.setAttendance(xid, order[1], Attendance.absent);
    await tester.pumpAndSettle();

    await tester.tap(find.text('إنهاء الحصة'));
    await tester.pumpAndSettle();
    expect(find.text('إنهاء وحفظ الحصة'), findsOneWidget);
    expect(find.textContaining('لسه ما اتعلّموش'), findsOneWidget);

    await tester.tap(find.text('إنهاء وحفظ الحصة'));
    await tester.pumpAndSettle();
    expect(find.text('اتحفظت الحصة'), findsOneWidget);

    final saved = sessionById(c.read(appProvider), xid)!;
    expect(saved.status, SessionStatus.closed);
    expect(c.read(appProvider).activeSessionId, isNull);

    await tester.tap(find.text('رجوع للمجاميع'));
    await tester.pumpAndSettle();
    expect(find.text('مجاميع النهارده'), findsOneWidget);
  });

  testWidgets('an open session shows the resume card', (tester) async {
    final c = await pumpApp(tester, unlock: true);
    c.read(appProvider.notifier).startSession(
      c.read(appProvider).groups.first.id,
    );
    await tester.pumpAndSettle();
    expect(find.text('فيه حصة مفتوحة ما اتقفلتش'), findsOneWidget);
    expect(find.text('كمّل الحصة'), findsOneWidget);
  });

  testWidgets('search finds a student by code', (tester) async {
    await pumpApp(tester, unlock: true);
    await tester.tap(find.text('بحث'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'S101');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('S101'), findsOneWidget);
    expect(find.text('1 نتيجة'), findsOneWidget);
  });

  testWidgets('student profile opens from search', (tester) async {
    await pumpApp(tester, unlock: true);
    await tester.tap(find.text('بحث'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'S101');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.tap(find.text('S101'));
    await tester.pumpAndSettle();
    expect(find.text('بروفايل الطالب'), findsOneWidget);
    expect(find.text('تسجيل دفعة'), findsOneWidget);
  });

  testWidgets('recording a payment completes the month', (tester) async {
    final c = await pumpApp(tester, unlock: true);
    final s0 = c.read(appProvider);
    // A student with nothing paid for the current month (2).
    final st = s0.students.firstWhere((x) => paidFor(s0, x.id, 2) == 0);

    await tester.tap(find.text('بحث'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), st.code);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.text(st.code));
    await tester.pumpAndSettle();

    await tester.tap(find.text('تسجيل دفعة'));
    await tester.pumpAndSettle();
    expect(find.text('الدفعة دي هتكمّل الشهر'), findsOneWidget);

    await tester.tap(find.text('حفظ الدفعة'));
    await tester.pumpAndSettle();
    expect(find.text('اتسجّلت الدفعة'), findsOneWidget);
    expect(remainingFor(c.read(appProvider), st.id, 2), 0);
  });

  testWidgets('history lists saved sessions and locks the old ones', (
    tester,
  ) async {
    await pumpApp(tester, unlock: true);
    await tester.tap(find.text('السجل'));
    await tester.pumpAndSettle();
    expect(find.textContaining('باقي'), findsWidgets);
    expect(find.textContaining('مقفولة'), findsWidgets);
  });

  testWidgets('sync screen shows pending work after an offline edit', (
    tester,
  ) async {
    final c = await pumpApp(tester, unlock: true);
    final ctl = c.read(appProvider.notifier);
    ctl.setOnline(false);
    final xid = ctl.startSession(c.read(appProvider).groups.first.id);
    ctl.finishSession(xid, '');
    await tester.pumpAndSettle();
    expect(find.textContaining('مفيش نت'), findsWidgets);

    ctl.setOnline(true);
    await tester.pumpAndSettle();
    expect(pendingCount(c.read(appProvider)), 0);
  });
}
