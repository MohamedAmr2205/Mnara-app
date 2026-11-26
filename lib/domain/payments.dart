import 'dart:math';

import 'package:assistant/data/models/models.dart';

/// Payment state of one student for one month.
enum PayStatus { paid, partial, unpaid, upcoming }

/// Derived payment figures for a month.
class MonthPayment {
  /// Creates the figures.
  const MonthPayment({
    required this.month,
    required this.due,
    required this.paid,
    required this.status,
  });

  /// Month number.
  final int month;

  /// Amount due.
  final int due;

  /// Amount paid so far.
  final int paid;

  /// Amount still owed (never negative).
  int get remaining => max(0, due - paid);

  /// Derived status.
  final PayStatus status;
}

/// Month price of a group (its override, or the teacher default).
int monthDue(Teacher teacher, Group? group) =>
    group?.priceMonth ?? teacher.priceMonth;

/// Session price of a group (its override, or the teacher default).
int sessionPrice(Teacher teacher, Group? group) =>
    group?.priceSession ?? teacher.priceSession;

/// Pure payment-status function.
///
/// `paid` when payments cover the due amount, `partial` when something was
/// paid, `unpaid` when nothing was paid for a month that has started, and
/// `upcoming` when nothing was paid for a month after [currentMonth].
MonthPayment monthPayment({
  required int month,
  required int due,
  required Iterable<Payment> payments,
  required int currentMonth,
}) {
  var paid = 0;
  for (final p in payments) {
    if (p.month == month) paid += p.amountEgp;
  }
  final PayStatus status;
  if (due > 0 && paid >= due) {
    status = PayStatus.paid;
  } else if (paid > 0) {
    status = PayStatus.partial;
  } else if (month > currentMonth) {
    status = PayStatus.upcoming;
  } else {
    status = PayStatus.unpaid;
  }
  return MonthPayment(month: month, due: due, paid: paid, status: status);
}

/// Months to show for a student: at least three, always one past the current.
List<int> monthsToShow(int currentMonth) {
  final last = max(3, currentMonth + 1);
  return [for (var m = 1; m <= last; m++) m];
}

/// Why an amount cannot be saved, or null when it is fine.
String? validatePaymentAmount({required int? amount, required int remaining}) {
  if (amount == null || amount <= 0) return 'اكتب مبلغ أكبر من صفر';
  if (amount > remaining) return 'المبلغ أكبر من المتبقي ($remaining جنيه)';
  return null;
}
