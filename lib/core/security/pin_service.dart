import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'package:assistant/core/security/key_value_store.dart';

/// Result of checking a PIN.
sealed class PinResult {
  const PinResult();
}

/// The PIN matched.
class PinOk extends PinResult {
  /// Creates the result.
  const PinOk();
}

/// The PIN was wrong; [attemptsLeft] tries remain before lockout.
class PinWrong extends PinResult {
  /// Creates the result.
  const PinWrong(this.attemptsLeft);

  /// Remaining attempts.
  final int attemptsLeft;
}

/// Too many wrong attempts; only the account password can unlock.
class PinLocked extends PinResult {
  /// Creates the result.
  const PinLocked();
}

/// Local device PIN: PBKDF2-HMAC-SHA256 with a per-install random salt.
///
/// Only the derived hash is stored. The failed-attempt counter is persisted so
/// killing the app does not reset the lockout.
class PinService {
  /// Creates the service; [iterations] is lowered in tests only.
  PinService(this._store, {this.iterations = 50000, Random? random})
    : _random = random ?? Random.secure();

  final KeyValueStore _store;
  final Random _random;

  /// PBKDF2 iteration count for new PINs.
  final int iterations;

  static const _saltKey = 'pin.salt';
  static const _hashKey = 'pin.hash';
  static const _iterKey = 'pin.iter';
  static const _failsKey = 'pin.fails';

  /// PINs that are too easy to guess.
  static bool isWeakPin(String pin) {
    if (pin == '1234' || pin == '4321' || pin == '0123') return true;
    return pin.split('').toSet().length == 1;
  }

  /// Whether a PIN has been set on this install.
  Future<bool> hasPin() async => (await _store.read(_hashKey)) != null;

  /// Number of wrong attempts so far.
  Future<int> failedAttempts() async =>
      int.tryParse(await _store.read(_failsKey) ?? '') ?? 0;

  /// Whether the lockout limit was reached.
  Future<bool> isLockedOut(int maxAttempts) async =>
      await failedAttempts() >= maxAttempts;

  Future<List<int>> _derive(String pin, List<int> salt, int iter) async {
    final algorithm = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iter,
      bits: 256,
    );
    final key = await algorithm.deriveKeyFromPassword(
      password: pin,
      nonce: salt,
    );
    return key.extractBytes();
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// Stores a new PIN (fresh salt) and clears the failed-attempt counter.
  Future<void> setPin(String pin) async {
    final salt = List<int>.generate(16, (_) => _random.nextInt(256));
    final hash = await _derive(pin, salt, iterations);
    await _store.write(_saltKey, base64Encode(salt));
    await _store.write(_hashKey, base64Encode(hash));
    await _store.write(_iterKey, iterations.toString());
    await _store.write(_failsKey, '0');
  }

  Future<bool> _matches(String pin) async {
    final saltText = await _store.read(_saltKey);
    final hashText = await _store.read(_hashKey);
    if (saltText == null || hashText == null) return false;
    final iter = int.tryParse(await _store.read(_iterKey) ?? '') ?? iterations;
    final derived = await _derive(pin, base64Decode(saltText), iter);
    return _constantTimeEquals(derived, base64Decode(hashText));
  }

  /// Whether [pin] equals the stored PIN, without touching the counter.
  Future<bool> matchesCurrent(String pin) => _matches(pin);

  /// Checks [pin], counting a failure when it is wrong.
  Future<PinResult> verify(String pin, {required int maxAttempts}) async {
    if (await isLockedOut(maxAttempts)) return const PinLocked();
    if (await _matches(pin)) {
      await _store.write(_failsKey, '0');
      return const PinOk();
    }
    final fails = await failedAttempts() + 1;
    await _store.write(_failsKey, fails.toString());
    if (fails >= maxAttempts) return const PinLocked();
    return PinWrong(maxAttempts - fails);
  }

  /// Clears the failed-attempt counter (after a password unlock).
  Future<void> resetLockout() => _store.write(_failsKey, '0');

  /// Removes the PIN completely (after a password unlock or logout).
  Future<void> clearAll() async {
    await _store.delete(_saltKey);
    await _store.delete(_hashKey);
    await _store.delete(_iterKey);
    await _store.delete(_failsKey);
  }
}
