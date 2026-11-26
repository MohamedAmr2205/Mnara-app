import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:assistant/app/routes.dart';
import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/primary_button.dart';
import 'package:assistant/core/design/widgets/screen_parts.dart';
import 'package:assistant/core/design/widgets/stat_tile.dart';
import 'package:assistant/core/sync/connectivity.dart';
import 'package:assistant/core/sync/write_service.dart';
import 'package:assistant/core/utils/cairo_time.dart';
import 'package:assistant/data/models/enums.dart';
import 'package:assistant/data/models/models.dart';
import 'package:assistant/data/providers.dart';
import 'package:assistant/data/repository.dart';
import 'package:assistant/domain/payments.dart';
import 'package:assistant/domain/session_logic.dart';
import 'package:assistant/features/session/session_controller.dart';
import 'package:assistant/features/shared/derived.dart';

/// Review, add notes and save the session in one atomic batch.
class FinishScreen extends ConsumerStatefulWidget {
  /// Creates the screen for session [sessionId].
  const FinishScreen({super.key, required this.sessionId, this.edit = false});

  /// Session id.
  final String sessionId;

  /// Edit mode (saving changes of a finished session).
  final bool edit;

  @override
  ConsumerState<FinishScreen> createState() => _FinishScreenState();
}

class _FinishScreenState extends ConsumerState<FinishScreen> {
  final _notes = TextEditingController();
  bool _init = false;
  bool _saved = false;
  SessionSummary? _savedSummary;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionMapProvider)[widget.sessionId];
    final group = session == null ? null : ref.watch(groupMapProvider)[session.groupId];
    final ui = ref.watch(sessionControllerProvider(widget.sessionId));
    final online = ref.watch(isOnlineProvider);
    if (session == null || group == null) {
      return const Scaffold(
        backgroundColor: MnaraColors.bg,
        body: Center(child: CircularProgressIndicator(color: MnaraColors.accent)),
      );
    }
    if (!_init) {
      _init = true;
      _notes.text = session.notes;
    }
    final home = (ref.watch(studentsProvider).valueOrNull ?? const <Student>[])
        .where((s) => s.groupId == group.id && s.active)
        .toList();
    final rosterIds = {...home.map((s) => s.id), ...ui.extras};
    var owing = 0;
    for (final s in home) {
      if (ref.watch(currentPaymentProvider(s.id)).status != PayStatus.paid) owing++;
    }
    final records = ui.records.values.where((r) => rosterIds.contains(r.studentId)).toList();
    final summary = summarize(
      records: records,
      total: rosterIds.length,
      maxExam: ui.noExam ? null : ui.maxExam,
      owingCount: owing,
    );
    final t = summary.tally;

    Future<void> save() async {
      final updated = session.copyWith(
        notes: _notes.text.trim(),
        maxExam: ui.maxExam,
        noExam: ui.noExam,
        status: widget.edit ? null : SessionStatus.finished,
        finishedAt: widget.edit ? null : DateTime.now(),
      );
      final writes = ref.read(writeServiceProvider);
      if (widget.edit) {
        writes.saveSessionEdits(updated, group.name);
      } else {
        final drafts = [
          for (final r in records)
            if (r.kind == RecordKind.newStudent && r.newStudent != null) r.newStudent!,
        ];
        writes.finishSession(
          FinishPlan(session: updated, newStudents: drafts, groupId: group.id),
          groupName: group.name,
          rosterSize: rosterIds.length,
        );
      }
      setState(() {
        _saved = true;
        _savedSummary = summary;
      });
    }

    if (_saved) {
      final s = _savedSummary!;
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
                Text(widget.edit ? 'اتحفظت التعديلات' : 'اتحفظت الحصة', style: MnaraText.h1()),
                const SizedBox(height: 8),
                Text('${group.name} · ${session.label}', style: MnaraText.body(MnaraColors.muted), textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(
                  '${s.tally.attended} حضر · ${s.homeworkRated} واجب اتقيّم · ${s.examCount} امتحان اتسجل',
                  style: MnaraText.small(MnaraColors.muted),
                  textAlign: TextAlign.center,
                ),
                if (!online) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: MnaraColors.amber)),
                      const SizedBox(width: 8),
                      Text('مستنية النت عشان ترفع للداتابيز', style: MnaraText.small(MnaraColors.amber)),
                    ],
                  ),
                ],
                const Spacer(),
                PrimaryButton(
                  label: widget.edit ? 'رجوع للسجل' : 'رجوع للمجاميع',
                  onPressed: () => context.go(widget.edit ? AppRoutes.history : AppRoutes.groups),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: MnaraColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'ملاحظات وإنهاء الحصة',
              subtitle: 'راجع الملخص قبل ما تحفظ',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.45,
                    children: [
                      StatTile(
                        value: '${t.attended} من ${t.total}',
                        label: 'الحضور',
                        caption: 'متأخر ${t.late} · غايب ${t.absent} · بعذر ${t.excused}',
                        valueColor: MnaraColors.green,
                      ),
                      StatTile(
                        value: '${summary.homeworkRated} اتقيّم',
                        label: 'الواجب',
                        caption: 'لم يسلم ${summary.homeworkNotSubmitted}',
                      ),
                      StatTile(
                        value: ui.noExam || summary.examAverage == null
                            ? '--'
                            : '${_oneDecimal(summary.examAverage!)} من ${ui.maxExam}',
                        label: 'الامتحان',
                        caption: ui.noExam
                            ? 'مفيش امتحان'
                            : (summary.examAveragePercent == null ? 'لسه' : 'متوسط ${summary.examAveragePercent}%'),
                      ),
                      StatTile(
                        value: '${summary.owingCount} لسه',
                        label: 'الدفع',
                        caption: 'شهر ${session.monthNumber}',
                        valueColor: summary.owingCount > 0 ? MnaraColors.amber : MnaraColors.green,
                      ),
                    ],
                  ),
                  if (t.unmarked > 0) ...[
                    const SizedBox(height: 10),
                    Text(
                      '${t.unmarked} طالب لسه ما اتعلّموش. هيتسجّلوا من غير حضور.',
                      style: MnaraText.small(MnaraColors.amber),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text('ملاحظات الحصة', style: MnaraText.h4()),
                  const SizedBox(height: 8),
                  MnaraTextField(
                    controller: _notes,
                    maxLines: 4,
                    maxLength: 2000,
                    hint: 'اكتب أي ملاحظة عن الحصة أو عن طالب معين...',
                  ),
                  if (!online) ...[
                    const SizedBox(height: 12),
                    MnaraCard(
                      color: MnaraColors.amberBg,
                      borderColor: MnaraColors.amber,
                      child: Text(
                        'مفيش نت حاليا. الحصة هتتحفظ على الموبايل وتترفع للداتابيز تلقائي لما النت يرجع.',
                        style: MnaraText.small(MnaraColors.amber),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            BottomBar(
              child: PrimaryButton(
                label: widget.edit ? 'حفظ التعديلات' : 'إنهاء وحفظ الحصة',
                onPressed: save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _oneDecimal(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
