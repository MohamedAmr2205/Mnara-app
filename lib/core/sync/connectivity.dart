import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Source of "can we reach the internet" signals.
abstract class ConnectivitySource {
  /// Emits whenever reachability may have changed.
  Stream<bool> get changes;

  /// Checks reachability now.
  Future<bool> check();
}

/// Real implementation: network interface state plus a DNS reachability probe.
class PlatformConnectivity implements ConnectivitySource {
  final Connectivity _connectivity = Connectivity();

  @override
  Future<bool> check() async {
    final results = await _connectivity.checkConnectivity();
    if (results.every((r) => r == ConnectivityResult.none)) return false;
    try {
      final found = await InternetAddress.lookup(
        'firestore.googleapis.com',
      ).timeout(const Duration(seconds: 4));
      return found.isNotEmpty && found.first.rawAddress.isNotEmpty;
    } on Exception {
      return false;
    }
  }

  @override
  Stream<bool> get changes async* {
    final controller = StreamController<void>();
    final sub = _connectivity.onConnectivityChanged.listen(
      (_) => controller.add(null),
    );
    final timer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => controller.add(null),
    );
    try {
      await for (final _ in controller.stream) {
        yield await check();
      }
    } finally {
      timer.cancel();
      await sub.cancel();
      await controller.close();
    }
  }
}

/// Connectivity source (overridden in tests).
final connectivitySourceProvider = Provider<ConnectivitySource>(
  (ref) => PlatformConnectivity(),
);

/// Raw reachability stream.
final rawOnlineProvider = StreamProvider<bool>((ref) async* {
  final source = ref.watch(connectivitySourceProvider);
  yield await source.check();
  yield* source.changes;
});

/// Debug-only switch that forces the app to behave as offline.
class DebugOfflineNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Sets the forced-offline flag.
  void set(bool value) => state = value;
}

/// Forced-offline flag (only exposed in debug builds).
final debugOfflineProvider = NotifierProvider<DebugOfflineNotifier, bool>(
  DebugOfflineNotifier.new,
);

/// Whether the app should consider itself online.
final isOnlineProvider = Provider<bool>((ref) {
  if (ref.watch(debugOfflineProvider)) return false;
  return ref.watch(rawOnlineProvider).valueOrNull ?? true;
});
