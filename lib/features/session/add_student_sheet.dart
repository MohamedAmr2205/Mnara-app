import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/bottom_sheet_scaffold.dart';
import 'package:assistant/core/design/widgets/code_badge.dart';
import 'package:assistant/core/design/widgets/primary_button.dart';
import 'package:assistant/core/design/widgets/screen_parts.dart';
import 'package:assistant/core/design/widgets/status_chip.dart';
import 'package:assistant/core/utils/arabic_text.dart';
import 'package:assistant/core/utils/cairo_time.dart';
import 'package:assistant/data/models/enums.dart';
import 'package:assistant/data/models/models.dart';
import 'package:assistant/data/providers.dart';
import 'package:assistant/domain/new_student.dart';
import 'package:assistant/domain/payments.dart';
import 'package:assistant/domain/session_logic.dart';
import 'package:assistant/features/shared/derived.dart';

enum _Step { menu, pick, missed, form }

/// Bottom sheet for adding a makeup student or a brand-new student.
class AddStudentSheet extends ConsumerStatefulWidget {
  /// Creates the sheet for the session of [group].
  const AddStudentSheet({
    super.key,
    required this.group,
    required this.excludeIds,
    required this.onMakeup,
    required this.onNew,
    this.initialQuery = '',
    this.startOnPick = false,
  });

  /// Group the session belongs to.
  final Group group;

  /// Students already in the session.
  final Set<String> excludeIds;

  /// Called with the chosen makeup student and the linked missed session.
  final void Function(Student student, MissedSession? missed) onMakeup;

  /// Called with the staged new student.
  final ValueChanged<NewStudentDraft> onNew;

  /// Pre-filled search text (from the "add them" shortcut).
  final String initialQuery;

  /// Opens directly on the makeup-student picker.
  final bool startOnPick;

  @override
  ConsumerState<AddStudentSheet> createState() => _AddStudentSheetState();
}

class _AddStudentSheetState extends ConsumerState<AddStudentSheet> {
  _Step _step = _Step.menu;
  String _query = '';
  Student? _picked;

