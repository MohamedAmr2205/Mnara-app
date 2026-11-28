import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/code_badge.dart';
import 'package:assistant/core/design/widgets/common.dart';
import 'package:assistant/core/design/widgets/primary_button.dart';
import 'package:assistant/core/design/widgets/stat_tile.dart';
import 'package:assistant/core/design/widgets/status_chip.dart';
import 'package:assistant/data/app_controller.dart';
import 'package:assistant/domain/logic.dart';

/// Group details: stats, student list with payment state, start button.
class GroupScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [groupId].
  const GroupScreen({super.key, required this.groupId});

  /// Group to show.
  final String groupId;

  @override
  ConsumerState<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends ConsumerState<GroupScreen> {
  bool _onlyUnpaid = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider);
    final g = groupById(s, widget.groupId);
    if (g == null) {
      return const Scaffold(
        body: SafeArea(child: ScreenHeader(title: 'المجموعة مش موجودة')),
      );
    }
    final slot = nextSessionSlot(s, g.id);
    final all = studentsOfGroup(s, g.id)
      ..sort((a, b) => a.code.compareTo(b.code));
    final rows = _onlyUnpaid
        ? all
              .where((st) => currentPayStatus(s, st) != PayStatus.paid)
              .toList()
        : all;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: g.name,
              subtitle: '${groupWhen(g)} · ${gradeLabel(g.grade)}',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(value: '${all.length}', label: 'طالب'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatTile(
                          value: '${slot.number}',
                          label: 'الحصة الجاية · شهر ${slot.month}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatTile(
                          value: '${s.teacher.monthPrice}',
                          label: 'جنيه في الشهر',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text('الطلبة', style: MnaraText.h4()),
                      const Spacer(),
                      FilterPill(
                        label: 'الكل',
                        selected: !_onlyUnpaid,
                        onTap: () => setState(() => _onlyUnpaid = false),
                      ),
                      const SizedBox(width: 8),
                      FilterPill(
                        label: 'لسه ما دفعش',
                        selected: _onlyUnpaid,
                        onTap: () => setState(() => _onlyUnpaid = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'كله دافع الشهر ده',
                          style: MnaraText.body(MnaraColors.muted),
                        ),
                      ),
                    ),
                  for (final st in rows) ...[
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      radius: MnaraRadii.r14,
                      onTap: () => context.push('/students/${st.id}'),
                      child: Row(
                        children: [
                          CodeBadge(code: st.code),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(st.name, style: MnaraText.bodyStrong()),
                          ),
                          if (currentPayStatus(s, st) == PayStatus.paid)
                            const StatusChip(
                              label: 'مدفوع',
                              tone: StatusTone.green,
                            )
                          else
                            const StatusChip(
                              label: 'لسه',
                              tone: StatusTone.amber,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            StickyCta(
              child: PrimaryButton(
                label: 'ابدأ الحصة',
                icon: Icons.play_arrow_rounded,
                onPressed: () => context.push('/groups/${g.id}/start'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
