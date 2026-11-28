import 'dart:math' as math;

const String _arabicIndic = '٠١٢٣٤٥٦٧٨٩';
const String _easternPersian = '۰۱۲۳۴۵۶۷۸۹';

/// Converts Arabic-Indic and Persian digits to Latin digits.
String normalizeDigits(String input) {
  final out = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    final a = _arabicIndic.indexOf(ch);
    if (a >= 0) {
      out.write(a);
      continue;
    }
    final p = _easternPersian.indexOf(ch);
    if (p >= 0) {
      out.write(p);
      continue;
    }
    out.write(ch);
  }
  return out.toString();
}

/// Normalizes text for searching: Latin digits, lowercase, unified Arabic
/// letter forms (أ/إ/آ→ا، ى→ي، ة→ه), no diacritics, collapsed spaces.
String normalizeSearch(String input) {
  var s = normalizeDigits(input).toLowerCase();
  s = s
      .replaceAll(RegExp('[ً-ْـ]'), '')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه');
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Latin digits with spaces and dashes removed (phone numbers).
String normalizePhone(String input) {
  return normalizeDigits(input).replaceAll(RegExp(r'[\s\-]'), '');
}

final RegExp _egyptMobile = RegExp(r'^01[0125]\d{8}$');

/// Whether [normalized] is a valid Egyptian mobile number.
bool isValidEgyptMobile(String normalized) => _egyptMobile.hasMatch(normalized);

/// Parses a positive integer from user input (Arabic digits allowed).
int? parsePositiveInt(String input) {
  final v = int.tryParse(normalizeDigits(input).trim());
  if (v == null || v <= 0) return null;
  return v;
}

/// Parses a non-negative decimal (score) from user input.
double? parseScore(String input) {
  final cleaned = normalizeDigits(input).trim().replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  final v = double.tryParse(cleaned);
  if (v == null || v < 0) return null;
  return v;
}

/// Formats a score without a trailing `.0` (`17` or `17.5`).
String formatScore(double v) {
  if (v == v.roundToDouble()) return v.round().toString();
  return v.toStringAsFixed(1);
}

/// Random id (not cryptographic, only needs to be unique locally).
String newId([String prefix = '']) {
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final r = math.Random().nextInt(1 << 30).toRadixString(36);
  return '$prefix$t$r';
}
