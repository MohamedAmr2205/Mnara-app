import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/code_badge.dart';
import 'package:assistant/core/design/widgets/common.dart';
import 'package:assistant/core/design/widgets/primary_button.dart';
import 'package:assistant/core/design/widgets/stat_tile.dart';
import 'package:assistant/core/design/widgets/status_chip.dart';
import 'package:assistant/core/util/date_utils.dart';
import 'package:assistant/core/util/text_utils.dart';
import 'package:assistant/data/app_controller.dart';
import 'package:assistant/domain/logic.dart';
import 'package:assistant/domain/models.dart';

class _Receipt {
  const _Receipt({
    required this.month,
    required this.amount,
    required this.method,
    required this.leftAfter,
  });

  final int month;
  final int amount;
  final PayMethod method;
  final int leftAfter;
}

/// Record a payment for one month of a student.
class PaymentScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [studentId].
  const PaymentScreen({super.key, required this.studentId});

  /// Student id.
  final String studentId;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  int? _month;
  PayMethod _method = PayMethod.cash;
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _date = TextEditingController();
  bool _inited = false;
  _Receipt? _receipt;

  @override
  void dispose() {
    _amount.dispose();
    _date.dispose();
    super.dispose();
  }

  void _selectMonth(AppState s, int month) {
    final left = remainingFor(s, widget.studentId, month);
    setState(() {
      _month = month;
      _amount.text = left > 0 ? '$left' : '';
    });
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
    final months = monthsFor(s, st);
    final current = currentMonthOf(s, st.groupId);

    if (!_inited) {
      _inited = true;
      _date.text = formatDate(ref.read(clockProvider)());
      var m = months.contains(current) ? current : months.first;
      if (remainingFor(s, st.id, m) == 0) {
        for (final x in months) {
          if (remainingFor(s, st.id, x) > 0) {
            m = x;
            break;
          }
        }
      }
      _month = m;
      final left = remainingFor(s, st.id, m);
      _amount.text = left > 0 ? '$left' : '';
    }

    final r = _receipt;
    if (r != null) {
      return _Success(student: st, receipt: r);
    }

    final month = _month ?? months.first;
    final need = s.teacher.monthPrice;
    final paid = paidFor(s, st.id, month);
    final left = remainingFor(s, st.id, month);
    final full = left == 0;
    final amount = parsePositiveInt(_amount.text);
    final over = amount != null && amount > left;
    final date = parseUserDate(_date.text);
    final canSave = !full && amount != null && !over && date != null;

    final quick = <(String, int)>[
      ('المتبقي كله ($left)', left),
      ('نصه (${(left / 2).round()})', (left / 2).round()),
      ('حصة (${s.teacher.sessionPrice})', s.teacher.sessionPrice),
    ];
    final seen = <int>{};
    final quickShown = quick.where((q) {
      if (q.$2 <= 0 || q.$2 > left) return false;
      return seen.add(q.$2);
    }).toList();

    String? message;
    Color messageColor = MnaraColors.muted;
    if (amount != null && !full) {
      if (over) {
        message = 'المبلغ أكبر من المتبقي ($left جنيه)';
        messageColor = MnaraColors.redText;
      } else if (amount == left) {
        message = 'الدفعة دي هتكمّل الشهر';
        messageColor = MnaraColors.green;
      } else {
        message = 'دفعة جزئية · هيفضل ${left - amount} جنيه';
        messageColor = MnaraColors.amber;
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(title: 'تسجيل دفعة'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CodeBadge(code: st.code),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(st.name, style: MnaraText.bodyStrong()),
                              Text(g?.name ?? '', style: MnaraText.caption()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('الشهر', style: MnaraText.bodyStrong()),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final m in months) ...[
                        Expanded(
                          child: _MonthChip(
                            month: m,
                            selected: m == month,
                            status: payStatus(
                              s,
                              st.id,
                              m,
                              currentMonth: current,
                            ),
                            left: remainingFor(s, st.id, m),
                            onTap: () => _selectMonth(s, m),
                          ),
                        ),
                        if (m != months.last) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: StatTile(label: 'المطلوب', value: '$need ج')),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatTile(
                          label: 'اتدفع',
                          value: '$paid ج',
                          valueColor: MnaraColors.green,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatTile(
                          label: 'المتبقي',
                          value: '$left ج',
                          valueColor: left > 0
                              ? MnaraColors.amber
                              : MnaraColors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (full)
                    const InfoBanner(
                      text: 'الشهر ده مدفوع بالكامل. اختار شهر تاني.',
                      tone: StatusTone.green,
                    )
                  else ...[
                    Text('المبلغ', style: MnaraText.bodyStrong()),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          width: 110,
                          height: 48,
                          child: TextField(
                            controller: _amount,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.ltr,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9٠-٩۰-۹]'),
                              ),
                            ],
                            onChanged: (_) => setState(() {}),
                            style: MnaraText.h4(),
                            decoration: mnaraInput(error: over),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('جنيه', style: MnaraText.body(MnaraColors.muted)),
                      ],
                    ),
                    if (quickShown.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final q in quickShown)
                            FilterPill(
                              label: q.$1,
                              selected: amount == q.$2,
                              onTap: () =>
                                  setState(() => _amount.text = '${q.$2}'),
                            ),
                        ],
                      ),
                    ],
                    if (message != null) ...[
                      const SizedBox(height: 8),
                      Semantics(
                        liveRegion: true,
                        child: Text(message, style: MnaraText.small(messageColor)),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text('طريقة الدفع', style: MnaraText.bodyStrong()),
                    const SizedBox(height: 8),
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
                          if (m != PayMethod.values.last)
                            const SizedBox(width: 6),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('تاريخ الدفع', style: MnaraText.bodyStrong()),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          width: 150,
                          height: 48,
                          child: TextField(
                            controller: _date,
                            keyboardType: TextInputType.datetime,
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.ltr,
                            onChanged: (_) => setState(() {}),
                            style: MnaraText.bodyStrong(),
                            decoration: mnaraInput(
                              hint: 'dd/mm/yyyy',
                              error: _date.text.isNotEmpty && date == null,
                            ),
                          ),
                        ),
                        if (_date.text.isNotEmpty && date == null) ...[
                          const SizedBox(width: 8),
                          Text(
                            'تاريخ مش صح',
                            style: MnaraText.caption(MnaraColors.redText),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            StickyCta(
              child: PrimaryButton(
                label: 'حفظ الدفعة',
                icon: Icons.check_rounded,
                onPressed: canSave
                    ? () {
                        // canSave guarantees both values are non-null.
                        final pay = amount!;
                        final when = date!;
                        ref
                            .read(appProvider.notifier)
                            .addPayment(
                              studentId: st.id,
                              month: month,
                              amount: pay,
                              method: _method,
                              date: when,
                            );
                        setState(
                          () => _receipt = _Receipt(
                            month: month,
                            amount: pay,
                            method: _method,
                            leftAfter: left - pay,
                          ),
                        );
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthChip extends StatelessWidget {
  const _MonthChip({
    required this.month,
    required this.selected,
    required this.status,
    required this.left,
    required this.onTap,
  });

  final int month;
  final bool selected;
  final PayStatus status;
  final int left;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (sub, subColor) = switch (status) {
      PayStatus.paid => ('مدفوع', MnaraColors.green),
      PayStatus.partial => ('باقي $left', MnaraColors.amber),
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
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? MnaraColors.primary : MnaraColors.card,
            borderRadius: BorderRadius.circular(MnaraRadii.r14),
            border: Border.all(
              color: selected ? MnaraColors.primary : MnaraColors.line,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('شهر $month', style: MnaraText.bodyStrong()),
              Text(sub, style: MnaraText.captionStrong(subColor)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Success extends ConsumerWidget {
  const _Success({required this.student, required this.receipt});

  final Student student;
  final _Receipt receipt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = receipt.leftAfter <= 0;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: MnaraColors.greenBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: MnaraColors.green, width: 3),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 52,
                    color: MnaraColors.green,
                  ),
                ),
                const SizedBox(height: 20),
                Text('اتسجّلت الدفعة', style: MnaraText.h2()),
                const SizedBox(height: 10),
                Text(
                  '${student.name} · شهر ${receipt.month}',
                  textAlign: TextAlign.center,
                  style: MnaraText.body(MnaraColors.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  '${receipt.amount} جنيه · ${receipt.method.label}',
                  style: MnaraText.bodyStrong(),
                ),
                const SizedBox(height: 4),
                Text(
                  done ? 'الشهر اتكمّل' : 'هيفضل ${receipt.leftAfter} جنيه',
                  style: MnaraText.bodyStrong(
                    done ? MnaraColors.green : MnaraColors.amber,
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Text(
                    ref.watch(appProvider.select((s) => s.online))
                        ? 'اتحفظت على الموبايل واترفعت.'
                        : 'اتحفظت على الموبايل، وهتترفع للداتابيز أول ما النت يرجع.',
                    textAlign: TextAlign.center,
                    style: MnaraText.small(MnaraColors.muted),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 300,
                  child: PrimaryButton(
                    label: 'رجوع للطالب',
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/students/${student.id}');
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
