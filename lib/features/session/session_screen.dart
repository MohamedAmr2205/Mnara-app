import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:assistant/core/design/motion.dart';
import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/bottom_sheet_scaffold.dart';
import 'package:assistant/core/design/widgets/code_badge.dart';
import 'package:assistant/core/design/widgets/common.dart';
import 'package:assistant/core/design/widgets/primary_button.dart';
import 'package:assistant/core/design/widgets/status_chip.dart';
import 'package:assistant/core/util/date_utils.dart';
import 'package:assistant/core/util/text_utils.dart';
import 'package:assistant/data/app_controller.dart';
import 'package:assistant/domain/logic.dart';
import 'package:assistant/domain/models.dart';
import 'package:assistant/features/session/add_student_sheet.dart';

StatusTone _attendanceTone(Attendance? a) => switch (a) {
  Attendance.present => StatusTone.green,
  Attendance.late => StatusTone.amber,
  Attendance.absent => StatusTone.red,
  Attendance.excused => StatusTone.sel,
  null => StatusTone.neutral,
};

Color _attendanceBorder(Attendance? a) => switch (a) {
  Attendance.present => MnaraColors.green,
  Attendance.late => MnaraColors.amber,
  Attendance.absent => MnaraColors.red,
  Attendance.excused => MnaraColors.primary,
  null => MnaraColors.line,
};

StatusTone _homeworkTone(Homework h) => switch (h) {
  Homework.excellent || Homework.veryGood => StatusTone.green,
  Homework.good || Homework.acceptable => StatusTone.sel,
  Homework.weak => StatusTone.amber,
  Homework.notSubmitted => StatusTone.red,
};

/// The core screen: mark attendance, homework and exam for each student.
class SessionScreen extends ConsumerStatefulWidget {
  /// Creates the screen for session [xid].
  const SessionScreen({super.key, required this.xid});

  /// Session id.
  final String xid;

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  String? _openId;
  String _query = '';
  final Map<String, GlobalKey<State<StatefulWidget>>> _keys = {};
  final TextEditingController _maxController = TextEditingController();
  bool _maxInit = false;

  @override
  void dispose() {
    _maxController.dispose();
    super.dispose();
  }

