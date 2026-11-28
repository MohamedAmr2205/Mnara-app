import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

/// Number of SHA-256 rounds. This is the interim local-mode scheme; the
/// planned Firebase milestone moves to PBKDF2 + secure storage.
const int _rounds = 5000;

/// Random 16-byte salt as hex.
String newSalt() {
  final rng = math.Random.secure();
  return List<String>.generate(
    16,
    (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// Salted, iterated SHA-256 of [pin] as hex.
String hashPin(String pin, String salt) {
  var bytes = utf8.encode('$salt:$pin');
  for (var i = 0; i < _rounds; i++) {
    bytes = sha256.convert(bytes).bytes;
  }
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Constant-time-ish comparison of two hex strings.
bool hashesEqual(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
