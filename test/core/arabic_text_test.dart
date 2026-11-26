import 'package:flutter_test/flutter_test.dart';

import 'package:assistant/core/utils/arabic_text.dart';

void main() {
  group('digits and phones', () {
    test('converts Arabic-Indic and Persian digits', () {
      expect(normalizeDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
      expect(normalizeDigits('۰۱۲'), '012');
    });

    test('normalizes spaces, dashes and country code', () {
      expect(normalizePhone('010 1234-5678'), '01012345678');
      expect(normalizePhone('+20 10 1234 5678'), '01012345678');
      expect(normalizePhone('٠١٠١٢٣٤٥٦٧٨'), '01012345678');
    });

    test('accepts only 010/011/012/015 mobiles of 11 digits', () {
      for (final ok in ['01012345678', '01112345678', '01212345678', '01512345678']) {
        expect(isValidEgyptianMobile(ok), isTrue, reason: ok);
      }
      for (final bad in ['01312345678', '0101234567', '010123456789', '11012345678', '']) {
        expect(isValidEgyptianMobile(bad), isFalse, reason: bad);
      }
    });

    test('helper messages match the prototype', () {
      expect(checkPhone('').message, '');
      expect(checkPhone('0101234').message, 'لازم 11 رقم بيبدأ بـ 01 (7 من 11)');
      expect(checkPhone('٠١٠١٢٣٤٥٦٧٨').valid, isTrue);
      expect(checkPhone('01012345678').message, 'الرقم تمام');
    });
  });

  group('search', () {
    test('normalizes hamza, ya, ta marbuta and digits', () {
      expect(normalizeForSearch('أحمد'), normalizeForSearch('احمد'));
      expect(normalizeForSearch('منى'), normalizeForSearch('مني'));
      expect(normalizeForSearch('فاطمة'), normalizeForSearch('فاطمه'));
      expect(normalizeForSearch('S١٢'), 's12');
    });

    test('matches by code (case-insensitive) or name substring', () {
      expect(matchesStudent(query: 's12', code: 'S12', name: 'يوسف'), isTrue);
      expect(matchesStudent(query: 'يوس', code: 'S99', name: 'يوسف عادل'), isTrue);
      expect(matchesStudent(query: 'احمد', code: 'S1', name: 'أحمد علي'), isTrue);
      expect(matchesStudent(query: 'زيد', code: 'S1', name: 'أحمد علي'), isFalse);
      expect(matchesStudent(query: '', code: 'S1', name: 'x'), isTrue);
    });
  });
}
