import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:assistant/app/router.dart';
import 'package:assistant/app/session_guard.dart';
import 'package:assistant/core/security/auth_controller.dart';
import 'package:assistant/core/design/theme.dart';

/// Root widget: Arabic (RTL), dark-only, driven by go_router.
class MnaraApp extends ConsumerWidget {
  /// Creates the app root.
  const MnaraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Mnara',
      debugShowCheckedModeBanner: false,
      theme: buildMnaraTheme(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        final unlocked = ref.watch(authControllerProvider).phase == AuthPhase.unlocked;
        final content = child ?? const SizedBox.shrink();
        return unlocked ? SessionGuard(child: content) : content;
      },
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [Locale('ar', 'EG')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
