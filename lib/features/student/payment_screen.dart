import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/code_badge.dart';
import 'package:assistant/core/design/widgets/primary_button.dart';
import 'package:assistant/core/design/widgets/screen_parts.dart';
import 'package:assistant/core/design/widgets/stat_tile.dart';
import 'package:assistant/core/sync/write_service.dart';
import 'package:assistant/core/utils/arabic_text.dart';
import 'package:assistant/core/utils/cairo_time.dart';
import 'package:assistant/data/models/enums.dart';
import 'package:assistant/data/models/models.dart';
import 'package:assistant/data/providers.dart';
import 'package:assistant/domain/payments.dart';
import 'package:assistant/features/shared/derived.dart';

/// Record a payment for a student.
class PaymentScreen extends ConsumerStatefulWidget {
  /// Creates the screen for student [sid].
  const PaymentScreen({super.key, required this.sid});

  /// Student id.
  final String sid;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  int? _month;
  final _amount = TextEditingController();
  late final TextEditingController _date = TextEditingController(text: formatDmy(todayIso()));
  PayMethod _method = PayMethod.cash;
  bool _saved = false;
  Payment? _savedPayment;
  bool _savedComplete = false;
  int _savedRemaining = 0;

  @override
  void dispose() {
    _amount.dispose();
    _date.dispose();
    super.dispose();
  }

