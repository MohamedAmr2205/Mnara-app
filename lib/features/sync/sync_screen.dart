import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/primary_button.dart';
import 'package:assistant/core/design/widgets/screen_parts.dart';
import 'package:assistant/core/design/widgets/status_chip.dart';
import 'package:assistant/core/sync/connectivity.dart';
import 'package:assistant/core/sync/sync_tracker.dart';
import 'package:assistant/core/sync/write_service.dart';

/// What is waiting to upload, what failed, and a manual upload button.
class SyncScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  bool _uploading = false;

  Future<void> _upload() async {
    setState(() => _uploading = true);
    try {
      await ref.read(syncServiceProvider).uploadNow();
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(syncItemsProvider);
    final online = ref.watch(isOnlineProvider);
    final pending = items.where((i) => i.isPending).toList();
    final done = items.where((i) => !i.isPending).toList();
    final failed = pending.any((i) => i.state == SyncState.failed);

    final (title, subtitle, color) = !online
        ? ('مفيش نت', '${pending.length} مستنيين الرفع. كمّل شغلك عادي.', MnaraColors.amber)
        : failed
        ? ('فيه حاجة فشلت', 'اضغط حاول تاني على الصف الأحمر.', MnaraColors.redText)
        : pending.isEmpty
        ? ('متصل · كله متزامن', done.isEmpty ? 'مفيش حاجة مستنية' : 'آخر رفع: دلوقتي', MnaraColors.green)
        : ('متصل', '${pending.length} جاهزين للرفع', MnaraColors.green);

    final String ctaLabel;
    VoidCallback? onCta;
    if (_uploading) {
      ctaLabel = 'بيرفع...';
    } else if (pending.isEmpty) {
      ctaLabel = 'مفيش حاجة للرفع';
    } else if (!online) {
      ctaLabel = 'مستني النت عشان يرفع';
    } else if (failed && pending.every((i) => i.state == SyncState.failed)) {
      ctaLabel = 'حاول تاني على الصف الأحمر';
    } else {
      ctaLabel = 'ارفع دلوقتي';
      onCta = _upload;
    }

    return Scaffold(
      backgroundColor: MnaraColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(title: 'المزامنة', onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  MnaraCard(
                    borderColor: color,
                    child: Row(
                      children: [
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(liveRegion: true, child: Text(title, style: MnaraText.h4(color))),
                              Text(subtitle, style: MnaraText.small(MnaraColors.muted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 10),
                    MnaraCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('اقطع النت (للتجربة بس)', style: MnaraText.bodyStrong()),
                        subtitle: Text('بيظهر في نسخة الديبج بس', style: MnaraText.caption()),
                        value: ref.watch(debugOfflineProvider),
                        onChanged: (v) => ref.read(debugOfflineProvider.notifier).set(v),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(pending.isNotEmpty ? 'مستني الرفع (${pending.length})' : 'اترفع النهارده', style: MnaraText.h4()),
                  const SizedBox(height: 8),
                  if (pending.isEmpty && done.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(child: Text('مفيش حاجة مستنية الرفع', style: MnaraText.body(MnaraColors.muted))),
                    ),
                  for (final item in [...pending, if (pending.isEmpty) ...done])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ItemRow(
                        item: item,
                        onRetry: () => ref.read(syncTrackerProvider.notifier).retry(item.key),
                      ),
                    ),
                  if (pending.isEmpty && done.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    MnaraCard(
                      color: MnaraColors.greenBg,
                      borderColor: MnaraColors.green,
                      child: Text('كل حاجة اترفعت. الداشبورد بتاع المدرس اتحدّث.', style: MnaraText.small(MnaraColors.green)),
                    ),
                  ],
                ],
              ),
            ),
            BottomBar(child: PrimaryButton(label: ctaLabel, onPressed: onCta)),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.onRetry});

  final SyncItem item;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final icon = switch (item.kind) {
      SyncKind.session => Icons.fact_check_outlined,
      SyncKind.payment => Icons.payments_outlined,
      SyncKind.student => Icons.person_add_alt,
    };
    final (label, tone) = switch (item.state) {
      SyncState.ready => ('جاهز للرفع', StatusTone.sel),
      SyncState.waiting => ('مستني النت', StatusTone.amber),
      SyncState.uploaded => ('اترفع', StatusTone.green),
      SyncState.failed => ('فشل', StatusTone.red),
    };
    final failed = item.state == SyncState.failed;
    return MnaraCard(
      borderColor: failed ? MnaraColors.red : MnaraColors.line,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: MnaraColors.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: MnaraText.bodyStrong()),
                    Text(item.subtitle, style: MnaraText.caption()),
                  ],
                ),
              ),
              StatusChip(label: label, tone: tone),
            ],
          ),
          if (failed) ...[
            const SizedBox(height: 8),
            Text('فشل الرفع: السيرفر ما ردش. بياناتك سليمة على الموبايل.', style: MnaraText.small(MnaraColors.redText)),
            const SizedBox(height: 8),
            PrimaryButton(label: 'حاول تاني', height: 48, onPressed: onRetry),
          ],
        ],
      ),
    );
  }
}
