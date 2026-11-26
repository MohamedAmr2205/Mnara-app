import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:assistant/app/routes.dart';
import 'package:assistant/core/design/mnara_logo.dart';
import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/bottom_sheet_scaffold.dart';
import 'package:assistant/core/design/widgets/primary_button.dart';
import 'package:assistant/core/design/widgets/screen_parts.dart';
import 'package:assistant/core/security/auth_controller.dart';
import 'package:assistant/core/sync/sync_tracker.dart';
import 'package:assistant/core/sync/write_service.dart';
import 'package:assistant/features/shared/derived.dart';

/// App version string (from the platform).
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});

/// Settings tab.
class SettingsScreen extends ConsumerWidget {
  /// Creates the screen.
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final pending = ref.read(pendingCountProvider);
    final notifier = ref.read(authControllerProvider.notifier);
    final warmer = ref.read(cacheWarmerProvider);
    final router = GoRouter.of(context);

    Future<void> doLogout() async {
      await notifier.logout();
      try {
        await warmer.wipe();
      } catch (_) {}
      // The Firestore instance cannot be reused after terminate(), so the app
      // closes; the next launch starts clean at the sign-in screen.
      await SystemNavigator.pop();
    }

    if (pending == 0) {
      await doLogout();
      return;
    }
    final choice = await showMnaraSheet<String>(
      context: context,
      builder: (ctx) => BottomSheetScaffold(
        title: 'تسجيل خروج؟',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MnaraCard(
              color: MnaraColors.amberBg,
              borderColor: MnaraColors.amber,
              child: Text(
                'فيه $pending حاجات لسه ما اترفعتش. لو خرجت قبل الرفع ممكن تضيع. ارفع الأول.',
                style: MnaraText.small(MnaraColors.amber),
              ),
            ),
            const SizedBox(height: 14),
            PrimaryButton(label: 'ارفع الأول', onPressed: () => Navigator.of(ctx).pop('sync')),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('out'),
              child: Text('اخرج برضه', style: MnaraText.bodyStrong(MnaraColors.redText)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('cancel'),
              child: Text('إلغاء', style: MnaraText.bodyStrong(MnaraColors.muted)),
            ),
          ],
        ),
      ),
    );
    if (choice == 'sync') {
      router.push(AppRoutes.sync);
    } else if (choice == 'out') {
      await doLogout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacher = ref.watch(teacherOrDefaultProvider);
    final auto = ref.watch(autoUploadProvider);
    final pending = ref.watch(pendingCountProvider);
    final version = ref.watch(appVersionProvider).valueOrNull ?? '';
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          const TabTitle(title: 'الإعدادات'),
          MnaraCard(
            child: Row(
              children: [
                CircleAvatar(radius: 26, backgroundColor: MnaraColors.sel, child: Text('أ', style: MnaraText.h3())),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الأسيستنت', style: MnaraText.h4()),
                      Text('مدرس: ${teacher.name}', style: MnaraText.small(MnaraColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          MnaraCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: MnaraColors.accent,
              title: Text('رفع تلقائي', style: MnaraText.bodyStrong()),
              subtitle: Text('يرفع لوحده أول ما النت يرجع', style: MnaraText.caption()),
              value: auto,
              onChanged: (v) => ref.read(autoUploadProvider.notifier).set(v),
            ),
          ),
          const SizedBox(height: 8),
          _NavRow(label: 'تغيير الـ PIN', onTap: () => context.push(AppRoutes.changePin)),
          const SizedBox(height: 8),
          _NavRow(
            label: 'المزامنة',
            sub: pending > 0 ? '$pending مستنيين الرفع' : 'كله متزامن',
            subColor: pending > 0 ? MnaraColors.amber : MnaraColors.green,
            onTap: () => context.push(AppRoutes.sync),
          ),
          const SizedBox(height: 12),
          MnaraCard(
            child: Row(
              children: [
                const MnaraLogo(height: 52, wordmarkSize: 16),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(version.isEmpty ? 'نسخة تجريبية' : 'نسخة $version (تجريبية)', style: MnaraText.small(MnaraColors.muted)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Material(
            color: MnaraColors.redBg,
            borderRadius: BorderRadius.circular(MnaraRadii.r18),
            child: InkWell(
              borderRadius: BorderRadius.circular(MnaraRadii.r18),
              onTap: () => _logout(context, ref),
              child: SizedBox(
                height: 56,
                child: Center(child: Text('تسجيل خروج', style: MnaraText.button(MnaraColors.redText))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.label, required this.onTap, this.sub, this.subColor = MnaraColors.muted});

  final String label;
  final String? sub;
  final Color subColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MnaraCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: MnaraText.bodyStrong()),
                if (sub != null) Text(sub!, style: MnaraText.caption(subColor)),
              ],
            ),
          ),
          const Icon(Icons.chevron_left, color: MnaraColors.muted),
        ],
      ),
    );
  }
}