  void _selectMonth(int m, int remaining) {
    setState(() {
      _month = m;
      _amount.text = remaining > 0 ? '$remaining' : '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final student = ref.watch(studentMapProvider)[widget.sid];
    if (student == null) {
      return Scaffold(
        backgroundColor: MnaraColors.bg,
        body: SafeArea(child: ScreenHeader(title: 'تسجيل دفعة', onBack: () => context.pop())),
      );
    }
    final group = ref.watch(groupMapProvider)[student.groupId];
    final teacher = ref.watch(teacherOrDefaultProvider);
    final currentMonth = ref.watch(groupMonthProvider(student.groupId));
    final month = _month ?? currentMonth;
    final months = monthsToShow(currentMonth);
    final pay = ref.watch(monthPaymentProvider((studentId: student.id, month: month)));

    if (_saved && _savedPayment != null) {
      final p = _savedPayment!;
      return Scaffold(
        backgroundColor: MnaraColors.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                const SuccessMark(),
                const SizedBox(height: 20),
                Text('اتسجّلت الدفعة', style: MnaraText.h1()),
                const SizedBox(height: 8),
                Text('${student.name} · شهر ${p.month}', style: MnaraText.body(MnaraColors.muted)),
                Text('${p.amountEgp} جنيه · ${p.method.label}', style: MnaraText.bodyStrong()),
                const SizedBox(height: 4),
                Text(
                  _savedComplete ? 'الشهر اتكمّل' : 'هيفضل $_savedRemaining جنيه',
                  style: MnaraText.small(_savedComplete ? MnaraColors.green : MnaraColors.amber),
                ),
                const SizedBox(height: 16),
                MnaraCard(
                  child: Text(
                    'اتحفظت على الموبايل، وهتترفع للداتابيز أول ما النت يرجع.',
                    style: MnaraText.small(MnaraColors.muted),
                  ),
                ),
                const Spacer(),
                PrimaryButton(label: 'رجوع للطالب', onPressed: () => context.pop()),
              ],
            ),
          ),
        ),
      );
    }

    final amount = int.tryParse(normalizeDigits(_amount.text).trim());
    final over = amount != null && amount > pay.remaining;
    final dateIso = parseDmyInput(_date.text);
    final canSave = pay.remaining > 0 && amount != null && amount > 0 && !over && dateIso != null;
    final quick = <(String, int)>[
      ('المتبقي كله (${pay.remaining})', pay.remaining),
      ('نصه (${(pay.remaining / 2).round()})', (pay.remaining / 2).round()),
      ('حصة (${sessionPrice(teacher, group)})', sessionPrice(teacher, group)),
    ].where((q) => q.$2 > 0 && q.$2 <= pay.remaining).toList();

    String? message;
    Color messageColor = MnaraColors.muted;
    if (amount != null && amount > 0) {
      if (over) {
        message = 'المبلغ أكبر من المتبقي (${pay.remaining} جنيه)';
        messageColor = MnaraColors.redText;
      } else if (amount == pay.remaining) {
        message = 'الدفعة دي هتكمّل الشهر';
        messageColor = MnaraColors.green;
      } else {
        message = 'دفعة جزئية · هيفضل ${pay.remaining - amount} جنيه';
        messageColor = MnaraColors.amber;
      }
    }

    void save() {
      if (!canSave) return;
      FocusScope.of(context).unfocus();
      final payment = Payment(
        id: const Uuid().v4(),
        studentId: student.id,
        groupId: student.groupId,
        month: month,
        amountEgp: amount,
        method: _method,
        paidOn: dateIso,
      );
      ref.read(writeServiceProvider).addPayment(payment, student.name);
      setState(() {
        _saved = true;
        _savedPayment = payment;
        _savedComplete = amount == pay.remaining;
        _savedRemaining = pay.remaining - amount;
      });
    }

    return Scaffold(
      backgroundColor: MnaraColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(title: 'تسجيل دفعة', onBack: () => context.pop()),
            Expanded(
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  MnaraCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CodeBadge(code: student.code),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(student.name, style: MnaraText.bodyStrong()),
                              Text(group?.name ?? '', style: MnaraText.caption()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('الشهر', style: MnaraText.h4()),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final m in months)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: _MonthChip(
                              month: m,
                              selected: m == month,
                              pay: ref.watch(monthPaymentProvider((studentId: student.id, month: m))),
                              onTap: () => _selectMonth(
                                m,
                                ref.read(monthPaymentProvider((studentId: student.id, month: m))).remaining,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: StatTile(value: '${pay.due} ج', label: 'المطلوب')),
                      const SizedBox(width: 8),
                      Expanded(child: StatTile(value: '${pay.paid} ج', label: 'اتدفع', valueColor: MnaraColors.green)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StatTile(
                          value: '${pay.remaining} ج',
                          label: 'المتبقي',
                          valueColor: pay.remaining > 0 ? MnaraColors.amber : MnaraColors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (pay.remaining == 0)
                    MnaraCard(
                      color: MnaraColors.greenBg,
                      borderColor: MnaraColors.green,
                      child: Text('الشهر ده مدفوع بالكامل. اختار شهر تاني.', style: MnaraText.small(MnaraColors.green)),
                    )
                  else ...[
                    Text('المبلغ', style: MnaraText.h4()),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          width: 130,
                          child: MnaraTextField(
                            controller: _amount,
                            height: 48,
                            keyboardType: TextInputType.number,
                            textDirection: TextDirection.ltr,
                            hasError: over,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('جنيه', style: MnaraText.body(MnaraColors.muted)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final q in quick)
                          ChoicePill(
                            label: q.$1,
                            selected: amount == q.$2,
                            onTap: () => setState(() => _amount.text = '${q.$2}'),
                          ),
                      ],
                    ),
                    SizedBox(
                      height: 28,
                      child: message == null
                          ? null
                          : Align(
                              alignment: Alignment.centerRight,
                              child: Text(message, style: MnaraText.small(messageColor)),
                            ),
                    ),
                    const SizedBox(height: 8),
                    Text('طريقة الدفع', style: MnaraText.h4()),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final m in PayMethod.values) ...[
                          Expanded(child: ChoicePill(label: m.label, selected: _method == m, onTap: () => setState(() => _method = m))),
                          if (m != PayMethod.values.last) const SizedBox(width: 6),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text('تاريخ الدفع', style: MnaraText.h4()),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 170,
                      child: MnaraTextField(
                        controller: _date,
                        height: 48,
                        keyboardType: TextInputType.datetime,
                        textDirection: TextDirection.ltr,
                        hasError: dateIso == null,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (dateIso == null)
                      Text('اكتب التاريخ بالشكل ده: 25/11/2026', style: MnaraText.caption(MnaraColors.redText)),
                  ],
                ],
              ),
            ),
            BottomBar(child: PrimaryButton(label: 'حفظ الدفعة', onPressed: canSave ? save : null)),
          ],
        ),
      ),
    );
  }
}

class _MonthChip extends StatelessWidget {
  const _MonthChip({required this.month, required this.selected, required this.pay, required this.onTap});

  final int month;
  final bool selected;
  final MonthPayment pay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (sub, color) = switch (pay.status) {
      PayStatus.paid => ('مدفوع', MnaraColors.green),
      PayStatus.partial => ('باقي ${pay.remaining}', MnaraColors.amber),
      _ => ('لسه', MnaraColors.muted),
    };
    return Semantics(
      button: true,
      selected: selected,
      label: 'شهر $month $sub',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 92,
          constraints: const BoxConstraints(minHeight: 60),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? MnaraColors.primary : MnaraColors.card,
            borderRadius: BorderRadius.circular(MnaraRadii.r14),
            border: Border.all(color: selected ? MnaraColors.primary : MnaraColors.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('شهر $month', style: MnaraText.bodyStrong()),
              Text(sub, style: MnaraText.caption(selected ? MnaraColors.text : color)),
            ],
          ),
        ),
      ),
    );
  }
}
