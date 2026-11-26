import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:assistant/app/routes.dart';
import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/primary_button.dart';
import 'package:assistant/core/design/widgets/screen_parts.dart';
import 'package:assistant/core/design/widgets/status_chip.dart';
import 'package:assistant/core/sync/sync_tracker.dart';
import 'package:assistant/core/utils/cairo_time.dart';
import 'package:assistant/data/models/models.dart';
import 'package:assistant/data/providers.dart';
import 'package:assistant/features/shared/derived.dart';

/// Past sessions with the 10-day edit window.
class HistoryScreen extends ConsumerWidget {
  /// Creates the screen.
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sessionsProvider);
    final groups = ref.watch(groupMapProvider);
    final pendingKeys = ref.watch(pendingKeysProvider);
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TabTitle(title: 'سجل الحصص'),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator(color: MnaraColors.accent)),
              error: (e, _) => Center(child: Text('مقدرناش نقرا السجل', style: MnaraText.body(MnaraColors.muted))),
              data: (sessions) => ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  MnaraCard(
                    color: MnaraColors.card2,
                    child: Text(
                      'تقدر تعدّل أي حصة لحد 10 أيام من تاريخها. بعد كده بتتقفل، والتعديل يبقى من المدرس.',
                      style: MnaraText.small(MnaraColors.muted),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (sessions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(child: Text('لسه مفيش حصص اتسجّلت', style: MnaraText.body(MnaraColors.muted))),
                    ),
                  for (final s in sessions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SessionCard(
                        session: s,
                        groupName: groups[s.groupId]?.name ?? '',
                        waiting: s.pending || pendingKeys.contains('session:${s.id}'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.session, required this.groupName, required this.waiting});

  final Session session;
  final String groupName;
  final bool waiting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(sessionRecordsProvider(session.id)).valueOrNull ?? const <SessionRecord>[];
    final present = records.where((r) => r.attendance?.attended ?? false).length;
    final absent = records.where((r) => r.attendance != null && !r.attendance!.attended).length;
    final editable = isEditable(session.editableUntil);
    final left = editDaysLeft(session.date);
    return MnaraCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(groupName, style: MnaraText.h4())),
              StatusChip(
                label: waiting ? 'مستنية النت' : 'اترفعت',
                tone: waiting ? StatusTone.amber : StatusTone.green,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${weekdayOfIso(session.date)} ${formatDm(session.date)} · ${session.label}${session.isOpen ? ' · لسه مفتوحة' : ''}',
            style: MnaraText.small(MnaraColors.muted),
          ),
          const SizedBox(height: 6),
          Text('حضور: $present   غياب: $absent', style: MnaraText.small()),
          const SizedBox(height: 10),
          if (editable)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'باقي ${left < 0 ? 0 : left} أيام للتعديل',
                    style: MnaraText.small(left <= 3 ? MnaraColors.amber : MnaraColors.muted),
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: PrimaryButton(
                    label: 'تعديل',
                    height: 44,
                    onPressed: () => context.go(AppRoutes.sessionPath(session.id, edit: true)),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                const Icon(Icons.lock_outline, size: 18, color: MnaraColors.muted),
                const SizedBox(width: 6),
                Expanded(child: Text('مقفولة · عدّى عليها أكتر من 10 أيام', style: MnaraText.small(MnaraColors.muted))),
              ],
            ),
        ],
      ),
    );
  }
}
