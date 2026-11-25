import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:assistant/app/app.dart';
import 'package:assistant/app/router.dart';

void main() {
  testWidgets('starts on the PIN lock route', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MnaraApp()));
    await tester.pumpAndSettle();

    expect(find.text('دخول بالـ PIN'), findsOneWidget);
    expect(find.text('المجاميع'), findsNothing);
  });

  testWidgets('tabs show the bottom nav and switch branches', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MnaraApp()));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).go(AppRoutes.groups);
    await tester.pumpAndSettle();

    expect(find.text('الشاشة دي هتتبني في M3'), findsOneWidget);

    await tester.tap(find.text('بحث'));
    await tester.pumpAndSettle();

    expect(find.text('بحث عن طالب'), findsOneWidget);
  });

  testWidgets('session routes hide the bottom nav', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MnaraApp()));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).go('/session/abc');
    await tester.pumpAndSettle();

    expect(find.text('الحصة'), findsOneWidget);
    expect(find.text('الإعدادات'), findsNothing);
  });
}
