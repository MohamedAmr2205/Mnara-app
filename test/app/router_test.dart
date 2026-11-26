import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:assistant/app/app.dart';
import 'package:assistant/core/security/auth_controller.dart';

import '../support/fakes.dart';

void main() {
  testWidgets('a fresh install lands on the sign-in screen', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: testOverrides(), child: const MnaraApp()));
    await tester.pumpAndSettle();

    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('المجاميع'), findsNothing);
  });

  testWidgets('with a saved session and PIN the app opens on the PIN screen, not the groups', (tester) async {
    final repo = FakeRepository(groups: [sampleGroup()]);
    final gateway = FakeAuthGateway();
    final container = ProviderContainer(overrides: testOverrides(repo: repo, gateway: gateway));
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const MnaraApp()));
    await tester.pumpAndSettle();

    final auth = container.read(authControllerProvider.notifier);
    await auth.signIn('a@b.com', 'secret123');
    await tester.pumpAndSettle();
    expect(find.text('اختار PIN جديد'), findsOneWidget);
  });
}
