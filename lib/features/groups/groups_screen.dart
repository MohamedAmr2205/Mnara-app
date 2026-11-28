import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/common.dart';
import 'package:assistant/core/design/widgets/empty_state.dart';
import 'package:assistant/core/design/widgets/offline_strip.dart';
import 'package:assistant/core/design/widgets/primary_button.dart';
import 'package:assistant/core/design/widgets/stat_tile.dart';
import 'package:assistant/core/design/widgets/status_chip.dart';
import 'package:assistant/core/util/date_utils.dart';
import 'package:assistant/core/util/text_utils.dart';
import 'package:assistant/data/app_controller.dart';
import 'package:assistant/domain/logic.dart';
import 'package:assistant/domain/models.dart';

/// Today's groups with filters, connection badge and resume card.
class GroupsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  int _grade = 0; // 0 = all
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider);
    final today = dateOnly(ref.watch(clockProvider)());

    if (s.groups.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: EmptyState(
            title: 'لسه مفيش مجاميع عندك',
            message:
                'المدرس لسه ما ضافش مجاميع لحسابك، أو لسه ما اتحمّلتش على الموبايل.',
            action: PrimaryButton(
              label: 'حمّل المجاميع من جديد',
              onPressed: () => ref.read(appProvider.notifier).reloadDemoData(),
            ),
            footnote: 'لو الموضوع فضل زي ما هو، كلّم المدرس يتأكد إن رقمك متسجّل.',
          ),
        ),
      );
    }

    final q = normalizeSearch(_query);
    final groups = s.groups.where((g) {
      if (_grade != 0 && g.grade != _grade) return false;
      if (q.isNotEmpty && !normalizeSearch(g.name).contains(q)) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        final ta = a.weekday == today.weekday ? 0 : 1;
        final tb = b.weekday == today.weekday ? 0 : 1;
        if (ta != tb) return ta - tb;
        return a.hour.compareTo(b.hour);
      });

    Session? open;
    if (s.activeSessionId != null) open = sessionById(s, s.activeSessionId!);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('أهلا يا أسيستنت', style: MnaraText.body(MnaraColors.muted)),
                      const SizedBox(height: 2),
                      Text('مجاميع النهارده', style: MnaraText.h1()),
                    ],
                  ),
                ),
                const ConnectivityBadge(),
              ],
            ),
            const SizedBox(height: 14),
            if (open != null) ...[
              _ResumeCard(session: open),
              const SizedBox(height: 14),
            ],
            if (!s.online) ...[
              OfflineStrip(onTap: () => context.push('/sync')),
              const SizedBox(height: 12),
            ],
            TextField(
              onChanged: (v) => setState(() => _query = v),
              style: MnaraText.body(),
              decoration: mnaraInput(
                hint: 'دوّر على مجموعة',
                prefix: const Icon(Icons.search, color: MnaraColors.muted),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final e in const [
                    (0, 'الكل'),
                    (1, 'أولى'),
                    (2, 'تانية'),
                    (3, 'تالتة'),
                  ]) ...[
                    FilterPill(
                      label: e.$2,
                      selected: _grade == e.$1,
                      onTap: () => setState(() => _grade = e.$1),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (groups.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'مفيش مجموعة بالاسم ده',
                    style: MnaraText.body(MnaraColors.muted),
                  ),
                ),
              ),
            for (final g in groups) ...[
              _GroupCard(group: g, today: today),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends ConsumerWidget {
  const _GroupCard({required this.group, required this.today});

  final Group group;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appProvider);
    final isToday = group.weekday == today.weekday;
    final count = studentsOfGroup(s, group.id).length;
    final next = nextOccurrence(today, group.weekday);
    return Semantics(
      button: true,
      label: group.name,
      child: AppCard(
        borderColor: isToday ? MnaraColors.accent : null,
        onTap: () => context.push('/groups/${group.id}'),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(group.name, style: MnaraText.h4())),
                      if (isToday) ...[
                        const SizedBox(width: 8),
                        const StatusChip(label: 'النهارده', tone: StatusTone.sel),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(groupWhen(group), style: MnaraText.caption()),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('$count طالب', style: MnaraText.smallStrong()),
                      const SizedBox(width: 10),
                      Text(gradeLabel(group.grade), style: MnaraText.caption()),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الحصة الجاية: ${formatDateWithDay(next)}',
                    style: MnaraText.caption(),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left, color: MnaraColors.muted),
          ],
        ),
      ),
    );
  }
}

class _ResumeCard extends ConsumerWidget {
  const _ResumeCard({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appProvider);
    final g = groupById(s, session.groupId);
    final c = countsOf(session);
    return AppCard(
      borderColor: MnaraColors.amber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'فيه حصة مفتوحة ما اتقفلتش',
            style: MnaraText.h4(MnaraColors.amber),
          ),
          const SizedBox(height: 6),
          Text(g?.name ?? '', style: MnaraText.bodyStrong()),
          Text(
            '${formatDateWithDay(parseDateKey(session.date))} · حصة ${session.number} · شهر ${session.month}',
            style: MnaraText.caption(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: StatTile(value: '${c.marked}', label: 'اتسجّلوا')),
              const SizedBox(width: 10),
              Expanded(child: StatTile(value: '${c.unmarked}', label: 'فاضلين')),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'التطبيق اتقفل قبل ما تنهي الحصة. كل اللي سجّلته محفوظ على الموبايل.',
            style: MnaraText.small(MnaraColors.muted),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'كمّل الحصة',
            onPressed: () => context.push('/session/${session.id}'),
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: () => _confirmCancel(context, ref, c.marked),
              child: Text(
                'إلغاء الحصة دي',
                style: MnaraText.bodyStrong(MnaraColors.redText),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    int marked,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MnaraColors.card,
        title: Text('متأكد؟', style: MnaraText.h3()),
        content: Text(
          'الـ $marked طالب اللي سجّلتهم هيتمسحوا.',
          style: MnaraText.body(MnaraColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('رجوع', style: MnaraText.bodyStrong()),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'امسح وابدأ من الأول',
              style: MnaraText.bodyStrong(MnaraColors.redText),
            ),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      ref.read(appProvider.notifier).cancelSession(session.id);
    }
  }
}
