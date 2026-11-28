import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:assistant/core/design/mnara_logo.dart';
import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/bottom_sheet_scaffold.dart';
import 'package:assistant/core/design/widgets/common.dart';
import 'package:assistant/core/design/widgets/primary_button.dart';
import 'package:assistant/data/app_controller.dart';
import 'package:assistant/domain/logic.dart';

/// Account, upload preferences, PIN and logout.
class SettingsScreen extends ConsumerWidget {
  /// Creates the screen.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appProvider);
    final controller = ref.read(appProvider.notifier);
    final pending = pendingCount(s);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(
              title: 'الإعدادات',
              showBack: false,
              trailing: HeaderLogo(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  AppCard(
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: MnaraColors.sel,
                            shape: BoxShape.circle,
                          ),
                          child: Text('أ', style: MnaraText.h2()),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('الأسيستنت', style: MnaraText.h3()),
                              const SizedBox(height: 2),
                              Text(
                                'مدرس: ${s.teacher.name}',
                                style: MnaraText.caption(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _SwitchRow(
                          title: 'الرفع التلقائي لما النت يرجع',
                          subtitle: 'الحصص والدفعات بتترفع لوحدها',
                          value: s.autoUpload,
                          onChanged: controller.setAutoUpload,
                        ),
                        const Divider(height: 1, color: MnaraColors.line),
                        _NavRow(
                          icon: Icons.lock_outline,
                          title: 'تغيير الـ PIN',
                          onTap: () => context.push('/settings/pin'),
                        ),
                        const Divider(height: 1, color: MnaraColors.line),
                        _NavRow(
                          icon: Icons.sync,
                          title: 'المزامنة',
                          trailingText: pending > 0
                              ? '$pending مستنيين'
                              : 'كله متزامن',
                          onTap: () => context.push('/sync'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppCard(
                    child: Row(
                      children: [
                        const MnaraLogo(height: 44),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Mnara Assistant', style: MnaraText.bodyStrong()),
                              Text(
                                'نسخة 1.0.0 (تجريبية · بيانات محلية)',
                                style: MnaraText.caption(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _logout(context, ref, pending),
                    child: Container(
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: MnaraColors.redBg,
                        borderRadius: BorderRadius.circular(MnaraRadii.r18),
                        border: Border.all(color: MnaraColors.red),
                      ),
                      child: Text(
                        'تسجيل الخروج',
                        style: MnaraText.button(MnaraColors.redText),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref, int pending) async {
    void lock() => ref.read(unlockedProvider.notifier).state = false;
    if (pending == 0) {
      lock();
      return;
    }
    await showMnaraSheet<void>(
      context: context,
      builder: (ctx) => BottomSheetScaffold(
        title: 'فيه شغل لسه ما اترفعش',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InfoBanner(
              text:
                  'عندك $pending حاجة مستنية الرفع. لو خرجت دلوقتي هتفضل محفوظة على الموبايل وتترفع بعدين.',
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'ارفع الأول',
              onPressed: () {
                Navigator.of(ctx).pop();
                context.push('/sync');
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                lock();
              },
              child: Text(
                'اخرج برضه',
                style: MnaraText.bodyStrong(MnaraColors.redText),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('إلغاء', style: MnaraText.bodyStrong()),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: MnaraText.bodyStrong()),
                Text(subtitle, style: MnaraText.caption()),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailingText,
  });

  final IconData icon;
  final String title;
  final String? trailingText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(icon, color: MnaraColors.text, size: 22),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: MnaraText.bodyStrong())),
                if (trailingText != null) ...[
                  Text(trailingText!, style: MnaraText.caption()),
                  const SizedBox(width: 6),
                ],
                const Icon(Icons.chevron_left, color: MnaraColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