  final _search = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _parent = TextEditingController();
  final _amount = TextEditingController();
  late final String _code = generateTempCode(Random.secure());
  late final String _studentId = const Uuid().v4();
  NewStudentPay? _pay;
  PayMethod _method = PayMethod.cash;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _search.text = widget.initialQuery;
    if (widget.startOnPick) _step = _Step.pick;
  }

  @override
  void dispose() {
    _search.dispose();
    _name.dispose();
    _phone.dispose();
    _parent.dispose();
    _amount.dispose();
    super.dispose();
  }

  int get _amountValue => int.tryParse(normalizeDigits(_amount.text).trim()) ?? 0;

  bool get _canAdd => canAddNewStudent(
    name: _name.text,
    phone: _phone.text,
    parentPhone: _parent.text,
    pay: _pay,
    amount: _amountValue,
  );

  String get _title => switch (_step) {
    _Step.menu => 'إضافة طالب',
    _Step.pick => 'طالب تعويض',
    _Step.missed => 'تعويض عن حصة',
    _Step.form => 'طالب جديد',
  };

  void _choosePay(NewStudentPay pay) {
    final teacher = ref.read(teacherOrDefaultProvider);
    setState(() {
      _pay = pay;
      switch (pay) {
        case NewStudentPay.session:
          _amount.text = '${sessionPrice(teacher, widget.group)}';
        case NewStudentPay.month:
          _amount.text = '${monthDue(teacher, widget.group)}';
        case NewStudentPay.none:
          _amount.text = '';
      }
    });
  }

  void _submitNew() {
    if (!_canAdd) return;
    final pay = _pay!;
    widget.onNew(
      NewStudentDraft(
        studentId: _studentId,
        name: _name.text.trim(),
        phone: normalizePhone(_phone.text),
        parentPhone: normalizePhone(_parent.text),
        code: _code,
        pay: pay,
        amountEgp: pay == NewStudentPay.none ? 0 : _amountValue,
        method: _method,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final onBack = _step == _Step.menu
        ? null
        : () => setState(() {
            _step = _step == _Step.missed ? _Step.pick : _Step.menu;
          });
    return BottomSheetScaffold(
      title: _title,
      onBack: onBack,
      child: switch (_step) {
        _Step.menu => _menu(),
        _Step.pick => _pick(),
        _Step.missed => _missed(),
        _Step.form => _form(),
      },
    );
  }

  Widget _menu() {
    Widget option(IconData icon, Color color, String title, String sub, _Step to) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: MnaraCard(
          onTap: () => setState(() => _step = to),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: MnaraColors.card2, borderRadius: BorderRadius.circular(MnaraRadii.r14)),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: MnaraText.h4()),
                    Text(sub, style: MnaraText.small(MnaraColors.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        option(Icons.swap_horiz, MnaraColors.amber, 'طالب تعويض', 'جاي من مجموعة تانية يحضر الحصة دي بس', _Step.pick),
        option(Icons.person_add_alt_1, MnaraColors.green, 'طالب جديد', 'أول مرة يجي للمستر، وهيتسجّل في المجموعة دي', _Step.form),
      ],
    );
  }

  Widget _pick() {
    final students = ref.watch(studentsProvider).valueOrNull ?? const <Student>[];
    final groups = ref.watch(groupMapProvider);
    final list = students
        .where((s) => s.active && s.groupId != widget.group.id && !widget.excludeIds.contains(s.id))
        .where((s) => matchesStudent(query: _query, code: s.code, name: s.name))
        .take(40)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MnaraTextField(
          controller: _search,
          hint: 'كود أو اسم الطالب',
          autofocus: true,
          prefix: const Icon(Icons.search, color: MnaraColors.muted),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 10),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'مفيش طالب بالاسم ده في المجموعات التانية. لو جديد على المستر اختار "طالب جديد".',
              style: MnaraText.small(MnaraColors.muted),
            ),
          ),
        for (final s in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MnaraCard(
              padding: const EdgeInsets.all(12),
              onTap: () => setState(() {
                _picked = s;
                _step = _Step.missed;
              }),
              child: Row(
                children: [
                  CodeBadge(code: s.code),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name, style: MnaraText.bodyStrong()),
                        Text(groups[s.groupId]?.name ?? '', style: MnaraText.caption()),
                      ],
                    ),
                  ),
                  const Icon(Icons.add_circle_outline, color: MnaraColors.accent),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _missed() {
    final student = _picked!;
    final recordsAsync = ref.watch(studentRecordsProvider(student.id));
    final sessions = ref.watch(sessionMapProvider);
    final missed = recordsAsync.valueOrNull == null
        ? const <MissedSession>[]
        : uncoveredAbsences(studentRecords: recordsAsync.valueOrNull!, sessionsById: sessions);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MnaraCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CodeBadge(code: student.code),
              const SizedBox(width: 10),
              Expanded(child: Text(student.name, style: MnaraText.bodyStrong())),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (missed.isEmpty)
          Text('مفيش غياب مسجّل للطالب ده عشان يتربط بيه.', style: MnaraText.small(MnaraColors.muted))
        else ...[
          Text('اختار الحصة اللي غابها وبيعوّضها', style: MnaraText.small(MnaraColors.muted)),
          const SizedBox(height: 8),
          for (final m in missed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MnaraCard(
                padding: const EdgeInsets.all(12),
                onTap: () {
                  widget.onMakeup(student, m);
                  Navigator.of(context).pop();
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('حصة ${m.number} · شهر ${m.month}', style: MnaraText.bodyStrong()),
                          Text(formatDmy(m.date), style: MnaraText.caption()),
                        ],
                      ),
                    ),
                    StatusChip(
                      label: m.attendance == Attendance.excused ? 'غايب بعذر' : 'غايب',
                      tone: m.attendance == Attendance.excused ? StatusTone.sel : StatusTone.red,
                    ),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 8),
        PrimaryButton(
          label: 'ضيفه من غير ربط بحصة',
          height: 52,
          onPressed: () {
            widget.onMakeup(student, null);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  Widget _phoneField(TextEditingController c, String label) {
    final check = checkPhone(c.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: MnaraText.small(MnaraColors.muted)),
        const SizedBox(height: 4),
        MnaraTextField(
          controller: c,
          hint: '01xxxxxxxxx',
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          hasError: c.text.isNotEmpty && !check.valid,
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(
          height: 22,
          child: check.message.isEmpty
              ? null
              : Text(check.message, style: MnaraText.caption(check.valid ? MnaraColors.green : MnaraColors.redText)),
        ),
      ],
    );
  }

  Widget _form() {
    final teacher = ref.watch(teacherOrDefaultProvider);
    final sessionPriceValue = sessionPrice(teacher, widget.group);
    final monthPriceValue = monthDue(teacher, widget.group);
    Widget payOption(NewStudentPay pay, String label, Color color) {
      final selected = _pay == pay;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _choosePay(pay),
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: selected ? MnaraColors.sel : MnaraColors.card,
                borderRadius: BorderRadius.circular(MnaraRadii.r14),
                border: Border.all(color: selected ? MnaraColors.accent : MnaraColors.line),
              ),
              child: Text(label, textAlign: TextAlign.center, style: MnaraText.smallStrong(selected ? MnaraColors.text : color)),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('اسم الطالب', style: MnaraText.small(MnaraColors.muted)),
        const SizedBox(height: 4),
        MnaraTextField(controller: _name, hint: 'الاسم الثلاثي', onChanged: (_) => setState(() {})),
        const SizedBox(height: 10),
        _phoneField(_phone, 'موبايل الطالب'),
        _phoneField(_parent, 'موبايل ولي الأمر'),
        MnaraCard(
          color: MnaraColors.sel,
          borderColor: MnaraColors.line,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('كود الطالب هيتولّد تلقائي: $_code', style: MnaraText.bodyStrong()),
              const SizedBox(height: 4),
              Text(
                'ده كود مؤقت، هيتحوّل لكود دائم أول ما النت يرجع. الرقمين مطلوبين (11 رقم لكل واحد)، عشان بوت الطالب يتأكد من هويته بآخر 4 أرقام.',
                style: MnaraText.small(MnaraColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text('الدفع (لازم تأكد)', style: MnaraText.h4()),
        const SizedBox(height: 8),
        Row(
          children: [
            payOption(NewStudentPay.session, 'دفع حصة\n($sessionPriceValue)', MnaraColors.text),
            const SizedBox(width: 8),
            payOption(NewStudentPay.month, 'دفع شهر\n($monthPriceValue)', MnaraColors.text),
            const SizedBox(width: 8),
            payOption(NewStudentPay.none, 'لسه ما دفعش', MnaraColors.amber),
          ],
        ),
        if (_pay != null && _pay != NewStudentPay.none) ...[
          const SizedBox(height: 12),
          Text('المبلغ اللي دفعه', style: MnaraText.small(MnaraColors.muted)),
          const SizedBox(height: 4),
          MnaraTextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            hasError: _amountValue <= 0,
            suffix: Padding(padding: const EdgeInsets.all(14), child: Text('جنيه', style: MnaraText.small(MnaraColors.muted))),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final m in PayMethod.values) ...[
                Expanded(child: ChoicePill(label: m.label, selected: _method == m, onTap: () => setState(() => _method = m))),
                if (m != PayMethod.values.last) const SizedBox(width: 6),
              ],
            ],
          ),
        ],
        const SizedBox(height: 16),
        PrimaryButton(label: 'إضافة للحصة', onPressed: _canAdd ? _submitNew : null),
      ],
    );
  }
}

/// Opens the add-student sheet.
Future<void> showAddStudentSheet(
  BuildContext context, {
  required Group group,
  required Set<String> excludeIds,
  required void Function(Student, MissedSession?) onMakeup,
  required ValueChanged<NewStudentDraft> onNew,
  String initialQuery = '',
  bool startOnPick = false,
}) {
  return showMnaraSheet<void>(
    context: context,
    builder: (_) => AddStudentSheet(
      group: group,
      excludeIds: excludeIds,
      onMakeup: onMakeup,
      onNew: onNew,
      initialQuery: initialQuery,
      startOnPick: startOnPick,
    ),
  );
}
