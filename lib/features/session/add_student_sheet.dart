import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

enum _Step { menu, pickStudent, pickSession, newStudent }

/// Bottom sheet to add a make-up student or a brand-new student.
///
/// Pops with the added student's id.
class AddStudentSheet extends ConsumerStatefulWidget {
  /// Creates the sheet for session [xid].
  const AddStudentSheet({super.key, required this.xid});

  /// Session the student is added to.
  final String xid;

  @override
  ConsumerState<AddStudentSheet> createState() => _AddStudentSheetState();
}

class _AddStudentSheetState extends ConsumerState<AddStudentSheet> {
  _Step _step = _Step.menu;
  String _query = '';
  Student? _picked;

  String get _title => switch (_step) {
    _Step.menu => 'إضافة طالب',
    _Step.pickStudent => 'طالب تعويض',
    _Step.pickSession => 'تعويض عن حصة',
    _Step.newStudent => 'طالب جديد',
  };

  VoidCallback? get _onBack => switch (_step) {
    _Step.menu => null,
    _Step.pickStudent => () => setState(() => _step = _Step.menu),
    _Step.pickSession => () => setState(() => _step = _Step.pickStudent),
    _Step.newStudent => () => setState(() => _step = _Step.menu),
  };

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider);
    final x = sessionById(s, widget.xid);
    if (x == null) return const SizedBox.shrink();

    final Widget body;
    switch (_step) {
      case _Step.menu:
        body = Column(
          children: [
            _MenuCard(
              icon: Icons.swap_horiz_rounded,
              color: MnaraColors.amber,
              title: 'طالب تعويض',
              subtitle: 'جاي من مجموعة تانية يحضر الحصة دي بس',
              onTap: () => setState(() {
                _query = '';
                _step = _Step.pickStudent;
              }),
            ),
            const SizedBox(height: 10),
            _MenuCard(
              icon: Icons.person_add_alt_1_rounded,
              color: MnaraColors.green,
              title: 'طالب جديد',
              subtitle: 'أول مرة يجي للمستر، وهيتسجّل في المجموعة دي',
              onTap: () => setState(() => _step = _Step.newStudent),
            ),
          ],
        );
      case _Step.pickStudent:
        body = _pickStudent(s, x);
      case _Step.pickSession:
        body = _pickSession(s, x);
      case _Step.newStudent:
        body = _NewStudentForm(
          xid: x.id,
          onDone: (id) => Navigator.of(context).pop(id),
        );
    }

    return BottomSheetScaffold(title: _title, onBack: _onBack, child: body);
  }

  Widget _pickStudent(AppState s, Session x) {
    final q = normalizeSearch(_query);
    final candidates = s.students.where((st) {
      if (st.groupId == x.groupId || x.order.contains(st.id)) return false;
      if (q.isEmpty) return true;
      return st.code.toLowerCase().contains(q) ||
          normalizeSearch(st.name).contains(q);
    }).take(40).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          autofocus: true,
          onChanged: (v) => setState(() => _query = v),
          style: MnaraText.body(),
          decoration: mnaraInput(
            hint: 'كود أو اسم الطالب',
            prefix: const Icon(Icons.search, color: MnaraColors.muted),
          ),
        ),
        const SizedBox(height: 12),
        if (candidates.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'مفيش طالب بالاسم ده في المجموعات التانية. لو جديد على المستر اختار "طالب جديد".',
              textAlign: TextAlign.center,
              style: MnaraText.body(MnaraColors.muted),
            ),
          ),
        for (final st in candidates) ...[
          AppCard(
            padding: const EdgeInsets.all(12),
            radius: MnaraRadii.r14,
            onTap: () => setState(() {
              _picked = st;
              _step = _Step.pickSession;
            }),
            child: Row(
              children: [
                CodeBadge(code: st.code),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(st.name, style: MnaraText.bodyStrong()),
                      Text(
                        groupById(s, st.groupId)?.name ?? '',
                        style: MnaraText.caption(),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.add_circle_outline, color: MnaraColors.accent),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _pickSession(AppState s, Session x) {
    final st = _picked;
    if (st == null) return const SizedBox.shrink();
    final missed = missedSessions(s, st.id);
    final controller = ref.read(appProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(12),
          radius: MnaraRadii.r14,
          child: Row(
            children: [
              CodeBadge(code: st.code),
              const SizedBox(width: 10),
              Expanded(child: Text(st.name, style: MnaraText.bodyStrong())),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (missed.isNotEmpty) ...[
          Text(
            'اختار الحصة اللي غابها وبيعوّضها',
            style: MnaraText.body(MnaraColors.muted),
          ),
          const SizedBox(height: 10),
          for (final m in missed) ...[
            AppCard(
              padding: const EdgeInsets.all(12),
              radius: MnaraRadii.r14,
              onTap: () {
                controller.addCompensation(
                  x.id,
                  st.id,
                  forSessionId: m.session.id,
                );
                Navigator.of(context).pop(st.id);
              },
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'حصة ${m.session.number} · شهر ${m.session.month}',
                          style: MnaraText.bodyStrong(),
                        ),
                        Text(
                          formatDateWithDay(parseDateKey(m.session.date)),
                          style: MnaraText.caption(),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(
                    label: m.attendance == Attendance.absent
                        ? 'غايب'
                        : 'غايب بعذر',
                    tone: m.attendance == Attendance.absent
                        ? StatusTone.red
                        : StatusTone.sel,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'مفيش غياب مسجّل للطالب ده عشان يتربط بيه.',
              textAlign: TextAlign.center,
              style: MnaraText.body(MnaraColors.muted),
            ),
          ),
        ],
        const SizedBox(height: 8),
        PrimaryButton(
          label: 'ضيفه من غير ربط بحصة',
          height: 52,
          onPressed: () {
            controller.addCompensation(x.id, st.id);
            Navigator.of(context).pop(st.id);
          },
        ),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withAlpha(40),
              borderRadius: BorderRadius.circular(MnaraRadii.r14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: MnaraText.h4()),
                const SizedBox(height: 2),
                Text(subtitle, style: MnaraText.caption()),
              ],
            ),
          ),
          const Icon(Icons.chevron_left, color: MnaraColors.muted),
        ],
      ),
    );
  }
}

class _NewStudentForm extends ConsumerStatefulWidget {
  const _NewStudentForm({required this.xid, required this.onDone});

  final String xid;
  final ValueChanged<String> onDone;

  @override
  ConsumerState<_NewStudentForm> createState() => _NewStudentFormState();
}

class _NewStudentFormState extends ConsumerState<_NewStudentForm> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _studentPhone = TextEditingController();
  final TextEditingController _parentPhone = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  NewStudentPay? _pay;
  PayMethod _method = PayMethod.cash;

  @override
  void dispose() {
    _name.dispose();
    _studentPhone.dispose();
    _parentPhone.dispose();
    _amount.dispose();
    super.dispose();
  }

  Widget _phoneField(String label, TextEditingController c) {
    final digits = normalizePhone(c.text);
    final valid = isValidEgyptMobile(digits);
    final hasText = digits.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: MnaraText.caption()),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹ \-]')),
          ],
          onChanged: (_) => setState(() {}),
          style: MnaraText.body(),
          decoration: mnaraInput(hint: '01xxxxxxxxx', error: hasText && !valid),
        ),
        if (hasText)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              valid
                  ? 'الرقم تمام'
                  : 'لازم 11 رقم بيبدأ بـ 01 (${digits.length} من 11)',
              style: MnaraText.caption(
                valid ? MnaraColors.green : MnaraColors.redText,
              ),
            ),
          ),
      ],
    );
  }

  bool get _canAdd {
    if (_name.text.trim().isEmpty) return false;
    if (!isValidEgyptMobile(normalizePhone(_studentPhone.text))) return false;
    if (!isValidEgyptMobile(normalizePhone(_parentPhone.text))) return false;
    if (_pay == null) return false;
    if (_pay == NewStudentPay.none) return true;
    return (parsePositiveInt(_amount.text) ?? 0) > 0;
  }

  void _choosePay(NewStudentPay p) {
    final t = ref.read(appProvider).teacher;
    setState(() {
      _pay = p;
      _amount.text = switch (p) {
        NewStudentPay.session => '${t.sessionPrice}',
        NewStudentPay.month => '${t.monthPrice}',
        NewStudentPay.none => '',
      };
    });
  }

  void _submit() {
    final st = ref
        .read(appProvider.notifier)
        .addNewStudent(
          widget.xid,
          name: _name.text,
          studentPhone: normalizePhone(_studentPhone.text),
          parentPhone: normalizePhone(_parentPhone.text),
          pay: _pay!,
          amount: parsePositiveInt(_amount.text) ?? 0,
          method: _method,
        );
    widget.onDone(st.id);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appProvider).teacher;
    Widget payOption(NewStudentPay p, String label, {bool warn = false}) {
      final selected = _pay == p;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _choosePay(p),
            child: Container(
              height: 56,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: selected
                    ? (warn ? MnaraColors.amberBg : MnaraColors.primary)
                    : MnaraColors.card,
                borderRadius: BorderRadius.circular(MnaraRadii.r12),
                border: Border.all(
                  color: selected
                      ? (warn ? MnaraColors.amber : MnaraColors.primary)
                      : MnaraColors.line,
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: MnaraText.captionStrong(
                  warn && selected ? MnaraColors.amber : MnaraColors.text,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('اسم الطالب', style: MnaraText.caption()),
        const SizedBox(height: 6),
        TextField(
          controller: _name,
          onChanged: (_) => setState(() {}),
          style: MnaraText.body(),
          decoration: mnaraInput(hint: 'الاسم الثلاثي'),
        ),
        const SizedBox(height: 12),
        _phoneField('موبايل الطالب', _studentPhone),
        const SizedBox(height: 12),
        _phoneField('موبايل ولي الأمر', _parentPhone),
        const SizedBox(height: 12),
        const InfoBanner(
          text:
              'كود الطالب هيتولّد تلقائي، ومؤقت لحد ما النت يرجع. الرقمين مطلوبين (11 رقم لكل واحد)، عشان بوت الطالب يتأكد من هويته بآخر 4 أرقام.',
          tone: StatusTone.sel,
        ),
        const SizedBox(height: 16),
        Text('الدفع (لازم تأكد)', style: MnaraText.bodyStrong()),
        const SizedBox(height: 8),
        Row(
          children: [
            payOption(NewStudentPay.session, 'دفع حصة (${t.sessionPrice})'),
            const SizedBox(width: 8),
            payOption(NewStudentPay.month, 'دفع شهر (${t.monthPrice})'),
            const SizedBox(width: 8),
            payOption(NewStudentPay.none, 'لسه ما دفعش', warn: true),
          ],
        ),
        if (_pay != null && _pay != NewStudentPay.none) ...[
          const SizedBox(height: 14),
          Text('المبلغ اللي دفعه', style: MnaraText.caption()),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹]')),
                  ],
                  onChanged: (_) => setState(() {}),
                  style: MnaraText.bodyStrong(),
                  decoration: mnaraInput(),
                ),
              ),
              const SizedBox(width: 8),
              Text('جنيه', style: MnaraText.body(MnaraColors.muted)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final m in PayMethod.values) ...[
                Expanded(
                  child: FilterPill(
                    label: m.label,
                    selected: _method == m,
                    onTap: () => setState(() => _method = m),
                  ),
                ),
                if (m != PayMethod.values.last) const SizedBox(width: 6),
              ],
            ],
          ),
        ],
        const SizedBox(height: 18),
        PrimaryButton(
          label: 'إضافة للحصة',
          onPressed: _canAdd ? _submit : null,
        ),
      ],
    );
  }
}
