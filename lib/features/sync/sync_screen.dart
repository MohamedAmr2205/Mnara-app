import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/common.dart';
import 'package:assistant/core/design/widgets/primary_button.dart';
import 'package:assistant/core/design/widgets/status_chip.dart';
import 'package:assistant/core/util/date_utils.dart';
import 'package:assistant/data/app_controller.dart';
import 'package:assistant/domain/logic.dart';

/// Upload queue and connection status.
///
/// Local mode: there is no server yet, so "upload" marks items as synced
/// and the connection switch is a debug-only simulation.
class SyncScreen extends ConsumerWidget {
  /// Creates the screen.
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appProvider);
    final controller = ref.read(appProvider.notifier);
    final today = dateOnly(ref.watch(clockProvider)());
    final items = syncItems(s);
    final pending = items.where((i) => i.pending).toList();
    final uploadedToday = items.where((i) {
      if (i.pending) return false;
      final d = DateTime.fromMillisecondsSinceEpoch(i.syncedAt!);
      return dateOnly(d) == today;
    }).toList();
    final shown = pending.isNotEmpty ? pending : uploadedToday;

    final (title, sub, color) = !s.online
        ? ('مفيش نت', '${pending.length} مستنيين الرفع. كمّل شغلك عادي.', MnaraColors.amber)
        : pending.isEmpty
        ? ('متصل · كله متزامن', 'آخر رفع: ${_lastUpload(s.lastUploadAtMs)}', MnaraColors.green)
        : ('متصل', '${pending.length} جاهزين للرفع', MnaraColors.green);

    final canUpload = s.online && pending.isNotEmpty;
    final ctaLabel = canUpload
        ? 'ارفع دلوقتي'
        : !s.online
        ? 'مستني النت عشان يرفع'
        : 'مفيش حاجة للرفع';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(title: 'المزامنة'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  AppCard(
                    borderColor: color,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: MnaraText.h4(color)),
                              const SizedBox(height: 2),
                              Text(sub, style: MnaraText.caption()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 10),
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'للتجربة فقط: محاكاة قطع النت',
                              style: MnaraText.small(MnaraColors.muted),
                            ),
                          ),
                          Switch(
                            value: !s.online,
                            onChanged: (v) => controller.setOnline(!v),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    pending.isNotEmpty
                        ? 'مستني الرفع (${pending.length})'
                        : 'اترفع النهارده',
                    style: MnaraText.h4(),
                  ),
                  const SizedBox(height: 10),
                  if (pending.isEmpty) ...[
                    const InfoBanner(
                      text: 'كل حاجة اترفعت. الداشبورد بتاع المدرس اتحدّث.',
                      tone: StatusTone.green,
                    ),
                    const SizedBox(height: 10),
                  ],
                  for (final i in shown) ...[
                    _Row(item: i, online: s.online),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            StickyCta(
              child: PrimaryButton(
                label: ctaLabel,
                icon: canUpload ? Icons.cloud_upload_outlined : null,
                onPressed: canUpload ? controller.uploadAll : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _lastUpload(int? ms) {
    if (ms == null) return 'لسه';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${formatDateShort(d)} $h:$m';
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.online});

  final SyncItem item;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final icon = switch (item.kind) {
      SyncKind.session => Icons.event_note_outlined,
      SyncKind.payment => Icons.payments_outlined,
      SyncKind.student => Icons.person_add_alt_1_outlined,
    };
    final (label, tone) = item.pending
        ? (online
              ? ('جاهز للرفع', StatusTone.sel)
              : ('مستني النت', StatusTone.amber))
        : ('اترفع', StatusTone.green);
    return AppCard(
      padding: const EdgeInsets.all(12),
      radius: MnaraRadii.r14,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: MnaraColors.card2,
              borderRadius: BorderRadius.circular(MnaraRadii.r12),
            ),
            child: Icon(icon, size: 20, color: MnaraColors.text),
          ),
          const SizedBox(width: 12),
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
    );
  }
}
