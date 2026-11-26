import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:assistant/core/security/auth_controller.dart';
import 'package:assistant/core/sync/connectivity.dart';
import 'package:assistant/core/sync/write_service.dart';
import 'package:assistant/data/providers.dart';

/// Wraps the unlocked app: idle auto-lock and background work.
///
/// The app locks after the idle limit (default 5 minutes) of no touches, or
/// when it returns from the background after longer than that. Whenever the
/// app is online it also converts temporary student codes to permanent ones.
class SessionGuard extends ConsumerStatefulWidget {
  /// Creates the guard around [child].
  const SessionGuard({super.key, required this.child});

  /// The app content.
  final Widget child;

  @override
  ConsumerState<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends ConsumerState<SessionGuard>
    with WidgetsBindingObserver {
  Timer? _timer;
  DateTime? _pausedAt;
  bool _reconciling = false;

  Duration get _limit =>
      Duration(minutes: ref.read(authControllerProvider).idleLockMinutes);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restart();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    _timer = Timer(_limit, _lock);
  }

  void _lock() {
    ref.read(authControllerProvider.notifier).lock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final at = _pausedAt;
      _pausedAt = null;
      if (at != null && DateTime.now().difference(at) >= _limit) {
        _lock();
      } else {
        _restart();
      }
    }
  }

  Future<void> _reconcile() async {
    if (_reconciling) return;
    _reconciling = true;
    try {
      await ref.read(dataRepositoryProvider).reconcileStudentCodes();
    } catch (_) {
      // Offline or rejected: tried again on the next connectivity change.
    } finally {
      _reconciling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(isOnlineProvider, (previous, online) {
      if (online && ref.read(autoUploadProvider)) _reconcile();
    });
    ref.listen(studentsProvider, (previous, next) {
      final students = next.valueOrNull;
      if (students == null) return;
      final hasTemp = students.any((s) => s.isTempCode && !s.pending);
      if (hasTemp && ref.read(isOnlineProvider) && ref.read(autoUploadProvider)) {
        _reconcile();
      }
    });
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _restart(),
      child: widget.child,
    );
  }
}
