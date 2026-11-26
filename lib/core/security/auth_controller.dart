import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:assistant/core/firebase/cache_warmer.dart';
import 'package:assistant/core/security/auth_gateway.dart';
import 'package:assistant/core/security/key_value_store.dart';
import 'package:assistant/core/security/pin_service.dart';

/// Where the user is in the sign-in / lock flow.
enum AuthPhase {
  booting,
  signedOut,
  warming,
  needsPinSetup,
  locked,
  lockedOut,
  unlocked,
}

/// Immutable auth/lock state.
class AuthState {
  /// Creates a state.
  const AuthState({
    this.phase = AuthPhase.booting,
    this.uid,
    this.email,
    this.teacherId,
    this.busy = false,
    this.error,
    this.attemptsLeft,
    this.maxAttempts = 10,
    this.idleLockMinutes = 5,
    this.shakeToken = 0,
  });

  /// Current phase.
  final AuthPhase phase;

  /// Signed-in uid.
  final String? uid;

  /// Account email.
  final String? email;

  /// Teacher id from `users/{uid}`.
  final String? teacherId;

  /// A network/crypto operation is running.
  final bool busy;

  /// Message to show, if any.
  final String? error;

  /// Remaining PIN attempts after a wrong PIN.
  final int? attemptsLeft;

  /// Attempt limit.
  final int maxAttempts;

  /// Idle minutes before auto-lock.
  final int idleLockMinutes;

  /// Increments on each wrong PIN so the dots shake again.
  final int shakeToken;

  /// Copy with changes (error and attemptsLeft reset unless given).
  AuthState copyWith({
    AuthPhase? phase,
    String? uid,
    String? email,
    String? teacherId,
    bool? busy,
    String? error,
    int? attemptsLeft,
    int? maxAttempts,
    int? idleLockMinutes,
    int? shakeToken,
  }) {
    return AuthState(
      phase: phase ?? this.phase,
      uid: uid ?? this.uid,
      email: email ?? this.email,
      teacherId: teacherId ?? this.teacherId,
      busy: busy ?? this.busy,
      error: error,
      attemptsLeft: attemptsLeft,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      idleLockMinutes: idleLockMinutes ?? this.idleLockMinutes,
      shakeToken: shakeToken ?? this.shakeToken,
    );
  }
}

/// Providers wired in `main.dart` (overridden in tests).
final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => throw UnimplementedError('keyValueStoreProvider not overridden'),
);

/// PIN service.
final pinServiceProvider = Provider<PinService>(
  (ref) => PinService(ref.watch(keyValueStoreProvider)),
);

/// Account gateway.
final authGatewayProvider = Provider<AuthGateway>(
  (ref) => throw UnimplementedError('authGatewayProvider not overridden'),
);

/// Cache warmer.
final cacheWarmerProvider = Provider<CacheWarmer>(
  (ref) => throw UnimplementedError('cacheWarmerProvider not overridden'),
);

/// Drives sign-in, PIN setup, lock and logout.
class AuthController extends Notifier<AuthState> {
  static const _teacherKey = 'auth.teacherId';
  static const _uidKey = 'auth.uid';
  static const _warmedKey = 'cache.warmedFor';
  static const _maxKey = 'cfg.maxAttempts';
  static const _idleKey = 'cfg.idleMinutes';

  KeyValueStore get _store => ref.read(keyValueStoreProvider);
  PinService get _pin => ref.read(pinServiceProvider);
  AuthGateway get _gateway => ref.read(authGatewayProvider);

  @override
  AuthState build() {
    Future<void>.microtask(boot);
    return const AuthState();
  }

  Future<AuthPhase> _phaseAfterAuth(int maxAttempts) async {
    if (!await _pin.hasPin()) return AuthPhase.needsPinSetup;
    if (await _pin.isLockedOut(maxAttempts)) return AuthPhase.lockedOut;
    return AuthPhase.locked;
  }

  Future<void> _loadSettings() async {
    final max = int.tryParse(await _store.read(_maxKey) ?? '') ?? 10;
    final idle = int.tryParse(await _store.read(_idleKey) ?? '') ?? 5;
    state = state.copyWith(maxAttempts: max, idleLockMinutes: idle);
  }

