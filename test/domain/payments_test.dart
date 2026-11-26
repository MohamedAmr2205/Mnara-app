import 'package:flutter_test/flutter_test.dart';

import 'package:assistant/data/models/enums.dart';
import 'package:assistant/data/models/models.dart';
import 'package:assistant/domain/payments.dart';

Payment _pay(int month, int amount) => Payment(
  id: '$month-$amount',
  studentId: 's1',
  groupId: 'g1',
  month: month,
  amountEgp: amount,
  method: PayMethod.cash,
  paidOn: '2026-11-25',
);

void main() {
  test('paid when payments reach the due amount', () {
    final m = monthPayment(month: 2, due: 700, payments: [_pay(2, 400), _pay(2, 300)], currentMonth: 2);
    expect(m.status, PayStatus.paid);
    expect(m.paid, 700);
    expect(m.remaining, 0);
  });

  test('partial when something was paid', () {
    final m = monthPayment(month: 2, due: 700, payments: [_pay(2, 175)], currentMonth: 2);
    expect(m.status, PayStatus.partial);
    expect(m.remaining, 525);
  });

  test('unpaid for a started month with no payments', () {
    expect(monthPayment(month: 2, due: 700, payments: [], currentMonth: 2).status, PayStatus.unpaid);
    expect(monthPayment(month: 1, due: 700, payments: [], currentMonth: 2).status, PayStatus.unpaid);
  });

  test('upcoming for a future month with no payments', () {
    expect(monthPayment(month: 3, due: 700, payments: [], currentMonth: 2).status, PayStatus.upcoming);
  });

  test('payments of other months are ignored; overpay never gives negative remaining', () {
    final m = monthPayment(month: 2, due: 700, payments: [_pay(1, 700), _pay(2, 800)], currentMonth: 2);
    expect(m.paid, 800);
    expect(m.remaining, 0);
    expect(m.status, PayStatus.paid);
  });

  test('a prepaid future month is partial or paid, not upcoming', () {
    expect(monthPayment(month: 3, due: 700, payments: [_pay(3, 700)], currentMonth: 2).status, PayStatus.paid);
    expect(monthPayment(month: 3, due: 700, payments: [_pay(3, 100)], currentMonth: 2).status, PayStatus.partial);
  });

  test('group price override wins over teacher default', () {
    const teacher = Teacher(id: 't', name: 'x');
    const plain = Group(id: 'g', name: 'a', gradeLabel: '', dayOfWeek: 1, timeLabel: '');
    const custom = Group(id: 'g', name: 'a', gradeLabel: '', dayOfWeek: 1, timeLabel: '', priceMonth: 600, priceSession: 150);
    expect(monthDue(teacher, plain), 700);
    expect(monthDue(teacher, custom), 600);
    expect(sessionPrice(teacher, custom), 150);
    expect(sessionPrice(teacher, null), 175);
  });

  test('amount validation', () {
    expect(validatePaymentAmount(amount: null, remaining: 500), isNotNull);
    expect(validatePaymentAmount(amount: 0, remaining: 500), isNotNull);
    expect(validatePaymentAmount(amount: 600, remaining: 500), 'المبلغ أكبر من المتبقي (500 جنيه)');
    expect(validatePaymentAmount(amount: 500, remaining: 500), isNull);
  });

  test('months to show always includes one past the current month', () {
    expect(monthsToShow(1), [1, 2, 3]);
    expect(monthsToShow(4), [1, 2, 3, 4, 5]);
  });
}
