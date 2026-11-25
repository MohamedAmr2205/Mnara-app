import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:assistant/core/design/widgets/app_nav_bar.dart';

/// Shell for the four main tabs with the persistent bottom navigation bar.
class TabsScaffold extends StatelessWidget {
  /// Creates the shell around the active tab's navigator.
  const TabsScaffold({super.key, required this.shell});

  /// Router shell that owns the tab branches.
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: AppNavBar(
        currentIndex: shell.currentIndex,
        onTap: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
      ),
    );
  }
}
