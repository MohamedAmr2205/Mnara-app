import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:assistant/app/router.dart';
import 'package:assistant/core/security/auth_controller.dart';
import 'package:assistant/core/security/auth_gateway.dart';
import 'package:assistant/core/security/key_value_store.dart';
import 'package:assistant/core/security/pin_service.dart';

import '../support/fakes.dart';

ProviderContainer _container({
  FakeAuthGateway? gateway,
  FakeCacheWarmer? warmer,
  MemoryKeyValueStore? store,
}) {
  final s = store ?? MemoryKeyValueStore();
  final c = ProviderContainer(
    overrides: [
      keyValueStoreProvider.overrideWithValue(s),
      pinServiceProvider.overrideWithValue(PinService(s, iterations: 10)),
      authGatewayProvider.overrideWithValue(gateway ?? FakeAuthGateway()),
      cacheWarmerProvider.overrideWithValue(warmer ?? FakeCacheWarmer()),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  test('without a saved session the app starts signed out', () async {
    final c = _container();
    c.read(authControllerProvider);
    await _settle();
    expect(c.read(authControllerProvider).phase, AuthPhase.signedOut);
  });

  test('first sign-in warms the cache, then asks for a PIN, then unlocks', () async {
    final warmer = FakeCacheWarmer();
    final c = _container(warmer: warmer);
    c.read(authControllerProvider);
    await _settle();
    final auth = c.read(authControllerProvider.notifier);

    await auth.signIn('a@b.com', 'secret123');
    expect(warmer.warmCalls, 1);
    expect(c.read(authControllerProvider).phase, AuthPhase.needsPinSetup);
    expect(c.read(authControllerProvider).teacherId, 't1');

    await auth.createPin('4827');
    expect(c.read(authControllerProvider).phase, AuthPhase.unlocked);
  });

  test('a wrong account password shows a message and stays signed out', () async {
    final c = _container();
    c.read(authControllerProvider);
    await _settle();
    await c.read(authControllerProvider.notifier).signIn('a@b.com', 'nope');
    final s = c.read(authControllerProvider);
    expect(s.phase, AuthPhase.signedOut);
    expect(s.error, 'الإيميل أو الباسورد غلط');
  });

  test('a failed first download keeps the user on the warming phase', () async {
    final warmer = FakeCacheWarmer()..fail = true;
    final c = _container(warmer: warmer);
    c.read(authControllerProvider);
    await _settle();
    await c.read(authControllerProvider.notifier).signIn('a@b.com', 'secret123');
    final s = c.read(authControllerProvider);
    expect(s.phase, AuthPhase.warming);
    expect(s.error, isNotNull);

    warmer.fail = false;
    await c.read(authControllerProvider.notifier).warmCache();
    expect(c.read(authControllerProvider).phase, AuthPhase.needsPinSetup);
  });

  test('restart with a saved session and PIN goes straight to the lock screen (offline-safe)', () async {
    final store = MemoryKeyValueStore();
    final gateway = FakeAuthGateway();
    final first = _container(gateway: gateway, store: store);
    first.read(authControllerProvider);
    await _settle();
    await first.read(authControllerProvider.notifier).signIn('a@b.com', 'secret123');
    await first.read(authControllerProvider.notifier).createPin('4827');

    final warmer = FakeCacheWarmer()..fail = true; // offline on the second launch
    final second = _container(gateway: gateway, store: store, warmer: warmer);
    second.read(authControllerProvider);
    await _settle();
    expect(second.read(authControllerProvider).phase, AuthPhase.locked);
    expect(warmer.warmCalls, 0);
  });

  test('wrong PINs count down, the 10th locks out, password unlock resets', () async {
    final c = _container();
    c.read(authControllerProvider);
    await _settle();
    final auth = c.read(authControllerProvider.notifier);
    await auth.signIn('a@b.com', 'secret123');
    await auth.createPin('4827');
    await auth.lock();
    expect(c.read(authControllerProvider).phase, AuthPhase.locked);

    await auth.submitPin('1111');
    expect(c.read(authControllerProvider).error, 'PIN غلط · باقي 9 محاولات');
    for (var i = 0; i < 9; i++) {
      await auth.submitPin('1111');
    }
    expect(c.read(authControllerProvider).phase, AuthPhase.lockedOut);

    expect(await auth.unlockWithPassword('wrong-password'), isFalse);
    expect(c.read(authControllerProvider).phase, AuthPhase.lockedOut);

    expect(await auth.unlockWithPassword('secret123'), isTrue);
    expect(c.read(authControllerProvider).phase, AuthPhase.needsPinSetup);
    await auth.createPin('9035');
    expect(c.read(authControllerProvider).phase, AuthPhase.unlocked);
  });

  test('the right PIN unlocks', () async {
    final c = _container();
    c.read(authControllerProvider);
    await _settle();
    final auth = c.read(authControllerProvider.notifier);
    await auth.signIn('a@b.com', 'secret123');
    await auth.createPin('4827');
    await auth.lock();
    await auth.submitPin('4827');
    expect(c.read(authControllerProvider).phase, AuthPhase.unlocked);
  });

  test('logout clears the PIN and the session', () async {
    final gateway = FakeAuthGateway();
    final store = MemoryKeyValueStore();
    final c = _container(gateway: gateway, store: store);
    c.read(authControllerProvider);
    await _settle();
    final auth = c.read(authControllerProvider.notifier);
    await auth.signIn('a@b.com', 'secret123');
    await auth.createPin('4827');
    await auth.logout();
    expect(gateway.signedOut, isTrue);
    expect(c.read(authControllerProvider).phase, AuthPhase.signedOut);
    expect(store.data.keys.where((k) => k.startsWith('pin.')), isEmpty);
  });

  group('route guards', () {
    test('every locked phase funnels to the PIN screen', () {
      expect(authRedirect(AuthPhase.locked, '/groups'), '/lock');
      expect(authRedirect(AuthPhase.lockedOut, '/session/x'), '/lock');
      expect(authRedirect(AuthPhase.locked, '/unlock'), isNull);
    });

    test('unlocking returns to where the user was', () {
      expect(authRedirect(AuthPhase.unlocked, '/lock', returnTo: '/session/x'), '/session/x');
      expect(authRedirect(AuthPhase.unlocked, '/lock'), '/groups');
      expect(authRedirect(AuthPhase.unlocked, '/groups'), isNull);
    });

    test('signed-out and setup phases pin their screens', () {
      expect(authRedirect(AuthPhase.signedOut, '/groups'), '/signin');
      expect(authRedirect(AuthPhase.needsPinSetup, '/groups'), '/pin-setup');
      expect(authRedirect(AuthPhase.warming, '/groups'), '/warming');
      expect(authRedirect(AuthPhase.booting, '/groups'), '/boot');
    });
  });

  test('AuthFailure carries its message', () {
    expect(const AuthFailure('x').toString(), 'x');
  });
}
