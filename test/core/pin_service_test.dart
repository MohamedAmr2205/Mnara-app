import 'package:flutter_test/flutter_test.dart';

import 'package:assistant/core/security/key_value_store.dart';
import 'package:assistant/core/security/pin_service.dart';

void main() {
  late MemoryKeyValueStore store;
  late PinService pin;

  setUp(() {
    store = MemoryKeyValueStore();
    pin = PinService(store, iterations: 10);
  });

  test('no PIN until one is set; the PIN itself is never stored', () async {
    expect(await pin.hasPin(), isFalse);
    await pin.setPin('4827');
    expect(await pin.hasPin(), isTrue);
    expect(store.data.values.any((v) => v.contains('4827')), isFalse);
  });

  test('correct PIN unlocks and resets the counter', () async {
    await pin.setPin('4827');
    await pin.verify('0000', maxAttempts: 10);
    expect(await pin.failedAttempts(), 1);
    expect(await pin.verify('4827', maxAttempts: 10), isA<PinOk>());
    expect(await pin.failedAttempts(), 0);
  });

  test('wrong PIN reports the attempts left', () async {
    await pin.setPin('4827');
    final r = await pin.verify('1111', maxAttempts: 10);
    expect(r, isA<PinWrong>());
    expect((r as PinWrong).attemptsLeft, 9);
  });

  test('locks out after 10 wrong attempts and rejects even the right PIN', () async {
    await pin.setPin('4827');
    PinResult? last;
    for (var i = 0; i < 10; i++) {
      last = await pin.verify('1111', maxAttempts: 10);
    }
    expect(last, isA<PinLocked>());
    expect(await pin.isLockedOut(10), isTrue);
    expect(await pin.verify('4827', maxAttempts: 10), isA<PinLocked>());
  });

  test('the lockout survives an app restart (same store, new service)', () async {
    await pin.setPin('4827');
    for (var i = 0; i < 10; i++) {
      await pin.verify('1111', maxAttempts: 10);
    }
    final restarted = PinService(store, iterations: 10);
    expect(await restarted.isLockedOut(10), isTrue);
    expect(await restarted.verify('4827', maxAttempts: 10), isA<PinLocked>());
  });

  test('resetting the lockout and choosing a new PIN works', () async {
    await pin.setPin('4827');
    for (var i = 0; i < 10; i++) {
      await pin.verify('1111', maxAttempts: 10);
    }
    await pin.clearAll();
    expect(await pin.hasPin(), isFalse);
    await pin.setPin('9035');
    expect(await pin.isLockedOut(10), isFalse);
    expect(await pin.verify('9035', maxAttempts: 10), isA<PinOk>());
    expect(await pin.verify('4827', maxAttempts: 10), isA<PinWrong>());
  });

  test('changing the PIN replaces the old one and uses a fresh salt', () async {
    await pin.setPin('4827');
    final salt1 = store.data['pin.salt'];
    await pin.setPin('9035');
    expect(store.data['pin.salt'], isNot(salt1));
    expect(await pin.matchesCurrent('9035'), isTrue);
    expect(await pin.matchesCurrent('4827'), isFalse);
  });

  test('matchesCurrent does not count as an attempt', () async {
    await pin.setPin('4827');
    await pin.matchesCurrent('0000');
    expect(await pin.failedAttempts(), 0);
  });

  test('weak PINs are flagged', () {
    for (final weak in ['1234', '4321', '0000', '7777']) {
      expect(PinService.isWeakPin(weak), isTrue, reason: weak);
    }
    expect(PinService.isWeakPin('4827'), isFalse);
  });
}
