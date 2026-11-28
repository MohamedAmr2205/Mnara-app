import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/common.dart';
import 'package:assistant/core/design/widgets/status_chip.dart';
import 'package:assistant/core/util/date_utils.dart';
import 'package:assistant/data/app_controller.dart';
import 'package:assistant/domain/logic.dart';
import 'package:assistant/domain/models.dart';

/// Saved sessions, editable for [editWindowDays] days after their date.
class HistoryScreen extends ConsumerWidget {
  /// Creates the screen.
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appProvider);
    final today = dateOnly(ref.watch(clockProvider)());
    final sessions = s.sessions
        .where((x) => x.status == SessionStatus.closed)
        .toList()
      ..sort((a, b) {
        final c = b.date.compareTo(a.date);
        return c != 0 ? c : b.createdAtMs.compareTo(a.createdAtMs);
      });

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(
              title: 'سجل الحصص',
              showBack: false,
              trailing: HeaderLogo(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  const InfoBanner(
                    text:
                        'تقدر تعدّل أي حصة لحد 10 أيام من تاريخها. بعد كده بتتقفل، والتعديل يبقى من المدرس.',
                    tone: StatusTone.sel,
                  ),
                  const SizedBox(height: 12),
                  if (sessions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'لسه مفيش حصص اتحفظت',
                          style: MnaraText.body(MnaraColors.muted),
                        ),
                      ),
                    ),
                  for (final x in sessions) ...[
                    _SessionCard(session: x, today: today),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.session, required this.today});

  final Session session;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appProvider);
    final g = groupById(s, session.groupId);
    final c = countsOf(session);
    final date = parseDateKey(session.date);
    final left = editDaysLeft(today, session.date);
    final editable = left > 0;
    final synced = session.syncedAt != null;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(g?.name ?? '', style: MnaraText.h4())),
              StatusChip(
                label: synced ? 'اترفعت' : 'مستنية النت',
                tone: synced ? StatusTone.green : StatusTone.amber,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${formatDateWithDay(date)} · حصة ${session.number} · شهر ${session.month}',
            style: MnaraText.caption(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('حضور: ${c.present + c.late}', style: MnaraText.smallStrong()),
              const SizedBox(width: 14),
              Text(
                'غياب: ${c.absent + c.excused}',
                style: MnaraText.smallStrong(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (editable)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'باقي $left ${left == 1 ? 'يوم' : 'أيام'} للتعديل',
                    style: MnaraText.small(
                      left <= 3 ? MnaraColors.amber : MnaraColors.muted,
                    ),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.push('/session/${session.id}'),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    decoration: BoxDecoration(
                      color: MnaraColors.primary,
                      borderRadius: BorderRadius.circular(MnaraRadii.r12),
                    ),
                    child: Text('تعديل', style: MnaraText.bodyStrong()),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: MnaraColors.card2,
                borderRadius: BorderRadius.circular(MnaraRadii.r12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, size: 18, color: MnaraColors.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'مقفولة · عدّى عليها أكتر من 10 أيام',
                      style: MnaraText.small(MnaraColors.muted),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