  void _open(String? id) {
    setState(() => _openId = id);
    if (id == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[id]?.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.05,
          duration: Motion.of(context, const Duration(milliseconds: 250)),
        );
      }
    });
  }

  /// Next not-yet-marked student after [currentId] (wrapping around).
  String? _nextUnmarked(Session x, String currentId) {
    final i = x.order.indexOf(currentId);
    final n = x.order.length;
    for (var step = 1; step < n; step++) {
      final id = x.order[(i + step) % n];
      if (x.recordOf(id).attendance == null) return id;
    }
    return null;
  }

  Future<void> _showAdd(Session x) async {
    final added = await showMnaraSheet<String>(
      context: context,
      builder: (_) => AddStudentSheet(xid: x.id),
    );
    if (added != null && mounted) {
      setState(() => _query = '');
      _open(added);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider);
    final x = sessionById(s, widget.xid);
    if (x == null) {
      return const Scaffold(
        body: SafeArea(child: ScreenHeader(title: 'الحصة مش موجودة')),
      );
    }
    if (!_maxInit) {
      _maxController.text = '${x.examMax}';
      _maxInit = true;
    }
    final g = groupById(s, x.groupId);
    final c = countsOf(x);
    final controller = ref.read(appProvider.notifier);
    final date = parseDateKey(x.date);
    final q = normalizeSearch(_query);
    final ids = x.order.where((id) {
      if (q.isEmpty) return true;
      final st = studentById(s, id);
      if (st == null) return false;
      return st.code.toLowerCase().contains(q) ||
          normalizeSearch(st.name).contains(q);
    }).toList();
    final isOpenRow = _openId != null && x.order.contains(_openId);

    final rows = <Widget>[];
    if (!isOpenRow) {
      rows.add(_Tools(
        session: x,
        maxController: _maxController,
        onQuery: (v) => setState(() => _query = v),
        onAll: () {
          final changed = controller.markAllPresent(x.id);
          showToast(
            context,
            changed.isEmpty
                ? 'كله معلَّم بالفعل'
                : 'اتعلّم ${changed.length} طالب حاضر',
            actionLabel: changed.isEmpty ? null : 'تراجع',
            onAction: () => controller.undoMarkAll(x.id, changed),
          );
        },
      ));
      rows.add(const SizedBox(height: 10));
      rows.add(_AddStudentButton(onTap: () => _showAdd(x)));
      rows.add(const SizedBox(height: 10));
      if (ids.isEmpty && q.isNotEmpty) {
        rows.add(
          AppCard(
            child: Column(
              children: [
                Text(
                  'مفيش طالب بالاسم أو الكود ده في المجموعة',
                  textAlign: TextAlign.center,
                  style: MnaraText.body(MnaraColors.muted),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'ضيفه كتعويض أو طالب جديد',
                  height: 48,
                  onPressed: () => _showAdd(x),
                ),
              ],
            ),
          ),
        );
      }
    }

    for (final id in ids) {
      final st = studentById(s, id);
      if (st == null) continue;
      final key = _keys.putIfAbsent(id, () => GlobalKey());
      final open = id == _openId;
      rows.add(
        KeyedSubtree(
          key: key,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: open
                ? _OpenRow(
                    key: ValueKey('open-$id'),
                    session: x,
                    student: st,
                    onClose: () => _open(null),
                    onNext: () => _open(_nextUnmarked(x, id)),
                  )
                : _ClosedRow(
                    session: x,
                    student: st,
                    dimmed: isOpenRow,
                    onTap: () => _open(id),
                  ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: g?.name ?? '',
              subtitle:
                  'الحصة ${x.number} · شهر ${x.month} · ${formatDateShort(date)}',
              trailing: const HeaderLogo(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: _CountsCard(counts: c),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: rows,
              ),
            ),
            StickyCta(
              child: PrimaryButton(
                label: x.status == SessionStatus.closed
                    ? 'حفظ التعديلات'
                    : 'إنهاء الحصة',
                icon: Icons.check_rounded,
                onPressed: () => context.push('/session/${x.id}/finish'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountsCard extends StatelessWidget {
  const _CountsCard({required this.counts});

  final SessionCounts counts;

  @override
  Widget build(BuildContext context) {
    Widget item(String label, int v, Color color) => Expanded(
      child: Column(
        children: [
          Text('$v', style: MnaraText.h3(color)),
          Text(label, style: MnaraText.caption()),
        ],
      ),
    );
    final progress = counts.total == 0 ? 0.0 : counts.marked / counts.total;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              item('حضر', counts.present, MnaraColors.green),
              item('متأخر', counts.late, MnaraColors.amber),
              item('غايب', counts.absent, MnaraColors.redText),
              item('بعذر', counts.excused, MnaraColors.muted),
              item('لسه', counts.unmarked, MnaraColors.muted),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(MnaraRadii.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: MnaraColors.card2,
              valueColor: const AlwaysStoppedAnimation(MnaraColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tools extends ConsumerWidget {
  const _Tools({
    required this.session,
    required this.maxController,
    required this.onQuery,
    required this.onAll,
  });

  final Session session;
  final TextEditingController maxController;
  final ValueChanged<String> onQuery;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(appProvider.notifier);
    final noExam = session.noExam;
    return Column(
      children: [
        Row(
          children: [
            Text('درجة الامتحان الكلية', style: MnaraText.bodyStrong()),
            const SizedBox(width: 10),
            Opacity(
              opacity: noExam ? 0.4 : 1,
              child: SizedBox(
                width: 64,
                height: 44,
                child: TextField(
                  controller: maxController,
                  enabled: !noExam,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: MnaraText.bodyStrong(),
                  decoration: mnaraInput(),
                  onChanged: (v) {
                    final n = parsePositiveInt(v);
                    if (n != null) controller.setExamMax(session.id, n);
                  },
                ),
              ),
            ),
            const Spacer(),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => controller.setNoExam(session.id, !noExam),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: noExam ? MnaraColors.primary : MnaraColors.card,
                    borderRadius: BorderRadius.circular(MnaraRadii.pill),
                    border: Border.all(
                      color: noExam ? MnaraColors.primary : MnaraColors.line,
                    ),
                  ),
                  child: Text('مفيش امتحان', style: MnaraText.bodyStrong()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: onQuery,
                style: MnaraText.body(),
                decoration: mnaraInput(
                  hint: 'كود أو اسم (S12)',
                  prefix: const Icon(Icons.search, color: MnaraColors.muted),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAll,
              child: Container(
                height: 48,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: MnaraColors.green,
                  borderRadius: BorderRadius.circular(MnaraRadii.r14),
                ),
                child: Text(
                  'الكل حضر',
                  style: MnaraText.bodyStrong(const Color(0xFF04261C)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AddStudentButton extends StatelessWidget {
  const _AddStudentButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'إضافة طالب (تعويض أو جديد)',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MnaraRadii.r14),
            border: Border.all(color: MnaraColors.accent.withAlpha(140)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add, color: MnaraColors.accent, size: 22),
              const SizedBox(width: 8),
              Text(
                'إضافة طالب (تعويض أو جديد)',
                style: MnaraText.bodyStrong(MnaraColors.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClosedRow extends StatelessWidget {
  const _ClosedRow({
    required this.session,
    required this.student,
    required this.dimmed,
    required this.onTap,
  });

  final Session session;
  final Student student;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = session.recordOf(student.id);
    final att = r.attendance;
    final showExtras = att != null && att.attended && !r.isNew && !dimmed;
    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: Semantics(
        button: true,
        label: '${student.name} ${att?.label ?? 'لسه'}',
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: dimmed ? 46 : 56),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: MnaraColors.card,
              borderRadius: BorderRadius.circular(MnaraRadii.r14),
              border: Border.all(color: _attendanceBorder(att)),
            ),
            child: Row(
              children: [
                CodeBadge(code: student.code),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.name, style: MnaraText.bodyStrong()),
                      if (r.tag != null)
                        Text(
                          r.tag!,
                          style: MnaraText.tiny(
                            r.tagTone == TagTone.mint
                                ? MnaraColors.mint
                                : MnaraColors.amber,
                          ),
                        ),
                    ],
                  ),
                ),
                if (showExtras && r.homework != null) ...[
                  StatusChip(
                    label: r.homework!.label,
                    tone: _homeworkTone(r.homework!),
                  ),
                  const SizedBox(width: 6),
                ],
                if (showExtras && r.exam != null && !session.noExam) ...[
                  StatusChip(
                    label: '${formatScore(r.exam!)}/${session.examMax}',
                    ltr: true,
                  ),
                  const SizedBox(width: 6),
                ],
                StatusChip(
                  label: att?.label ?? 'لسه',
                  tone: _attendanceTone(att),
                ),
                const Icon(Icons.expand_more, color: MnaraColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OpenRow extends ConsumerWidget {
  const _OpenRow({
    super.key,
    required this.session,
    required this.student,
    required this.onClose,
    required this.onNext,
  });

  final Session session;
  final Student student;
  final VoidCallback onClose;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appProvider);
    final x = sessionById(s, session.id) ?? session;
    final r = x.recordOf(student.id);
    final controller = ref.read(appProvider.notifier);
    final attended = r.attendance?.attended ?? false;
    final showWork = attended && !r.isNew;

    Widget choice({
      required String label,
      required bool selected,
      required VoidCallback onTap,
      Color? selectedColor,
    }) {
      return Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? (selectedColor ?? MnaraColors.primary)
                  : MnaraColors.card2,
              borderRadius: BorderRadius.circular(MnaraRadii.r12),
              border: Border.all(
                color: selected
                    ? (selectedColor ?? MnaraColors.primary)
                    : MnaraColors.line,
              ),
            ),
            child: Text(label, style: MnaraText.bodyStrong()),
          ),
        ),
      );
    }

    Widget gap() => const SizedBox(width: 8);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MnaraColors.card,
        borderRadius: BorderRadius.circular(MnaraRadii.r18),
        border: Border.all(color: MnaraColors.accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: Row(
              children: [
                CodeBadge(code: student.code),
                const SizedBox(width: 10),
                Expanded(child: Text(student.name, style: MnaraText.h4())),
                const Icon(Icons.expand_less, color: MnaraColors.muted),
              ],
            ),
          ),
          if (r.tag != null) ...[
            const SizedBox(height: 6),
            Text(
              r.tag!,
              style: MnaraText.captionStrong(
                r.tagTone == TagTone.mint ? MnaraColors.mint : MnaraColors.amber,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text('الحضور', style: MnaraText.caption()),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final a in Attendance.values) ...[
                Expanded(
                  child: choice(
                    label: a.label,
                    selected: r.attendance == a,
                    selectedColor: switch (a) {
                      Attendance.present => MnaraColors.green,
                      Attendance.late => MnaraColors.amber,
                      Attendance.absent => MnaraColors.red,
                      Attendance.excused => MnaraColors.primary,
                    },
                    onTap: () =>
                        controller.setAttendance(session.id, student.id, a),
                  ),
                ),
                if (a != Attendance.values.last) gap(),
              ],
            ],
          ),
          if (showWork) ...[
            const SizedBox(height: 14),
            Text('الواجب', style: MnaraText.caption()),
            const SizedBox(height: 6),
            for (var row = 0; row < 2; row++) ...[
              if (row > 0) const SizedBox(height: 8),
              Row(
                children: [
                  for (var col = 0; col < 3; col++) ...[
                    if (col > 0) gap(),
                    Expanded(
                      child: choice(
                        label: Homework.values[row * 3 + col].label,
                        selected: r.homework == Homework.values[row * 3 + col],
                        onTap: () => controller.setHomework(
                          session.id,
                          student.id,
                          Homework.values[row * 3 + col],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (!x.noExam) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Text('درجة الامتحان', style: MnaraText.bodyStrong()),
                  const SizedBox(width: 12),
                  _ExamField(
                    value: r.exam,
                    max: x.examMax,
                    onChanged: (v) =>
                        controller.setExam(session.id, student.id, v),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '/ ${x.examMax}',
                    textDirection: TextDirection.ltr,
                    style: MnaraText.body(MnaraColors.muted),
                  ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 14),
          TextFormField(
            initialValue: r.note,
            onChanged: (v) =>
                controller.setStudentNote(session.id, student.id, v),
            style: MnaraText.body(),
            decoration: mnaraInput(hint: 'ملاحظة على الطالب (اختياري)'),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'تمام · الطالب اللي بعده',
            height: 52,
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _ExamField extends StatefulWidget {
  const _ExamField({
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final double? value;
  final int max;
  final ValueChanged<double?> onChanged;

  @override
  State<_ExamField> createState() => _ExamFieldState();
}

class _ExamFieldState extends State<_ExamField> {
  late final TextEditingController _c = TextEditingController(
    text: widget.value == null ? '' : formatScore(widget.value!),
  );
  bool _over = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _change(String text) {
    if (text.trim().isEmpty) {
      setState(() => _over = false);
      widget.onChanged(null);
      return;
    }
    final v = parseScore(text);
    if (v == null || v > widget.max) {
      setState(() => _over = true);
      return;
    }
    setState(() => _over = false);
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 44,
      child: TextField(
        controller: _c,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: MnaraText.bodyStrong(),
        decoration: mnaraInput(error: _over),
        onChanged: _change,
      ),
    );
  }
}
