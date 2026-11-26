import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:assistant/app/routes.dart';
import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/empty_state.dart';
import 'package:assistant/core/design/widgets/offline_strip.dart';
import 'package:assistant/core/design/widgets/primary_button.dart';
import 'package:assistant/core/design/widgets/screen_parts.dart';
import 'package:assistant/core/design/widgets/status_chip.dart';
import 'package:assistant/core/design/widgets/stat_tile.dart';
import 'package:assistant/core/design/widgets/bottom_sheet_scaffold.dart';
import 'package:assistant/core/security/auth_controller.dart';
import 'package:assistant/core/sync/connectivity.dart';
import 'package:assistant/core/utils/arabic_text.dart';
import 'package:assistant/core/utils/cairo_time.dart';
import 'package:assistant/data/models/models.dart';
import 'package:assistant/data/providers.dart';
import 'package:assistant/features/shared/connection_badge.dart';
import 'package:assistant/features/shared/derived.dart';

/// Main tab: today's groups (or the Resume card when a session is open).
class GroupsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  int _year = 0;
  String _query = '';
  bool _reloading = false;
  String? _reloadError;

  Future<void> _reload() async {
    final tid = ref.read(authControllerProvider).teacherId;
    if (tid == null) return;
    setState(() {
      _reloading = true;
      _reloadError = null;
    });
    try {
      await ref.read(cacheWarmerProvider).warm(tid);
    } catch (_) {
      _reloadError = 'مقدرناش نحمّل. اتأكد إن النت شغال.';
    }
    if (mounted) setState(() => _reloading = false);
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsProvider);
    final students = ref.watch(studentsProvider).valueOrNull ?? const <Student>[];
    final online = ref.watch(isOnlineProvider);
    final meta = ref.watch(metaProvider).valueOrNull;
    final dismissed = ref.watch(resumeDismissedProvider);
    final sessions = ref.watch(sessionMapProvider);
    final activeId = meta?.activeSessionId;
    final active = activeId == null ? null : sessions[activeId];
    final today = todayIso();

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('أهلا يا أسيستنت', style: MnaraText.caption()),
                      Text('مجاميع النهارده', style: MnaraText.h1()),
                    ],
                  ),
                ),
                const ConnectionBadge(),
              ],
            ),
          ),
          if (!online)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: OfflineStrip(onTap: () => context.push(AppRoutes.sync)),
            ),
          Expanded(
            child: groupsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: MnaraColors.accent)),
              error: (e, _) => EmptyState(title: 'حصلت مشكلة', message: 'مقدرناش نقرا المجاميع من الموبايل.'),
              data: (groups) {
                if (active != null && active.isOpen && !dismissed) {
                  return ResumeView(session: active, groups: groups);
                }
                if (groups.isEmpty) {
                  return EmptyState(
                    title: 'لسه مفيش مجاميع عندك',
                    message: 'المدرس لسه ما ضافش مجاميع لحسابك، أو لسه ما اتحمّلتش على الموبايل.',
                    action: PrimaryButton(
                      label: _reloading ? 'بنحمّل...' : 'حمّل المجاميع من جديد',
                      onPressed: _reloading ? null : _reload,
                    ),
                    footnote: _reloadError ?? 'لو الموضوع فضل زي ما هو، كلّم المدرس يتأكد إن رقمك متسجّل.',
                  );
                }
                final shown = groups.where((g) {
                  if (_year != 0 && g.year != _year) return false;
                  return matchesStudent(query: _query, code: g.name, name: g.name);
                }).toList();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    MnaraTextField(
                      hint: 'دوّر على مجموعة',
                      prefix: const Icon(Icons.search, color: MnaraColors.muted),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final (label, y) in const [('الكل', 0), ('أولى', 1), ('تانية', 2), ('تالتة', 3)]) ...[
                            ChoicePill(label: label, selected: _year == y, onTap: () => setState(() => _year = y)),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (shown.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(child: Text('مفيش مجموعة بالاسم ده', style: MnaraText.body(MnaraColors.muted))),
                      ),
                    for (final g in shown)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _GroupCard(
                          group: g,
                          isToday: g.meetsOn(today),
                          count: students.where((s) => s.groupId == g.id && s.active).length,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends ConsumerWidget {
  const _GroupCard({required this.group, required this.isToday, required this.count});

  final Group group;
  final bool isToday;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = ref.watch(nextSessionProvider(group.id));
    return MnaraCard(
      borderColor: isToday ? MnaraColors.accent : MnaraColors.line,
      onTap: () => context.push(AppRoutes.groupPath(group.id)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(group.name, style: MnaraText.h4(), overflow: TextOverflow.ellipsis)),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      const StatusChip(label: 'النهارده', tone: StatusTone.sel),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(group.when, style: MnaraText.small(MnaraColors.muted)),
                const SizedBox(height: 4),
                Text(
                  '$count طالب · ${group.gradeLabel}',
                  style: MnaraText.small(MnaraColors.muted),
                ),
                Text(
                  'الحصة الجاية: حصة ${next.number} · شهر ${next.monthNumber}',
                  style: MnaraText.small(MnaraColors.muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_left, color: MnaraColors.muted),
        ],
      ),
    );
  }
}

/// Resume screen content: an unfinished session exists on this device.
class ResumeView extends ConsumerWidget {
  /// Creates the view.
  const ResumeView({super.key, required this.session, required this.groups});

  /// The open session.
  final Session session;

  /// All groups (to find the name).
  final List<Group> groups;

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref, int count) async {
    final ok = await showMnaraSheet<bool>(
      context: context,
      builder: (ctx) => BottomSheetScaffold(
        title: 'إلغاء الحصة دي؟',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'متأكد؟ الـ $count طالب اللي سجّلتهم هيتمسحوا.',
              style: MnaraText.body(MnaraColors.redText),
            ),
            const SizedBox(height: 16),
            _DangerButton(label: 'امسح وابدأ من الأول', onPressed: () => Navigator.of(ctx).pop(true)),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('رجوع', style: MnaraText.bodyStrong(MnaraColors.muted))),
          ],
        ),
      ),
    );
    if (ok == true) {
      await ref.read(dataRepositoryProvider).cancelSession(session.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(sessionRecordsProvider(session.id)).valueOrNull ?? const <SessionRecord>[];
    final students = ref.watch(studentsProvider).valueOrNull ?? const <Student>[];
    final group = groups.where((g) => g.id == session.groupId).firstOrNull;
    final homeIds = {
      for (final s in students)
        if (s.groupId == session.groupId && s.active) s.id,
    };
    final outside = records.where((r) => !homeIds.contains(r.studentId)).length;
    final roster = homeIds.length + outside;
    final recorded = records.length;
    final remaining = roster - recorded < 0 ? 0 : roster - recorded;
    DateTime? last;
    for (final r in records) {
      final t = r.updatedAt;
      if (t != null && (last == null || t.isAfter(last))) last = t;
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        MnaraCard(
          borderColor: MnaraColors.amber,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('فيه حصة مفتوحة ما اتقفلتش', style: MnaraText.bodyStrong(MnaraColors.amber)),
              const SizedBox(height: 6),
              Text(group?.name ?? '', style: MnaraText.h3()),
              Text(
                '${weekdayOfIso(session.date)} ${formatDm(session.date)} · ${session.label}',
                style: MnaraText.small(MnaraColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: StatTile(value: '$recorded', label: 'اتسجّلوا')),
            const SizedBox(width: 8),
            Expanded(child: StatTile(value: '$remaining', label: 'فاضلين')),
            const SizedBox(width: 8),
            Expanded(child: StatTile(value: last == null ? '--' : formatClock(last), label: 'آخر حفظ')),
          ],
        ),
        const SizedBox(height: 12),
        Text('التطبيق اتقفل قبل ما تنهي الحصة. كل اللي سجّلته محفوظ على الموبايل.', style: MnaraText.small(MnaraColors.muted)),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'كمّل الحصة',
          onPressed: () {
            ref.read(resumeDismissedProvider.notifier).dismiss();
            context.go(AppRoutes.sessionPath(session.id));
          },
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => _confirmCancel(context, ref, recorded),
            child: Text('إلغاء الحصة دي', style: MnaraText.bodyStrong(MnaraColors.redText)),
          ),
        ),
        const SizedBox(height: 16),
        Text('باقي المجاميع', style: MnaraText.h4()),
        const SizedBox(height: 8),
        MnaraCard(
          onTap: () => ref.read(resumeDismissedProvider.notifier).dismiss(),
          child: Row(
            children: [
              Expanded(child: Text('شوف كل المجاميع', style: MnaraText.bodyStrong())),
              const Icon(Icons.chevron_left, color: MnaraColors.muted),
            ],
          ),
        ),
      ],
    );
  }
}

class _DangerButton extends StatelessWidget {
  const _DangerButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MnaraColors.red,
      borderRadius: BorderRadius.circular(MnaraRadii.r18),
      child: InkWell(
        borderRadius: BorderRadius.circular(MnaraRadii.r18),
        onTap: onPressed,
        child: SizedBox(
          height: 56,
          child: Center(child: Text(label, style: MnaraText.button(const Color(0xFFFFFFFF)))),
        ),
      ),
    );
  }
}
