import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:assistant/data/models/enums.dart';
import 'package:assistant/data/models/models.dart';
import 'package:assistant/features/student/payment_screen.dart';

import '../support/fakes.dart';

FakeRepository _repo({List<Payment> payments = const []}) => FakeRepository(
  groups: [sampleGroup()],
  students: [sampleStudent('s1', 'يوسف عادل', code: 'S1001')],
  sessions: [sampleSession()], // month 2
  payments: [...payments],
);

Future<void> _pump(WidgetTester tester, FakeRepository repo) async {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(testApp(const PaymentScreen(sid: 's1'), overrides: testOverrides(repo: repo)));
  await tester.pumpAndSettle();
}

Finder get _amountField => find.byType(TextField).first;

void main() {
  testWidgets('defaults to the current month and pre-fills the remaining amount', (tester) async {
    await _pump(tester, _repo());
    expect(find.text('700 ج'), findsWidgets);
    expect(find.widgetWithText(TextField, '700'), findsOneWidget);
    expect(find.text('الدفعة دي هتكمّل الشهر'), findsOneWidget);
  });

  testWidgets('an amount above the remaining shows the error and blocks saving', (tester) async {
    final repo = _repo();
    await _pump(tester, repo);
    await tester.enterText(_amountField, '900');
    await tester.pumpAndSettle();
    expect(find.text('المبلغ أكبر من المتبقي (700 جنيه)'), findsOneWidget);
    await tester.tap(find.text('حفظ الدفعة'));
    await tester.pumpAndSettle();
    expect(repo.payments, isEmpty);
  });

  testWidgets('a partial payment shows what is left and saves an integer amount', (tester) async {
    final repo = _repo();
    await _pump(tester, repo);
    await tester.enterText(_amountField, '٣٠٠');
    await tester.pumpAndSettle();
    expect(find.text('دفعة جزئية · هيفضل 400 جنيه'), findsOneWidget);

    await tester.tap(find.text('إنستاباي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ الدفعة'));
    await tester.pumpAndSettle();

    expect(repo.payments, hasLength(1));
    final p = repo.payments.single;
    expect((p.amountEgp, p.method, p.month), (300, PayMethod.instapay, 2));
    expect(find.text('اتسجّلت الدفعة'), findsOneWidget);
    expect(find.text('هيفضل 400 جنيه'), findsOneWidget);
  });

  testWidgets('a fully paid month disables the form', (tester) async {
    final repo = _repo(
      payments: const [
        Payment(id: 'p', studentId: 's1', groupId: 'g1', month: 2, amountEgp: 700, method: PayMethod.cash, paidOn: '2026-11-01'),
      ],
    );
    await _pump(tester, repo);
    expect(find.text('الشهر ده مدفوع بالكامل. اختار شهر تاني.'), findsOneWidget);
    await tester.tap(find.text('حفظ الدفعة'));
    await tester.pumpAndSettle();
    expect(repo.payments, hasLength(1));
  });

  testWidgets('an invalid date blocks saving', (tester) async {
    final repo = _repo();
    await _pump(tester, repo);
    await tester.enterText(find.byType(TextField).at(1), '99/99/2026');
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ الدفعة'));
    await tester.pumpAndSettle();
    expect(repo.payments, isEmpty);
  });
}
