import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:assistant/app/routes.dart';
import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/code_badge.dart';
import 'package:assistant/core/design/widgets/primary_button.dart';
import 'package:assistant/core/design/widgets/screen_parts.dart';
import 'package:assistant/core/design/widgets/stat_tile.dart';
import 'package:assistant/core/design/widgets/status_chip.dart';
import 'package:assistant/core/utils/cairo_time.dart';
import 'package:assistant/data/models/enums.dart';
import 'package:assistant/data/models/models.dart';
import 'package:assistant/data/providers.dart';
import 'package:assistant/domain/payments.dart';
import 'package:assistant/features/shared/derived.dart';

/// Student profile: contacts, stats, attendance and payment history.
class StudentScreen extends ConsumerStatefulWidget {
  /// Creates the screen for student [sid].
  const StudentScreen({super.key, required this.sid});

  /// Student id.
  final String sid;

  @override
  ConsumerState<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends ConsumerState<StudentScreen> {
  int _tab = 0;

  Future<void> _call(String phone) async {
    final ok = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مقدرناش نفتح الاتصال على الموبايل ده')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = ref.watch(studentMapProvider)[widget.sid];
    if (student == null) {
      return Scaffold(
        backgroundColor: MnaraColors.bg,
        body: SafeArea(child: ScreenHeader(title: 'بروفايل الطالب', onBack: () => context.pop())),
      );
    }
    final group = ref.watch(groupMapProvider)[student.groupId];
    final sessions = ref.watch(sessionMapProvider);
    final records = (ref.watch(studentRecordsProvider(student.id)).valueOrNull ?? const <SessionRecord>[])
        .where((r) => r.attendance != null && sessions[r.sessionId] != null)
        .toList()
      ..sort((a, b) => sessions[b.sessionId]!.date.compareTo(sessions[a.sessionId]!.date));
    final attended = records.where((r) => r.attendance!.attended).length;
    var pctSum = 0.0, pctCount = 0, notSubmitted = 0;
    for (final r in records) {
      final max = sessions[r.sessionId]!.maxExam;
      if (r.examScore != null && max != null && max > 0) {
        pctSum += r.examScore!.toDouble() / max;
        pctCount++;
      }
      if (r.homework == Homework.notSubmitted) notSubmitted++;
    }
    final avg = pctCount == 0 ? '--' : '${(pctSum / pctCount * 100).round()}%';
    final currentMonth = ref.watch(groupMonthProvider(student.groupId));
    final teacher = ref.watch(teacherOrDefaultProvider);
    final payments = (ref.watch(paymentsProvider).valueOrNull ?? const <Payment>[])
        .where((p) => p.studentId == student.id)
        .toList();

    return Scaffold(
      backgroundColor: MnaraColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(title: 'بروفايل الطالب', onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  MnaraCard(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: MnaraColors.sel,
                          child: Text(student.name.isEmpty ? '؟' : student.name.characters.first, style: MnaraText.h3()),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(student.name, style: MnaraText.h3()),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  CodeBadge(code: student.code),
                                  const SizedBox(width: 8),
                                  Flexible(child: Text(group?.name ?? '', style: MnaraText.small(MnaraColors.muted), overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PhoneCard(label: 'موبايل الطالب', phone: student.phone, onCall: () => _call(student.phone)),
                  const SizedBox(height: 8),
                  _PhoneCard(label: 'موبايل ولي الأمر', phone: student.parentPhone, onCall: () => _call(student.parentPhone)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: StatTile(value: '$attended من ${records.length}', label: 'حضور', valueColor: MnaraColors.green)),
                      const SizedBox(width: 8),
                      Expanded(child: StatTile(value: avg, label: 'متوسط الامتحان')),
                      const SizedBox(width: 8),
                      Expanded(child: StatTile(value: '$notSubmitted', label: 'لم يسلم', valueColor: MnaraColors.amber)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ChoicePill(label: 'الحضور', selected: _tab == 0, onTap: () => setState(() => _tab = 0)),
                      const SizedBox(width: 8),
                      ChoicePill(label: 'الدفع', selected: _tab == 1, onTap: () => setState(() => _tab = 1)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_tab == 0) ...[
                    if (records.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(child: Text('لسه مفيش حصص مسجّلة للطالب ده', style: MnaraText.body(MnaraColors.muted))),
                      ),
                    for (final r in records)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _AttendanceCard(record: r, session: sessions[r.sessionId]!),
                      ),
                  ] else
                    for (final m in monthsToShow(currentMonth))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _MonthCard(
                          pay: monthPayment(
                            month: m,
                            due: monthDue(teacher, group),
                            payments: payments,
                            currentMonth: currentMonth,
                          ),
                        ),
                      ),
                ],
              ),
            ),
            BottomBar(
              child: PrimaryButton(
                label: 'تسجيل دفعة',
                icon: Icons.add,
                onPressed: () => context.push(AppRoutes.paymentPath(student.id)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneCard extends StatelessWidget {
  const _PhoneCard({required this.label, required this.phone, required this.onCall});

  final String label;
  final String phone;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return MnaraCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: MnaraText.caption()),
                Text(phone, textDirection: TextDirection.ltr, style: MnaraText.bodyStrong()),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'اتصل: $label',
            excludeSemantics: true,
            child: Material(
              color: MnaraColors.greenBg,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: phone.isEmpty ? null : onCall,
                child: const SizedBox(width: 44, height: 44, child: Icon(Icons.call, color: MnaraColors.green)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.record, required this.session});

  final SessionRecord record;
  final Session session;

  @override
  Widget build(BuildContext context) {
    final a = record.attendance!;
    final tone = switch (a) {
      Attendance.present => StatusTone.green,
      Attendance.late => StatusTone.amber,
      Attendance.absent => StatusTone.red,
      Attendance.excused => StatusTone.sel,
    };
    final label = a == Attendance.excused ? 'غايب بعذر' : a.label;
    final exam = record.examScore == null ? '--' : '${record.examScore} / ${session.maxExam ?? '--'}';
    return MnaraCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${session.label}  ·  ${formatDmy(session.date)}', style: MnaraText.bodyStrong()),
              ),
              StatusChip(label: label, tone: tone),
            ],
          ),
          if (a.attended) ...[
            const SizedBox(height: 6),
            Text(
              'الواجب: ${record.homework?.label ?? '--'}   الامتحان: $exam',
              style: MnaraText.small(MnaraColors.muted),
            ),
          ],
          if (record.kind == RecordKind.makeup)
            Text('حصة تعويض', style: MnaraText.caption(MnaraColors.amber)),
        ],
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.pay});

  final MonthPayment pay;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (pay.status) {
      PayStatus.paid => ('مدفوع', StatusTone.green),
      PayStatus.partial => ('جزئي', StatusTone.amber),
      PayStatus.upcoming => ('قادم', StatusTone.sel),
      PayStatus.unpaid => ('لسه', StatusTone.amber),
    };
    Widget cell(String l, int v, [Color c = MnaraColors.text]) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l, style: MnaraText.caption()),
          Text('$v ج', style: MnaraText.bodyStrong(c)),
        ],
      ),
    );
    return MnaraCard(
      borderColor: pay.status == PayStatus.partial ? MnaraColors.amber : MnaraColors.line,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text('شهر ${pay.month}', style: MnaraText.h4())),
              StatusChip(label: label, tone: tone),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              cell('المطلوب', pay.due),
              cell('اتدفع', pay.paid, MnaraColors.green),
              cell('المتبقي', pay.remaining, pay.remaining > 0 ? MnaraColors.amber : MnaraColors.green),
            ],
          ),
        ],
      ),
    );
  }
}
