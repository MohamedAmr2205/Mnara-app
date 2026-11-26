
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:assistant/app/routes.dart';
import 'package:assistant/core/design/mnara_logo.dart';
import 'package:assistant/core/design/motion.dart';
import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/code_badge.dart';
import 'package:assistant/core/design/widgets/primary_button.dart';
import 'package:assistant/core/design/widgets/screen_parts.dart';
import 'package:assistant/core/design/widgets/status_chip.dart';
import 'package:assistant/core/utils/arabic_text.dart';
import 'package:assistant/core/utils/cairo_time.dart';
import 'package:assistant/data/models/enums.dart';
import 'package:assistant/data/models/models.dart';
import 'package:assistant/data/providers.dart';
import 'package:assistant/domain/session_logic.dart';
import 'package:assistant/features/session/add_student_sheet.dart';
import 'package:assistant/features/session/session_controller.dart';
import 'package:assistant/features/shared/derived.dart';

class _RowInfo {
  const _RowInfo(this.id, this.code, this.name, this.kind);

  final String id;
  final String code;
  final String name;
  final RecordKind kind;
}

Color _attendanceColor(Attendance? a) => switch (a) {
  Attendance.present => MnaraColors.green,
  Attendance.late => MnaraColors.amber,
  Attendance.absent => MnaraColors.red,
  Attendance.excused => MnaraColors.muted,
  null => MnaraColors.line,
};

StatusTone _attendanceTone(Attendance? a) => switch (a) {
  Attendance.present => StatusTone.green,
  Attendance.late => StatusTone.amber,
  Attendance.absent => StatusTone.red,
  Attendance.excused => StatusTone.sel,
  null => StatusTone.neutral,
};

/// The core screen: marking attendance, homework and exam for a session.
class SessionScreen extends ConsumerStatefulWidget {
  /// Creates the screen for session [sessionId]; [edit] reopens a finished one.
  const SessionScreen({super.key, required this.sessionId, this.edit = false});

  /// Session id.
  final String sessionId;

  /// Edit mode (history).
  final bool edit;

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  final _scroll = ScrollController();
  final Map<String, GlobalKey> _keys = {};
  final _examController = TextEditingController();
  bool _examInit = false;

