import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/common.dart';
import 'package:assistant/core/design/widgets/primary_button.dart';
import 'package:assistant/core/design/widgets/stat_tile.dart';
import 'package:assistant/core/util/text_utils.dart';
import 'package:assistant/data/app_controller.dart';
import 'package:assistant/domain/logic.dart';
import 'package:assistant/domain/models.dart';

/// Review summary, session notes and the final save.
class FinishScreen extends ConsumerStatefulWidget {
  /// Creates the screen for session [xid].
  const FinishScreen({super.key, required this.xid});

  /// Session id.
  final String xid;

  @override
  ConsumerState<FinishScreen> createState() => _FinishScreenState();
}

class _FinishScreenState extends ConsumerState<FinishScreen> {
  final TextEditingController _notes = TextEditingController();
  bool _inited = false;
  bool _saved = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
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
    if (!_inited) {
      _notes.text = x.notes;
      _inited = true;
    }
    final g = groupById(s, x.groupId);
    final sum = summaryOf(s, x);
    final c = sum.counts;
    final attended = c.present + c.late;

    if (_saved) return _Saved(session: x, groupName: g?.name ?? '', sum: sum);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(
              title: 'ملاحظات وإنهاء الحصة',
              subtitle: 'راجع الملخص قبل ما تحفظ',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          label: 'الحضور',
                          value: '$attended من ${c.total}',
                          caption:
                              'متأخر ${c.late} · غايب ${c.absent} · بعذر ${c.excused}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatTile(
                          label: 'الواجب',
                          value: '${sum.homeworkGraded} اتقيّم',
                          caption: 'لم يسلم ${sum.homeworkMissing}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          label: 'الامتحان',
                          value: x.noExam || sum.examCount == 0
                              ? '--'
                              : '${formatScore(double.parse(sum.examAverage.toStringAsFixed(1)))} من ${x.examMax}',
                          caption: x.noExam
                              ? 'مفيش امتحان'
                              : sum.examCount == 0
                              ? 'لسه ما اتسجّلش'
                              : 'متوسط ${sum.examPercent}%',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatTile(
                          label: 'الدفع',
                          value: '${sum.unpaid} لسه',
                          valueColor: sum.unpaid > 0
                              ? MnaraColors.amber
                              : MnaraColors.green,
                          caption: 'شهر ${x.month}',
                        ),
                      ),
                    ],
                  ),
                  if (c.unmarked > 0) ...[
                    const SizedBox(height: 12),
                    InfoBanner(
                      text: 'فيه ${c.unmarked} طالب لسه ما اتعلّموش. تقدر ترجع تعلّمهم.',
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text('ملاحظات الحصة', style: MnaraText.bodyStrong()),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notes,
                    maxLines: 4,
                    style: MnaraText.body(),
                    decoration: mnaraInput(
                      hint: 'اكتب أي ملاحظة عن الحصة أو عن طالب معين...',
                    ),
                  ),
                  if (!s.online) ...[
                    const SizedBox(height: 12),
                    const InfoBanner(
                      text:
                          'مفيش نت حاليا. الحصة هتتحفظ على الموبايل وتترفع للداتابيز تلقائي لما النت يرجع.',
                    ),
                  ],
                ],
              ),
            ),
            StickyCta(
              child: PrimaryButton(
                label: x.status == SessionStatus.closed
                    ? 'حفظ التعديلات'
                    : 'إنهاء وحفظ الحصة',
                icon: Icons.check_rounded,
                onPressed: () {
                  ref
                      .read(appProvider.notifier)
                      .finishSession(x.id, _notes.text);
                  setState(() => _saved = true);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Saved extends ConsumerWidget {
  const _Saved({
    required this.session,
    required this.groupName,
    required this.sum,
  });

  final Session session;
  final String groupName;
  final SessionSummary sum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(appProvider.select((s) => s.online));
    final c = sum.counts;
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
                Text('اتحفظت الحصة', style: MnaraText.h2()),
                const SizedBox(height: 10),
                Text(
                  '$groupName · الحصة ${session.number} · شهر ${session.month}',
                  textAlign: TextAlign.center,
                  style: MnaraText.body(MnaraColors.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  '${c.present + c.late} حضر · ${sum.homeworkGraded} واجب اتقيّم · ${sum.examCount} امتحان اتسجل',
                  textAlign: TextAlign.center,
                  style: MnaraText.small(MnaraColors.muted),
                ),
                if (!online) ...[
                  const SizedBox(height: 18),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: MnaraColors.amber,
                        ),
                      ),
                      SizedBox(width: 10),
                      _AmberText('مستنية النت عشان ترفع للداتابيز'),
                    ],
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: 300,
                  child: PrimaryButton(
                    label: 'رجوع للمجاميع',
                    onPressed: () => context.go('/groups'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go('/history'),
                  child: Text(
                    'شوف السجل',
                    style: MnaraText.bodyStrong(MnaraColors.accent),
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

class _AmberText extends StatelessWidget {
  const _AmberText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: MnaraText.small(MnaraColors.amber));
}
