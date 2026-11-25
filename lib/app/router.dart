import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:assistant/app/route_placeholder.dart';
import 'package:assistant/app/tabs_scaffold.dart';

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

GoRoute _route(String path, String title, String milestone) {
  return GoRoute(
    path: path,
    builder: (context, state) =>
        RoutePlaceholder(title: title, milestone: milestone),
  );
}

StatefulShellBranch _tab(String path, String title, String milestone) {
  return StatefulShellBranch(routes: [_route(path, title, milestone)]);
}

/// App router; auth/lock redirect guards are added in M1.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'root'),
    initialLocation: AppRoutes.lock,
    routes: [
      _route(AppRoutes.lock, 'دخول بالـ PIN', 'M1'),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => TabsScaffold(shell: shell),
        branches: [
          _tab(AppRoutes.groups, 'المجاميع', 'M3'),
          _tab(AppRoutes.search, 'بحث عن طالب', 'M4'),
          _tab(AppRoutes.history, 'سجل الحصص', 'M5'),
          _tab(AppRoutes.settings, 'الإعدادات', 'M5'),
        ],
      ),
      _route(AppRoutes.group, 'تفاصيل المجموعة', 'M3'),
      _route(AppRoutes.startSession, 'بدء حصة جديدة', 'M3'),
      _route(AppRoutes.session, 'الحصة', 'M3'),
      _route(AppRoutes.finishSession, 'إنهاء الحصة', 'M3'),
      _route(AppRoutes.student, 'بروفايل الطالب', 'M4'),
      _route(AppRoutes.payment, 'تسجيل دفعة', 'M4'),
      _route(AppRoutes.sync, 'المزامنة', 'M5'),
      _route(AppRoutes.changePin, 'تغيير الـ PIN', 'M1'),
    ],
  );
});