  /// Restores the persisted session at app start (works offline).
  Future<void> boot() async {
    final user = _gateway.currentUser;
    if (user == null) {
      state = state.copyWith(phase: AuthPhase.signedOut);
      return;
    }
    final teacherId = await _store.read(_teacherKey);
    state = state.copyWith(
      uid: user.uid,
      email: user.email,
      teacherId: teacherId,
    );
    await _loadSettings();
    if (teacherId == null || await _store.read(_warmedKey) != teacherId) {
      state = state.copyWith(phase: AuthPhase.warming);
      await warmCache();
      return;
    }
    state = state.copyWith(phase: await _phaseAfterAuth(state.maxAttempts));
  }

  /// First sign-in with email and password.
  Future<void> signIn(String email, String password) async {
    state = state.copyWith(busy: true, phase: state.phase);
    try {
      final user = await _gateway.signIn(email, password);
      final previous = await _store.read(_uidKey);
      if (previous != null && previous != user.uid) {
        await _pin.clearAll();
      }
      await _store.write(_uidKey, user.uid);
      state = state.copyWith(
        uid: user.uid,
        email: user.email,
        busy: false,
        phase: AuthPhase.warming,
      );
      await warmCache();
    } on AuthFailure catch (e) {
      state = state.copyWith(busy: false, error: e.message);
    }
  }

  /// Downloads the working set; on failure stays on the warming screen.
  Future<void> warmCache() async {
    final uid = state.uid;
    if (uid == null) return;
    state = state.copyWith(busy: true, phase: AuthPhase.warming);
    try {
      var teacherId = state.teacherId ?? await _gateway.fetchTeacherId(uid);
      if (teacherId == null) {
        state = state.copyWith(
          busy: false,
          error: 'الحساب ده مش مربوط بمدرس. كلّم المدرس يظبط الحساب.',
        );
        return;
      }
      final settings = await ref.read(cacheWarmerProvider).warm(teacherId);
      await _store.write(_teacherKey, teacherId);
      await _store.write(_warmedKey, teacherId);
      await _store.write(_maxKey, settings.maxPinAttempts.toString());
      await _store.write(_idleKey, settings.idleLockMinutes.toString());
      state = state.copyWith(
        teacherId: teacherId,
        maxAttempts: settings.maxPinAttempts,
        idleLockMinutes: settings.idleLockMinutes,
        busy: false,
      );
      state = state.copyWith(phase: await _phaseAfterAuth(settings.maxPinAttempts));
    } catch (_) {
      state = state.copyWith(
        busy: false,
        error: 'مقدرناش نحمّل البيانات. اتأكد إن النت شغال وجرّب تاني.',
      );
    }
  }

  /// Stores the first (or a reset) PIN and unlocks.
  Future<void> createPin(String pin) async {
    state = state.copyWith(busy: true);
    await _pin.setPin(pin);
    state = state.copyWith(busy: false, phase: AuthPhase.unlocked);
  }

  /// Checks a PIN entered on the lock screen.
  Future<void> submitPin(String pin) async {
    state = state.copyWith(busy: true);
    final result = await _pin.verify(pin, maxAttempts: state.maxAttempts);
    switch (result) {
      case PinOk():
        state = state.copyWith(busy: false, phase: AuthPhase.unlocked);
      case PinWrong(:final attemptsLeft):
        state = state.copyWith(
          busy: false,
          attemptsLeft: attemptsLeft,
          error: 'PIN غلط · باقي $attemptsLeft محاولات',
          shakeToken: state.shakeToken + 1,
        );
      case PinLocked():
        state = state.copyWith(
          busy: false,
          phase: AuthPhase.lockedOut,
          shakeToken: state.shakeToken + 1,
        );
    }
  }

  /// Unlock path after lockout: re-enter the account password, then pick a new PIN.
  Future<bool> unlockWithPassword(String password) async {
    state = state.copyWith(busy: true);
    try {
      await _gateway.reauthenticate(password);
      await _pin.clearAll();
      state = state.copyWith(busy: false, phase: AuthPhase.needsPinSetup);
      return true;
    } on AuthFailure catch (e) {
      state = state.copyWith(busy: false, error: e.message);
      return false;
    }
  }

  /// Locks the app (idle timeout or manual).
  Future<void> lock() async {
    if (state.phase != AuthPhase.unlocked) return;
    state = state.copyWith(phase: await _phaseAfterAuth(state.maxAttempts));
  }

  /// Clears the PIN and the session; the caller wipes the cache first.
  Future<void> logout() async {
    await _pin.clearAll();
    await _store.delete(_teacherKey);
    await _store.delete(_uidKey);
    await _store.delete(_warmedKey);
    await _gateway.signOut();
    state = const AuthState(phase: AuthPhase.signedOut);
  }
}

/// Auth/lock state.
final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