  @override
  void dispose() {
    _scroll.dispose();
    _examController.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  void _scrollTo(String id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keyFor(id).currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.02,
        duration: Motion.of(context, const Duration(milliseconds: 250)),
        curve: Curves.easeOut,
      );
    });
  }

  void _leave() {
    ref.read(sessionControllerProvider(widget.sessionId).notifier).flushAll();
    if (widget.edit) {
      context.go(AppRoutes.history);
    } else {
      context.go(AppRoutes.groups);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionMapProvider)[widget.sessionId];
    final group = session == null ? null : ref.watch(groupMapProvider)[session.groupId];
    if (session == null || group == null) {
      return Scaffold(
        backgroundColor: MnaraColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              ScreenHeader(title: 'الحصة', onBack: _leave),
              const Expanded(child: Center(child: CircularProgressIndicator(color: MnaraColors.accent))),
            ],
          ),
        ),
      );
    }
    final ui0 = ref.watch(sessionControllerProvider(widget.sessionId));
    final ctl = ref.read(sessionControllerProvider(widget.sessionId).notifier);
    if (!_examInit && ui0.hydrated) {
      _examInit = true;
      _examController.text = '${ui0.maxExam}';
    }
    ref.listen<String?>(
      sessionControllerProvider(widget.sessionId).select((s) => s.openId),
      (prev, next) {
        if (next != null) _scrollTo(next);
      },
    );

    final studentMap = ref.watch(studentMapProvider);
    final home = (ref.watch(studentsProvider).valueOrNull ?? const <Student>[])
        .where((s) => s.groupId == group.id && s.active)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final infos = <_RowInfo>[];
    for (final id in ui0.extras) {
      final st = studentMap[id];
      final rec = ui0.records[id];
      if (st != null) {
        infos.add(_RowInfo(id, st.code, st.name, rec?.kind ?? RecordKind.makeup));
      } else if (rec?.newStudent != null) {
        infos.add(_RowInfo(id, rec!.newStudent!.code, rec.newStudent!.name, RecordKind.newStudent));
      }
    }
    for (final s in home) {
      if (!ui0.extras.contains(s.id)) infos.add(_RowInfo(s.id, s.code, s.name, RecordKind.regular));
    }
    final tally = Tally.of(ui0.records.values.where((r) => infos.any((i) => i.id == r.studentId)), infos.length);
    final shown = infos.where((i) => matchesStudent(query: ui0.query, code: i.code, name: i.name)).toList();
    final anyOpen = ui0.openId != null;

    String? nextUnmarkedAfter(String id) {
      final start = infos.indexWhere((i) => i.id == id);
      for (var step = 1; step < infos.length; step++) {
        final i = infos[(start + step) % infos.length];
        if (ui0.records[i.id]?.attendance == null) return i.id;
      }
      return null;
    }

    void openAdd({String query = '', bool pick = false}) {
      showAddStudentSheet(
        context,
        group: group,
        excludeIds: {for (final i in infos) i.id},
        onMakeup: ctl.addMakeup,
        onNew: ctl.addNewStudent,
        initialQuery: query,
        startOnPick: pick,
      );
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, _) => ctl.flushAll(),
      child: Scaffold(
        backgroundColor: MnaraColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              ScreenHeader(
                title: group.name,
                subtitle: '${session.label} · ${formatDm(session.date)}',
                onBack: _leave,
                trailing: const MnaraLogo(height: 38, wordmarkSize: 11),
              ),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    _CountersCard(tally: tally),
                    const SizedBox(height: 12),
                    if (!anyOpen) ...[
                      _Tools(
                        examController: _examController,
                        ui: ui0,
                        onMax: (v) => ctl.setMaxExam(v),
                        onToggleNoExam: ctl.toggleNoExam,
                        onQuery: ctl.setQuery,
                        onAllPresent: () => ctl.markAllPresent([for (final i in infos) i.id]),
                        onUndo: ctl.undoMarkAll,
                      ),
                      const SizedBox(height: 12),
                      _DashedButton(label: 'إضافة طالب (تعويض أو جديد)', onTap: openAdd),
                      const SizedBox(height: 12),
                    ],
                    if (shown.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            Text('مفيش طالب بالاسم أو الكود ده في المجموعة', style: MnaraText.body(MnaraColors.muted), textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            PrimaryButton(
                              label: 'ضيفه كتعويض أو طالب جديد',
                              height: 52,
                              onPressed: () => openAdd(query: ui0.query, pick: true),
                            ),
                          ],
                        ),
                      ),
                    for (final info in shown)
                      Padding(
                        key: _keyFor(info.id),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _StudentRow(
                          info: info,
                          record: ui0.records[info.id],
                          open: ui0.openId == info.id,
                          dimmed: anyOpen && ui0.openId != info.id,
                          maxExam: ui0.maxExam,
                          noExam: ui0.noExam,
                          onTap: () => ctl.open(ui0.openId == info.id ? null : info.id),
                          onAttendance: (a) => ctl.setAttendance(info.id, a),
                          onHomework: (h) => ctl.setHomework(info.id, h),
                          onExam: (v) => ctl.setExam(info.id, v),
                          onNote: (t) => ctl.setNote(info.id, t),
                          onNext: () => ctl.open(nextUnmarkedAfter(info.id)),
                        ),
                      ),
                  ],
                ),
              ),
              BottomBar(
                child: PrimaryButton(
                  label: widget.edit ? 'حفظ التعديلات' : 'إنهاء الحصة',
                  icon: Icons.check,
                  onPressed: () {
                    ctl.flushAll();
                    context.push(AppRoutes.finishPath(widget.sessionId, edit: widget.edit));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountersCard extends StatelessWidget {
  const _CountersCard({required this.tally});

  final Tally tally;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, int n, Color c) => Expanded(
      child: Column(
        children: [
          Text('$n', style: MnaraText.h3(c)),
          Text(label, style: MnaraText.caption()),
        ],
      ),
    );
    return MnaraCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Column(
        children: [
          Row(
            children: [
              cell('حضر', tally.present, MnaraColors.green),
              cell('متأخر', tally.late, MnaraColors.amber),
              cell('غايب', tally.absent, MnaraColors.redText),
              cell('بعذر', tally.excused, MnaraColors.muted),
              cell('لسه', tally.unmarked, MnaraColors.muted),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(MnaraRadii.pill),
            child: LinearProgressIndicator(
              value: tally.progress,
              minHeight: 6,
              color: MnaraColors.accent,
              backgroundColor: MnaraColors.card2,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tools extends StatelessWidget {
  const _Tools({
    required this.examController,
    required this.ui,
    required this.onMax,
    required this.onToggleNoExam,
    required this.onQuery,
    required this.onAllPresent,
    required this.onUndo,
  });

  final TextEditingController examController;
  final SessionUiState ui;
  final ValueChanged<int> onMax;
  final VoidCallback onToggleNoExam;
  final ValueChanged<String> onQuery;
  final VoidCallback onAllPresent;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('درجة الامتحان الكلية', style: MnaraText.small(MnaraColors.muted))),
            Opacity(
              opacity: ui.noExam ? 0.4 : 1,
              child: SizedBox(
                width: 64,
                child: MnaraTextField(
                  controller: examController,
                  height: 44,
                  enabled: !ui.noExam,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  maxLength: 4,
                  onChanged: (v) {
                    final n = int.tryParse(normalizeDigits(v));
                    if (n != null && n > 0) onMax(n);
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              selected: ui.noExam,
              label: 'مفيش امتحان',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggleNoExam,
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: ui.noExam ? MnaraColors.primary : MnaraColors.card,
                    borderRadius: BorderRadius.circular(MnaraRadii.r12),
                    border: Border.all(color: ui.noExam ? MnaraColors.primary : MnaraColors.line),
                  ),
                  child: Text('مفيش امتحان', style: MnaraText.smallStrong()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: MnaraTextField(
                hint: 'كود أو اسم (S12)',
                height: 48,
                prefix: const Icon(Icons.search, color: MnaraColors.muted),
                onChanged: onQuery,
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: 'الكل حضر',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onAllPresent,
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: MnaraColors.greenBg,
                    borderRadius: BorderRadius.circular(MnaraRadii.r14),
                    border: Border.all(color: MnaraColors.green),
                  ),
                  child: Text('الكل حضر', style: MnaraText.smallStrong(MnaraColors.green)),
                ),
              ),
            ),
          ],
        ),
        if (ui.undoIds.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onUndo,
              child: Text('تراجع عن "الكل حضر" (${ui.undoIds.length})', style: MnaraText.smallStrong(MnaraColors.accent)),
            ),
          ),
      ],
    );
  }
}

class _DashedButton extends StatelessWidget {
  const _DashedButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: CustomPaint(
          painter: _DashPainter(),
          child: Container(
            height: 52,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, color: MnaraColors.accent),
                const SizedBox(width: 8),
                Text(label, style: MnaraText.bodyStrong(MnaraColors.accent)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(MnaraRadii.r16));
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = MnaraColors.accent.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.info,
    required this.record,
    required this.open,
    required this.dimmed,
    required this.maxExam,
    required this.noExam,
    required this.onTap,
    required this.onAttendance,
    required this.onHomework,
    required this.onExam,
    required this.onNote,
    required this.onNext,
  });

  final _RowInfo info;
  final SessionRecord? record;
  final bool open;
  final bool dimmed;
  final int maxExam;
  final bool noExam;
  final VoidCallback onTap;
  final ValueChanged<Attendance> onAttendance;
  final ValueChanged<Homework> onHomework;
  final ValueChanged<num?> onExam;
  final ValueChanged<String> onNote;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final a = record?.attendance;
    final attended = a?.attended ?? false;
    final showGrades = attended && info.kind != RecordKind.newStudent && !dimmed;
    final tag = _tag();
    return AnimatedOpacity(
      opacity: dimmed ? 0.55 : 1,
      duration: Motion.of(context, const Duration(milliseconds: 150)),
      child: Container(
        decoration: BoxDecoration(
          color: MnaraColors.card,
          borderRadius: BorderRadius.circular(MnaraRadii.r16),
          border: Border.all(color: open ? MnaraColors.accent : _attendanceColor(a)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(MnaraRadii.r16),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: dimmed ? 46 : 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      CodeBadge(code: info.code),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(info.name, style: MnaraText.bodyStrong(), overflow: TextOverflow.ellipsis),
                            if (tag != null) tag,
                          ],
                        ),
                      ),
                      StatusChip(label: a?.label ?? 'لسه', tone: _attendanceTone(a)),
                      if (showGrades && record?.homework != null) ...[
                        const SizedBox(width: 6),
                        StatusChip(label: record!.homework!.label),
                      ],
                      if (showGrades && record?.examScore != null) ...[
                        const SizedBox(width: 6),
                        StatusChip(label: '${_fmt(record!.examScore!)}/$maxExam', ltr: true),
                      ],
                      const SizedBox(width: 4),
                      Icon(open ? Icons.expand_less : Icons.expand_more, color: MnaraColors.muted),
                    ],
                  ),
                ),
              ),
            ),
            if (open)
              _RowEditor(
                key: ValueKey('editor-${info.id}'),
                info: info,
                record: record,
                maxExam: maxExam,
                noExam: noExam,
                onAttendance: onAttendance,
                onHomework: onHomework,
                onExam: onExam,
                onNote: onNote,
                onNext: onNext,
              ),
          ],
        ),
      ),
    );
  }

  Widget? _tag() {
    final r = record;
    if (r == null) return null;
    if (r.kind == RecordKind.makeup) {
      final text = r.makeupForNumber != null
          ? 'تعويض عن حصة ${r.makeupForNumber} · شهر ${r.makeupForMonth}'
          : 'تعويض';
      return Text(text, style: MnaraText.tiny(MnaraColors.amber));
    }
    final n = r.newStudent;
    if (r.kind == RecordKind.newStudent && n != null) {
      if (n.pay == NewStudentPay.none) {
        return Text('طالب جديد · لسه ما دفعش', style: MnaraText.tiny(MnaraColors.amber));
      }
      final what = n.pay == NewStudentPay.session ? 'حصة' : 'شهر';
      return Text('طالب جديد · دفع ${n.amountEgp} ج ($what)', style: MnaraText.tiny(MnaraColors.mint));
    }
    return null;
  }
}

