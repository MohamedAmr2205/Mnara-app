import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:assistant/core/design/theme.dart';
import 'package:assistant/core/design/widgets/app_nav_bar.dart';
import 'package:assistant/core/design/widgets/code_badge.dart';
import 'package:assistant/core/design/widgets/primary_button.dart';
import 'package:assistant/core/design/widgets/status_chip.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: buildMnaraTheme(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('PrimaryButton fires onPressed when enabled', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(PrimaryButton(label: 'ابدأ الحصة', onPressed: () => taps++)),
    );

    await tester.tap(find.text('ابدأ الحصة'));

    expect(taps, 1);
  });

  testWidgets('PrimaryButton is inert when onPressed is null', (tester) async {
    await tester.pumpWidget(
      _host(const PrimaryButton(label: 'ابدأ الحصة', onPressed: null)),
    );

    await tester.tap(find.text('ابدأ الحصة'));

    expect(tester.takeException(), isNull);
    expect(find.text('ابدأ الحصة'), findsOneWidget);
  });

  testWidgets('StatusChip always renders its text label', (tester) async {
    await tester.pumpWidget(
      _host(const StatusChip(label: 'مدفوع', tone: StatusTone.green)),
    );

    expect(find.text('مدفوع'), findsOneWidget);
  });

  testWidgets('CodeBadge shows the code', (tester) async {
    await tester.pumpWidget(_host(const CodeBadge(code: 'S101')));

    expect(find.text('S101'), findsOneWidget);
  });

  testWidgets('AppNavBar reports the tapped tab index', (tester) async {
    int? tapped;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMnaraTheme(),
        home: Scaffold(
          bottomNavigationBar: AppNavBar(
            currentIndex: 0,
            onTap: (i) => tapped = i,
          ),
        ),
      ),
    );

    await tester.tap(find.text('السجل'));

    expect(tapped, 2);
    for (final label in ['المجاميع', 'بحث', 'السجل', 'الإعدادات']) {
      expect(find.text(label), findsOneWidget);
    }
  });
}
