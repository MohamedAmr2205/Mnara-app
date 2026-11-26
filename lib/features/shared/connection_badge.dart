import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:assistant/app/routes.dart';
import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/sync/connectivity.dart';
import 'package:assistant/core/sync/sync_tracker.dart';

/// Connection status pill that opens the Sync screen.
class ConnectionBadge extends ConsumerWidget {
  /// Creates the badge.
  const ConnectionBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider);
    final pending = ref.watch(pendingCountProvider);
    final color = online ? MnaraColors.green : MnaraColors.amber;
    final bg = online ? MnaraColors.greenBg : MnaraColors.amberBg;
    final label = online ? 'متصل' : 'مفيش نت · $pending مستنيين';
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push(AppRoutes.sync),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(MnaraRadii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(label, style: MnaraText.captionStrong(color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
