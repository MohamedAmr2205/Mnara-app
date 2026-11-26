import 'dart:math';

import 'package:assistant/core/utils/arabic_text.dart';
import 'package:assistant/data/models/enums.dart';

/// Whether the new-student form can be submitted.
bool canAddNewStudent({
  required String name,
  required String phone,
  required String parentPhone,
  required NewStudentPay? pay,
  required int amount,
}) {
  if (name.trim().isEmpty) return false;
  if (!isValidEgyptianMobile(phone) || !isValidEgyptianMobile(parentPhone)) {
    return false;
  }
  if (pay == null) return false;
  if (pay == NewStudentPay.none) return true;
  return amount > 0;
}

/// Temporary student code: `N-` plus four base-36 characters.
String generateTempCode(Random random) {
  const alphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  final chars = [
    for (var i = 0; i < 4; i++) alphabet[random.nextInt(alphabet.length)],
  ];
  return 'N-${chars.join()}';
}

/// Assigns permanent codes `S<n>` continuing after [counter].
///
/// [tempStudentIds] must already be sorted by creation time; the result keeps
/// that order so earlier students get lower numbers.
Map<String, String> assignPermanentCodes(
  int counter,
  List<String> tempStudentIds,
) {
  final map = <String, String>{};
  var next = counter;
  for (final id in tempStudentIds) {
    next++;
    map[id] = 'S$next';
  }
  return map;
}
