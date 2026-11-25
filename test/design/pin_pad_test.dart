import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:assistant/core/design/theme.dart';
import 'package:assistant/core/design/widgets/pin_dots.dart';
import 'package:assistant/core/design/widgets/pin_pad.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: buildMnaraTheme(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('PinPad', () {
    testWidgets('reports digits and backspace', (tester) async {
      final digits = <String>[];
      var backspaces = 0;
      await tester.pumpWidget(
        _host(
          PinPad(onDigit: digits.add, onBackspace: () => backspaces++),
        ),
      );

      await tester.tap(find.text('1'));
      await tester.tap(find.text('0'));
      await tester.tap(find.byIcon(Icons.backspace_outlined));

      expect(digits, ['1', '0']);
      expect(backspaces, 1);
    });

    testWidgets('ignores taps while disabled', (tester) async {
      final digits = <String>[];
      var backspaces = 0;
      await tester.pumpWidget(
        _host(
          PinPad(
            enabled: false,
            onDigit: digits.add,
            onBackspace: () => backspaces++,
          ),
        ),
      );

      await tester.tap(find.text('5'));
      await tester.tap(find.byIcon(Icons.backspace_outlined));

      expect(digits, isEmpty);
      expect(backspaces, 0);
    });
  });

  group('PinDots', () {
    testWidgets('exposes progress through semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const PinDots(filled: 2)));

      expect(
        tester.getSemantics(find.byType(PinDots)),
        matchesSemantics(label: 'أرقام الـ PIN المدخلة', value: '2 من 4'),
      );
      handle.dispose();
    });

    testWidgets('shake does not throw when the token changes', (tester) async {
      await tester.pumpWidget(_host(const PinDots(filled: 0)));
      await tester.pumpWidget(_host(const PinDots(filled: 0, shakeToken: 1)));
      await tester.pump(const Duration(milliseconds: 450));

      expect(tester.takeException(), isNull);
    });
  });
}