String _fmt(num n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

class _RowEditor extends StatefulWidget {
  const _RowEditor({
    super.key,
    required this.info,
    required this.record,
    required this.maxExam,
    required this.noExam,
    required this.onAttendance,
    required this.onHomework,
    required this.onExam,
    required this.onNote,
    required this.onNext,
  });

  final _RowInfo info;
  final SessionRecord? record;
  final int maxExam;
  final bool noExam;
  final ValueChanged<Attendance> onAttendance;
  final ValueChanged<Homework> onHomework;
  final ValueChanged<num?> onExam;
  final ValueChanged<String> onNote;
  final VoidCallback onNext;

  @override
  State<_RowEditor> createState() => _RowEditorState();
}

class _RowEditorState extends State<_RowEditor> {
  late final TextEditingController _exam = TextEditingController(
    text: widget.record?.examScore == null ? '' : _fmt(widget.record!.examScore!),
  );
  late final TextEditingController _note = TextEditingController(text: widget.record?.note ?? '');
  bool _examBad = false;

  @override
  void dispose() {
    _exam.dispose();
    _note.dispose();
    super.dispose();
  }

  void _examChanged(String v) {
    final text = normalizeDigits(v).trim();
    if (text.isEmpty) {
      setState(() => _examBad = false);
      widget.onExam(null);
      return;
    }
    final n = double.tryParse(text);
    final bad = n == null || n < 0 || n > widget.maxExam;
    setState(() => _examBad = bad);
    if (!bad) widget.onExam(n == n.roundToDouble() ? n.toInt() : n);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.record?.attendance;
    final attended = a?.attended ?? false;
    final canGrade = attended && widget.info.kind != RecordKind.newStudent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(color: MnaraColors.line, height: 16),
          Text('الحضور', style: MnaraText.small(MnaraColors.muted)),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final opt in Attendance.values) ...[
                Expanded(
                  child: _OptionButton(
                    label: opt.label,
                    selected: a == opt,
                    color: _attendanceColor(opt),
                    onTap: () => widget.onAttendance(opt),
                  ),
                ),
                if (opt != Attendance.values.last) const SizedBox(width: 6),
              ],
            ],
          ),
          if (canGrade) ...[
            const SizedBox(height: 12),
            Text('الواجب', style: MnaraText.small(MnaraColors.muted)),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 2.6,
              children: [
                for (final h in Homework.values)
                  _OptionButton(
                    label: h.label,
                    selected: widget.record?.homework == h,
                    color: MnaraColors.accent,
                    onTap: () => widget.onHomework(h),
                  ),
              ],
            ),
            if (!widget.noExam) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text('درجة الامتحان', style: MnaraText.small(MnaraColors.muted))),
                  SizedBox(
                    width: 76,
                    child: MnaraTextField(
                      controller: _exam,
                      height: 44,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.center,
                      hasError: _examBad,
                      onChanged: _examChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('/ ${widget.maxExam}', textDirection: TextDirection.ltr, style: MnaraText.body(MnaraColors.muted)),
                ],
              ),
              if (_examBad)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('الدرجة لازم تكون من 0 لـ ${widget.maxExam}', style: MnaraText.caption(MnaraColors.redText)),
                ),
            ],
          ],
          const SizedBox(height: 12),
          Text('ملاحظة على الطالب (اختياري)', style: MnaraText.small(MnaraColors.muted)),
          const SizedBox(height: 6),
          MnaraTextField(controller: _note, maxLines: 2, maxLength: 500, onChanged: widget.onNote),
          const SizedBox(height: 12),
          PrimaryButton(label: 'تمام · الطالب اللي بعده', height: 52, onPressed: widget.onNext),
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.22) : MnaraColors.card2,
            borderRadius: BorderRadius.circular(MnaraRadii.r12),
            border: Border.all(color: selected ? color : MnaraColors.line),
          ),
          child: Text(label, style: MnaraText.smallStrong(selected ? MnaraColors.text : MnaraColors.muted)),
        ),
      ),
    );
  }
}
