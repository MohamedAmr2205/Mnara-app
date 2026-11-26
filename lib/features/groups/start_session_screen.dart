import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:assistant/app/routes.dart';
import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/primary_button.dart';
import 'package:assistant/core/design/widgets/screen_parts.dart';
import 'package:assistant/core/sync/write_service.dart';
import 'package:assistant/core/utils/cairo_time.dart';
import 'package:assistant/data/models/models.dart';
import 'package:assistant/data/providers.dart';
import 'package:assistant/domain/session_logic.dart';
import 'package:assistant/features/shared/derived.dart';

/// Confirms the date/number and creates the open session.
class StartSessionScreen extends ConsumerStatefulWidget {
  /// Creates the screen for group [gid].
  const StartSessionScreen({super.key, required this.gid});

  /// Group id.
  final String gid;

  @override
  ConsumerState<StartSessionScreen> createState() => _StartSessionScreenState();
}

class _StartSessionScreenState extends ConsumerState<StartSessionScreen> {
  bool _starting = false;

  void _start(Group group, NextSession next) {
    if (_starting) return;
    setState(() => _starting = true);
    final date = todayIso();
    final session = Session(
      id: const Uuid().v4(),
      groupId: group.id,
      date: date,
      number: next.number,
      monthNumber: next.monthNumber,
      status: SessionStatus.open,
      editableUntil: editableUntilFor(date),
    );
    ref.read(writeServiceProvider).startSession(session, group.name);
    context.go(AppRoutes.sessionPath(session.id));
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(groupMapProvider)[widget.gid];
    final next = ref.watch(nextSessionProvider(widget.gid));
    final count = (ref.watch(studentsProvider).valueOrNull ?? const <Student>[])
        .where((s) => s.groupId == widget.gid && s.active)
        .length;
    final activeId = ref.watch(metaProvider).valueOrNull?.activeSessionId;
    final active = activeId == null ? null : ref.watch(sessionMapProvider)[activeId];
    final hasOpen = active != null && active.isOpen;
    final today = todayIso();
    return Scaffold(
      backgroundColor: MnaraColors.bg,
      body: Stack(
        children: [
          const Positioned(top: 0, left: 0, right: 0, child: Beam()),
          SafeArea(
            child: Column(
              children: [
                ScreenHeader(title: 'بدء حصة جديدة', onBack: () => context.pop()),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    children: [
                      Center(child: Text('المجموعة', style: MnaraText.caption())),
                      Center(child: Text(group?.name ?? '', style: MnaraText.h1())),
                      const SizedBox(height: 24),
                      MnaraCard(
                        child: Column(
                          children: [
                            _Line('التاريخ', '${weekdayOfIso(today)} ${formatDmy(today)}'),
                            const Divider(color: MnaraColors.line),
                            _Line('رقم الحصة', 'الحصة ${next.number} · شهر ${next.monthNumber}'),
                            const Divider(color: MnaraColors.line),
                            _Line('عدد الطلبة', '$count طالب'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      MnaraCard(
                        color: MnaraColors.amberBg,
                        borderColor: MnaraColors.amber,
                        child: Text(
                          hasOpen
                              ? 'فيه حصة مفتوحة ما اتقفلتش على الموبايل. كمّلها الأول.'
                              : 'مفيش نت دلوقتي؟ كمّل عادي. الحصة هتتحفظ على موبايلك وتترفع لوحدها أول ما النت يرجع.',
                          style: MnaraText.small(MnaraColors.amber),
                        ),
                      ),
                    ],
                  ),
                ),
                BottomBar(
                  child: hasOpen
                      ? PrimaryButton(
                          label: 'كمّل الحصة المفتوحة',
                          onPressed: () => context.go(AppRoutes.sessionPath(active.id)),
                        )
                      : PrimaryButton(
                          label: _starting ? 'ثواني...' : 'ابدأ الحصة دلوقتي',
                          onPressed: (group == null || _starting) ? null : () => _start(group, next),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: MnaraText.small(MnaraColors.muted))),
          Text(value, style: MnaraText.h4()),
        ],
      ),
    );
  }
}
