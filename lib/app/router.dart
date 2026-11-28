import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:assistant/app/tabs_scaffold.dart';
import 'package:assistant/data/app_controller.dart';
import 'package:assistant/features/groups/group_screen.dart';
import 'package:assistant/features/groups/groups_screen.dart';
import 'package:assistant/features/groups/start_session_screen.dart';
import 'package:assistant/features/history/history_screen.dart';
import 'package:assistant/features/lock/lock_screen.dart';
import 'package:assistant/features/payment/payment_screen.dart';
import 'package:assistant/features/search/search_screen.dart';
import 'package:assistant/features/session/finish_screen.dart';
import 'package:assistant/features/session/session_screen.dart';
import 'package:assistant/features/settings/change_pin_screen.dart';
import 'package:assistant/features/settings/settings_screen.dart';
import 'package:assistant/features/student/student_screen.dart';
import 'package:assistant/features/sync/sync_screen.dart';

/// Route paths from the screen table (the session screens hide the nav bar).
abstract final class AppRoutes {
  static const String lock = '/lock';
  static const String groups = '/groups';
  static const String search = '/search';
  static const String history = '/history';
  static const String settings = '/settings';
  static const String changePin = '/settings/pin';
  static const String sync = '/sync';
  static const String group = '/groups/:gid';
  static const String startSession = '/groups/:gid/start';
  static const String session = '/session/:xid';
  static const String finishSession = '/session/:xid/finish';
  static const String student = '/students/:sid';
  static const String payment = '/students/:sid/pay';
}

/// App router. Everything except the lock screen requires the PIN gate to be
/// open for this app run; locking again (logout) returns to the lock screen.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<bool>(unlockedProvider, (previous, next) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'root'),
    initialLocation: AppRoutes.lock,
    refreshListenable: refresh,
    redirect: (context, state) {
      final unlocked = ref.read(unlockedProvider);
      final atLock = state.matchedLocation == AppRoutes.lock;
      if (!unlocked && !atLock) return AppRoutes.lock;
      if (unlocked && atLock) return AppRoutes.groups;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.lock,
        builder: (context, state) => const LockScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => TabsScaffold(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.groups,
                builder: (context, state) => const GroupsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.search,
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.history,
                builder: (context, state) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.changePin,
        builder: (context, state) => const ChangePinScreen(),
      ),
      GoRoute(
        path: AppRoutes.sync,
        builder: (context, state) => const SyncScreen(),
      ),
      GoRoute(
        path: AppRoutes.group,
        builder: (context, state) =>
            GroupScreen(groupId: state.pathParameters['gid']!),
      ),
      GoRoute(
        path: AppRoutes.startSession,
        builder: (context, state) =>
            StartSessionScreen(groupId: state.pathParameters['gid']!),
      ),
      GoRoute(
        path: AppRoutes.session,
        builder: (context, state) =>
            SessionScreen(xid: state.pathParameters['xid']!),
      ),
      GoRoute(
        path: AppRoutes.finishSession,
        builder: (context, state) =>
            FinishScreen(xid: state.pathParameters['xid']!),
      ),
      GoRoute(
        path: AppRoutes.student,
        builder: (context, state) =>
            StudentScreen(studentId: state.pathParameters['sid']!),
      ),
      GoRoute(
        path: AppRoutes.payment,
        builder: (context, state) =>
            PaymentScreen(studentId: state.pathParameters['sid']!),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
