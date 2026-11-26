/// Arabic-aware text helpers shared by phone validation and search.

/// Converts Arabic-Indic and Persian digits to ASCII digits.
String normalizeDigits(String input) {
  final buffer = StringBuffer();
  for (final unit in input.runes) {
    if (unit >= 0x0660 && unit <= 0x0669) {
      buffer.writeCharCode(0x30 + unit - 0x0660);
    } else if (unit >= 0x06F0 && unit <= 0x06F9) {
      buffer.writeCharCode(0x30 + unit - 0x06F0);
    } else {
      buffer.writeCharCode(unit);
    }
  }
  return buffer.toString();
}

/// Normalizes a typed phone number: ASCII digits only, `+20` becomes `0`.
String normalizePhone(String input) {
  var text = normalizeDigits(input).replaceAll(RegExp(r'[\s\-\.\(\)]'), '');
  if (text.startsWith('+20')) {
    text = '0${text.substring(3)}';
  } else if (text.startsWith('0020')) {
    text = '0${text.substring(4)}';
  }
  return text.replaceAll(RegExp(r'[^0-9]'), '');
}

final RegExp _mobile = RegExp(r'^01[0125][0-9]{8}$');

/// Whether [input] is a valid Egyptian mobile number after normalization.
bool isValidEgyptianMobile(String input) =>
    _mobile.hasMatch(normalizePhone(input));

/// Result of validating a phone field as the user types.
class PhoneCheck {
  /// Creates a result.
  const PhoneCheck({required this.valid, required this.message});

  /// Whether the number is acceptable.
  final bool valid;

  /// Arabic helper message shown under the field (empty when untouched).
  final String message;
}

/// Validates [input] and returns the helper message from the prototype.
PhoneCheck checkPhone(String input) {
  final phone = normalizePhone(input);
  if (phone.isEmpty) return const PhoneCheck(valid: false, message: '');
  if (_mobile.hasMatch(phone)) {
    return const PhoneCheck(valid: true, message: 'الرقم تمام');
  }
  return PhoneCheck(
    valid: false,
    message: 'لازم 11 رقم بيبدأ بـ 01 (${phone.length} من 11)',
  );
}

/// Normalizes text for forgiving Arabic search (digits, hamza, ya, ta marbuta).
String normalizeForSearch(String input) {
  var text = normalizeDigits(input).toLowerCase().trim();
  text = text.replaceAll(RegExp('[ً-ْـ]'), '');
  text = text
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه');
  return text.replaceAll(RegExp(r'\s+'), ' ');
}

/// Whether a student's [code] or [name] matches the search [query].
///
/// The code matches case-insensitively as a substring, the name as a substring
/// after normalization. An empty query matches everything.
bool matchesStudent({
  required String query,
  required String code,
  required String name,
}) {
  final q = normalizeForSearch(query);
  if (q.isEmpty) return true;
  return normalizeForSearch(code).contains(q) ||
      normalizeForSearch(name).contains(q);
}
