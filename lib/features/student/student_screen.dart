import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/common.dart';
import 'package:assistant/core/design/widgets/primary_button.dart';
import 'package:assistant/core/design/widgets/stat_tile.dart';
import 'package:assistant/core/design/widgets/status_chip.dart';
import 'package:assistant/core/util/date_utils.dart';
import 'package:assistant/core/util/text_utils.dart';
import 'package:assistant/data/app_controller.dart';
import 'package:assistant/domain/logic.dart';
import 'package:assistant/domain/models.dart';

/// Student profile with attendance history and monthly payments.
class StudentScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [studentId].
  const StudentScreen({super.key, required this.studentId});

  /// Student id.
  final String studentId;

  @override
  ConsumerState<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends ConsumerState<StudentScreen> {
  int _tab = 0; // 0 attendance, 1 payments

  Future<void> _call(String phone) async {
    var ok = false;
    try {
      ok = await launchUrl(Uri(scheme: 'tel', path: phone));
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) {
      await Clipboard.setData(ClipboardData(text: phone));
      if (mounted) showToast(context, 'مقدرتش أفتح الاتصال. الرقم اتنسخ.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider);
    final st = studentById(s, widget.studentId);
    if (st == null) {
      return const Scaffold(
        body: SafeArea(child: ScreenHeader(title: 'الطالب مش موجود')),
      );
    }
    final g = groupById(s, st.groupId);
    final stats = statsOf(s, st.id);
    final sessions = sessionsOfStudent(s, st.id);
    final currentMonth = currentMonthOf(s, st.groupId);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(title: 'بروفايل الطالب'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
                          child: Text(
                            st.name.isEmpty ? '؟' : st.name.characters.first,
                            style: MnaraText.h2(),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(st.name, style: MnaraText.h3()),
                              const SizedBox(height: 4),
                              Text(
                                '${st.code} · ${g?.name ?? ''}',
                                style: MnaraText.caption(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _PhoneCard(
                          label: 'موبايل الطالب',
                          phone: st.studentPhone,
                          onCall: () => _call(st.studentPhone),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PhoneCard(
                          label: 'موبايل ولي الأمر',
                          phone: st.parentPhone,
                          onCall: () => _call(st.parentPhone),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          label: 'حضور',
                          value: '${stats.attended} من ${stats.total}',
                          valueColor: MnaraColors.green,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatTile(
                          label: 'متوسط الامتحان',
                          value: stats.examPercent == null
                              ? '--'
                              : '${stats.examPercent}%',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatTile(
                          label: 'لم يسلم',
                          value: '${stats.notSubmitted}',
                          valueColor: stats.notSubmitted > 0
                              ? MnaraColors.amber
                              : MnaraColors.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      FilterPill(
                        label: 'الحضور',
                        selected: _tab == 0,
                        onTap: () => setState(() => _tab = 0),
                      ),
                      const SizedBox(width: 8),
                      FilterPill(
                        label: 'الدفع',
                        selected: _tab == 1,
                        onTap: () => setState(() => _tab = 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_tab == 0) ...[
                    if (sessions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'لسه مفيش حصص مسجّلة للطالب ده',
                            style: MnaraText.body(MnaraColors.muted),
                          ),
                        ),
                      ),
                    for (final x in sessions) ...[
                      _SessionCard(session: x, studentId: st.id),
                      const SizedBox(height: 8),
                    ],
                  ] else ...[
                    for (final m in monthsFor(s, st)) ...[
                      _MonthCard(
                        month: m,
                        need: s.teacher.monthPrice,
                        paid: paidFor(s, st.id, m),
                        status: payStatus(
                          s,
                          st.id,
                          m,
                          currentMonth: currentMonth,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ],
              ),
            ),
            StickyCta(
              child: PrimaryButton(
                label: 'تسجيل دفعة',
                icon: Icons.add_rounded,
                onPressed: () => context.push('/students/${st.id}/pay'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneCard extends StatelessWidget {
  const _PhoneCard({
    required this.label,
    required this.phone,
    required this.onCall,
  });

  final String label;
  final String phone;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      radius: MnaraRadii.r16,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: MnaraText.caption()),
                const SizedBox(height: 2),
                Text(
                  phone,
                  textDirection: TextDirection.ltr,
                  style: MnaraText.smallStrong(),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'اتصال: $label',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCall,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: MnaraColors.greenBg,
                  borderRadius: BorderRadius.circular(MnaraRadii.r12),
                ),
                child: const Icon(Icons.call, color: MnaraColors.green, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.studentId});

  final Session session;
  final String studentId;

  @override
  Widget build(BuildContext context) {
    final r = session.recordOf(studentId);
    final a = r.attendance;
    final tone = switch (a) {
      Attendance.present => StatusTone.green,
      Attendance.late => StatusTone.amber,
      Attendance.absent => StatusTone.red,
      Attendance.excused => StatusTone.sel,
      null => StatusTone.neutral,
    };
    final label = a == Attendance.excused ? 'غايب بعذر' : (a?.label ?? '--');
    return AppCard(
      padding: const EdgeInsets.all(12),
      radius: MnaraRadii.r14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'حصة ${session.number} · شهر ${session.month}',
                      style: MnaraText.bodyStrong(),
                    ),
                    Text(
                      formatDateWithDay(parseDateKey(session.date)),
                      style: MnaraText.caption(),
                    ),
                  ],
                ),
              ),
              StatusChip(label: label, tone: tone),
            ],
          ),
          if (a?.attended ?? false) ...[
            const SizedBox(height: 8),
            Text(
              'الواجب: ${r.homework?.label ?? '--'}',
              style: MnaraText.small(MnaraColors.muted),
            ),
            Text(
              session.noExam
                  ? 'الامتحان: مفيش امتحان'
                  : 'الامتحان: ${r.exam == null ? '--' : formatScore(r.exam!)} / ${session.examMax}',
              style: MnaraText.small(MnaraColors.muted),
            ),
          ],
          if (r.tag != null) ...[
            const SizedBox(height: 4),
            Text(
              r.tag!,
              style: MnaraText.tiny(
                r.tagTone == TagTone.mint ? MnaraColors.mint : MnaraColors.amber,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.month,
    required this.need,
    required this.paid,
    required this.status,
  });

  final int month;
  final int need;
  final int paid;
  final PayStatus status;

  @override
  Widget build(BuildContext context) {
    final remaining = (need - paid) < 0 ? 0 : need - paid;
    final (label, tone) = switch (status) {
      PayStatus.paid => ('مدفوع', StatusTone.green),
      PayStatus.partial => ('جزئي', StatusTone.amber),
      PayStatus.upcoming => ('قادم', StatusTone.sel),
      PayStatus.none => ('لسه', StatusTone.amber),
    };
    Widget cell(String l, int v, [Color c = MnaraColors.text]) => Expanded(
      child: Column(
        children: [
          Text('$v ج', style: MnaraText.bodyStrong(c)),
          Text(l, style: MnaraText.caption()),
        ],
      ),
    );
    return AppCard(
      padding: const EdgeInsets.all(12),
      radius: MnaraRadii.r14,
      borderColor: status == PayStatus.partial ? MnaraColors.amber : null,
      child: Column(
        children: [
          Row(
            children: [
              Text('شهر $month', style: MnaraText.h4()),
              const Spacer(),
              StatusChip(label: label, tone: tone),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              cell('المطلوب', need),
              cell('اتدفع', paid, MnaraColors.green),
              cell(
                'المتبقي',
                remaining,
                remaining > 0 ? MnaraColors.amber : MnaraColors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
