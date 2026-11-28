// ignore_for_file: always_use_package_imports
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:assistant/app/app.dart';
import 'package:assistant/app/router.dart';
import 'package:assistant/data/app_controller.dart';

import '../helpers.dart';

/// Pumps the whole app on a phone-sized surface with in-memory storage.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  bool unlock = false,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(() => testNow),
      ],
      child: const MnaraApp(),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MnaraApp)),
  );
  if (unlock) {
    container.read(unlockedProvider.notifier).state = true;
    await tester.pumpAndSettle();
  }
  return container;
}

Future<void> typePin(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.text(d));
    await tester.pump();
  }
}

void main() {
  testWidgets('locked app shows the PIN setup on first run', (tester) async {
    await pumpApp(tester);
    expect(find.text('اختار PIN جديد'), findsOneWidget);
    expect(find.text('مجاميع النهارده'), findsNothing);
  });

  testWidgets('first run: choose a PIN, confirm it, land on groups', (
    tester,
  ) async {
    await pumpApp(tester);

    await typePin(tester, '2580');
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    expect(find.text('أكّد الـ PIN'), findsOneWidget);

    await typePin(tester, '2580');
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();

    expect(find.text('مجاميع النهارده'), findsOneWidget);
  });

  testWidgets('weak PIN is refused', (tester) async {
    await pumpApp(tester);
    await typePin(tester, '1234');
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PIN سهل'), findsOneWidget);
    expect(find.text('اختار PIN جديد'), findsOneWidget);
  });

  testWidgets('wrong PIN shows the remaining attempts', (tester) async {
    final c = await pumpApp(tester);
    c.read(appProvider.notifier).setPin('2580');
    await tester.pumpAndSettle();
    expect(find.text('ادخل الـ PIN'), findsOneWidget);

    await typePin(tester, '1111');
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();

    expect(find.textContaining('باقي 9 محاولات'), findsOneWidget);
    expect(find.text('مجاميع النهارده'), findsNothing);
  });

  testWidgets('correct PIN unlocks', (tester) async {
    final c = await pumpApp(tester);
    c.read(appProvider.notifier).setPin('2580');
    await tester.pumpAndSettle();

    await typePin(tester, '2580');
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();

    expect(find.text('مجاميع النهارده'), findsOneWidget);
  });

  testWidgets('protected routes redirect to the lock screen', (tester) async {
    await pumpApp(tester);
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).go('/history');
    await tester.pumpAndSettle();
    expect(find.text('سجل الحصص'), findsNothing);
    expect(find.text('اختار PIN جديد'), findsOneWidget);
  });

  testWidgets('tabs switch and keep the bottom nav', (tester) async {
    await pumpApp(tester, unlock: true);
    expect(find.text('مجاميع النهارده'), findsOneWidget);

    await tester.tap(find.text('بحث'));
    await tester.pumpAndSettle();
    expect(find.text('بحث عن طالب'), findsOneWidget);

    await tester.tap(find.text('السجل'));
    await tester.pumpAndSettle();
    expect(find.text('سجل الحصص'), findsOneWidget);

    await tester.tap(find.text('الإعدادات'));
    await tester.pumpAndSettle();
    expect(find.text('تسجيل الخروج'), findsOneWidget);
  });

  testWidgets('session routes hide the bottom nav', (tester) async {
    final c = await pumpApp(tester, unlock: true);
    final gid = c.read(appProvider).groups.first.id;
    final xid = c.read(appProvider.notifier).startSession(gid);

    final context = tester.element(find.byType(Scaffold).first);
    unawaited(
      GoRouter.of(context).push(AppRoutes.session.replaceFirst(':xid', xid)),
    );
    await tester.pumpAndSettle();

    expect(find.text('إنهاء الحصة'), findsOneWidget);
    expect(find.text('الإعدادات'), findsNothing);
  });

  testWidgets('logging out returns to the lock screen', (tester) async {
    final c = await pumpApp(tester, unlock: true);
    c.read(appProvider.notifier).setPin('2580');
    // Nothing pending after the seed, so logout is immediate.
    await tester.tap(find.text('الإعدادات'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تسجيل الخروج'));
    await tester.pumpAndSettle();
    expect(find.text('ادخل الـ PIN'), findsOneWidget);
  });
}
