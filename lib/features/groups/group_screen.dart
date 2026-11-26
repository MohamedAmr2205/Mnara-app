import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:assistant/app/routes.dart';
import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/code_badge.dart';
import 'package:assistant/core/design/widgets/primary_button.dart';
import 'package:assistant/core/design/widgets/screen_parts.dart';
import 'package:assistant/core/design/widgets/stat_tile.dart';
import 'package:assistant/core/design/widgets/status_chip.dart';
import 'package:assistant/data/providers.dart';
import 'package:assistant/domain/payments.dart';
import 'package:assistant/features/shared/derived.dart';

/// Group details: counts, price, students with this month's payment status.
class GroupScreen extends ConsumerStatefulWidget {
  /// Creates the screen for group [gid].
  const GroupScreen({super.key, required this.gid});

  /// Group id.
  final String gid;

  @override
  ConsumerState<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends ConsumerState<GroupScreen> {
  bool _onlyUnpaid = false;

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(groupMapProvider)[widget.gid];
    final teacher = ref.watch(teacherOrDefaultProvider);
    final all = (ref.watch(studentsProvider).valueOrNull ?? const [])
        .where((s) => s.groupId == widget.gid && s.active)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final next = ref.watch(nextSessionProvider(widget.gid));
    if (group == null) {
      return Scaffold(
        backgroundColor: MnaraColors.bg,
        body: SafeArea(child: ScreenHeader(title: 'المجموعة', onBack: () => context.pop())),
      );
    }
    final rows = <Widget>[];
    for (final s in all) {
      final pay = ref.watch(currentPaymentProvider(s.id));
      final paid = pay.status == PayStatus.paid;
      if (_onlyUnpaid && paid) continue;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: MnaraCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () => context.push(AppRoutes.studentPath(s.id)),
            child: Row(
              children: [
                CodeBadge(code: s.code),
                const SizedBox(width: 10),
                Expanded(child: Text(s.name, style: MnaraText.bodyStrong(), overflow: TextOverflow.ellipsis)),
                StatusChip(
                  label: paid ? 'مدفوع' : 'لسه',
                  tone: paid ? StatusTone.green : StatusTone.amber,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: MnaraColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(title: group.name, subtitle: '${group.when} · ${group.gradeLabel}', onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  Row(
                    children: [
                      Expanded(child: StatTile(value: '${all.length}', label: 'طالب')),
                      const SizedBox(width: 8),
                      Expanded(child: StatTile(value: '${next.number}', label: 'الحصة الجاية · شهر ${next.monthNumber}')),
                      const SizedBox(width: 8),
                      Expanded(child: StatTile(value: '${monthDue(teacher, group)}', label: 'جنيه في الشهر')),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text('الطلبة', style: MnaraText.h4()),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ChoicePill(label: 'الكل', selected: !_onlyUnpaid, onTap: () => setState(() => _onlyUnpaid = false)),
                      const SizedBox(width: 8),
                      ChoicePill(label: 'لسه ما دفعش', selected: _onlyUnpaid, onTap: () => setState(() => _onlyUnpaid = true)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text(_onlyUnpaid ? 'كله دافع الشهر ده' : 'مفيش طلبة في المجموعة دي لسه', style: MnaraText.body(MnaraColors.muted))),
                    ),
                  ...rows,
                ],
              ),
            ),
            BottomBar(
              child: PrimaryButton(
                label: 'ابدأ الحصة',
                icon: Icons.play_arrow_rounded,
                onPressed: () => context.push(AppRoutes.startPath(widget.gid)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
