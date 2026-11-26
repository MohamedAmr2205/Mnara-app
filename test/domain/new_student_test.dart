import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:assistant/data/models/enums.dart';
import 'package:assistant/domain/new_student.dart';

void main() {
  bool can({
    String name = 'يوسف عادل',
    String phone = '01012345678',
    String parent = '01112345678',
    NewStudentPay? pay = NewStudentPay.none,
    int amount = 0,
  }) => canAddNewStudent(name: name, phone: phone, parentPhone: parent, pay: pay, amount: amount);

  test('needs a name', () {
    expect(can(name: '  '), isFalse);
    expect(can(), isTrue);
  });

  test('needs both phones to be valid', () {
    expect(can(phone: '0101'), isFalse);
    expect(can(parent: ''), isFalse);
    expect(can(phone: '٠١٠١٢٣٤٥٦٧٨'), isTrue);
  });

  test('payment must be confirmed; paying needs a positive amount', () {
    expect(can(pay: null), isFalse);
    expect(can(pay: NewStudentPay.session, amount: 0), isFalse);
    expect(can(pay: NewStudentPay.session, amount: 175), isTrue);
    expect(can(pay: NewStudentPay.month, amount: 700), isTrue);
    expect(can(pay: NewStudentPay.none, amount: 0), isTrue);
  });

  test('temporary code format', () {
    final code = generateTempCode(Random(1));
    expect(code, matches(RegExp(r'^N-[0-9A-Z]{4}$')));
  });

  test('permanent codes continue after the counter in creation order', () {
    expect(assignPermanentCodes(1000, ['b', 'a', 'c']), {'b': 'S1001', 'a': 'S1002', 'c': 'S1003'});
    expect(assignPermanentCodes(1000, const []), isEmpty);
  });
}
