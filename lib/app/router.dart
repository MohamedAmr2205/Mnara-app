import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:assistant/app/routes.dart';
import 'package:assistant/app/tabs_scaffold.dart';
import 'package:assistant/core/security/auth_controller.dart';
import 'package:assistant/features/auth/pin_login_screen.dart';
import 'package:assistant/features/auth/pin_setup_screen.dart';
import 'package:assistant/features/auth/sign_in_screen.dart';
import 'package:assistant/features/auth/unlock_screen.dart';
import 'package:assistant/features/auth/warming_screen.dart';
import 'package:assistant/features/groups/group_screen.dart';
import 'package:assistant/features/groups/groups_screen.dart';
import 'package:assistant/features/groups/start_session_screen.dart';
import 'package:assistant/features/history/history_screen.dart';
import 'package:assistant/features/search/search_screen.dart';
import 'package:assistant/features/session/finish_screen.dart';
import 'package:assistant/features/session/session_screen.dart';
import 'package:assistant/features/settings/change_pin_screen.dart';
import 'package:assistant/features/settings/settings_screen.dart';
import 'package:assistant/features/student/payment_screen.dart';
import 'package:assistant/features/student/student_screen.dart';
import 'package:assistant/features/sync/sync_screen.dart';

const _authRoutes = {
  AppRoutes.boot,
  AppRoutes.signIn,
  AppRoutes.warming,
  AppRoutes.pinSetup,
  AppRoutes.lock,
  AppRoutes.unlock,
};

/// Pure redirect rule, exposed for tests.
///
/// [returnTo] remembers where the user was when the app locked.
String? authRedirect(AuthPhase phase, String location, {String? returnTo}) {
  switch (phase) {
    case AuthPhase.booting:
      return location == AppRoutes.boot ? null : AppRoutes.boot;
    case AuthPhase.signedOut:
      return location == AppRoutes.signIn ? null : AppRoutes.signIn;
    case AuthPhase.warming:
      return location == AppRoutes.warming ? null : AppRoutes.warming;
    case AuthPhase.needsPinSetup:
      return location == AppRoutes.pinSetup ? null : AppRoutes.pinSetup;
    case AuthPhase.locked:
    case AuthPhase.lockedOut:
      if (location == AppRoutes.lock || location == AppRoutes.unlock) return null;
      return AppRoutes.lock;
    case AuthPhase.unlocked:
      if (_authRoutes.contains(location)) return returnTo ?? AppRoutes.groups;
      return null;
  }
}

/// App router with auth/lock guards.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<AuthState>(authControllerProvider, (previous, next) {
    if (previous?.phase != next.phase) refresh.value++;
  });
  ref.onDispose(refresh.dispose);

  String? returnTo;
  return GoRouter(
    navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'root'),
    initialLocation: AppRoutes.boot,
    refreshListenable: refresh,
    redirect: (context, state) {
      final phase = ref.read(authControllerProvider).phase;
      final location = state.matchedLocation;
      if ((phase == AuthPhase.locked || phase == AuthPhase.lockedOut) &&
          !_authRoutes.contains(location)) {
        returnTo = state.uri.toString();
      }
      final target = authRedirect(phase, location, returnTo: returnTo);
      if (phase == AuthPhase.unlocked && target != null) returnTo = null;
      return target;
    },
    routes: [
      GoRoute(path: AppRoutes.boot, builder: (c, s) => const WarmingScreen(booting: true)),
      GoRoute(path: AppRoutes.signIn, builder: (c, s) => const SignInScreen()),
      GoRoute(path: AppRoutes.warming, builder: (c, s) => const WarmingScreen()),
      GoRoute(path: AppRoutes.pinSetup, builder: (c, s) => const PinSetupScreen()),
      GoRoute(path: AppRoutes.lock, builder: (c, s) => const PinLoginScreen()),
      GoRoute(path: AppRoutes.unlock, builder: (c, s) => const UnlockScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => TabsScaffold(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: AppRoutes.groups, builder: (c, s) => const GroupsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: AppRoutes.search, builder: (c, s) => const SearchScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: AppRoutes.history, builder: (c, s) => const HistoryScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: AppRoutes.settings, builder: (c, s) => const SettingsScreen())]),
        ],
      ),
      GoRoute(path: AppRoutes.group, builder: (c, s) => GroupScreen(gid: s.pathParameters['gid']!)),
      GoRoute(path: AppRoutes.startSession, builder: (c, s) => StartSessionScreen(gid: s.pathParameters['gid']!)),
      GoRoute(
        path: AppRoutes.session,
        builder: (c, s) => SessionScreen(
          sessionId: s.pathParameters['xid']!,
          edit: s.uri.queryParameters['edit'] == '1',
        ),
      ),
      GoRoute(
        path: AppRoutes.finishSession,
        builder: (c, s) => FinishScreen(
          sessionId: s.pathParameters['xid']!,
          edit: s.uri.queryParameters['edit'] == '1',
        ),
      ),
      GoRoute(path: AppRoutes.student, builder: (c, s) => StudentScreen(sid: s.pathParameters['sid']!)),
      GoRoute(path: AppRoutes.payment, builder: (c, s) => PaymentScreen(sid: s.pathParameters['sid']!)),
      GoRoute(path: AppRoutes.sync, builder: (c, s) => const SyncScreen()),
      GoRoute(path: AppRoutes.changePin, builder: (c, s) => const ChangePinScreen()),
    ],
  );
});
