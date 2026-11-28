import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/common.dart';
import 'package:assistant/core/design/widgets/primary_button.dart';
import 'package:assistant/core/design/widgets/status_chip.dart';
import 'package:assistant/core/util/date_utils.dart';
import 'package:assistant/data/app_controller.dart';
import 'package:assistant/domain/logic.dart';
import 'package:assistant/domain/models.dart';

/// Confirmation screen before opening a new session.
class StartSessionScreen extends ConsumerWidget {
  /// Creates the screen for [groupId].
  const StartSessionScreen({super.key, required this.groupId});

  /// Group the session belongs to.
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appProvider);
    final g = groupById(s, groupId);
    if (g == null) {
      return const Scaffold(
        body: SafeArea(child: ScreenHeader(title: 'المجموعة مش موجودة')),
      );
    }
    final today = ref.watch(clockProvider)();
    Session? open;
    for (final x in s.sessions) {
      if (x.groupId == g.id && x.status == SessionStatus.open) open = x;
    }
    final slot = open == null
        ? nextSessionSlot(s, g.id)
        : (number: open.number, month: open.month);
    final count = open?.order.length ?? studentsOfGroup(s, g.id).length;

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(label, style: MnaraText.body(MnaraColors.muted)),
          const Spacer(),
          Text(value, style: MnaraText.bodyStrong()),
        ],
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(title: 'بدء حصة جديدة'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                children: [
                  Center(
                    child: Text('المجموعة', style: MnaraText.body(MnaraColors.muted)),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      g.name,
                      textAlign: TextAlign.center,
                      style: MnaraText.h2(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppCard(
                    child: Column(
                      children: [
                        row('التاريخ', formatDateWithDay(today)),
                        const Divider(height: 1, color: MnaraColors.line),
                        row('رقم الحصة', 'الحصة ${slot.number} · شهر ${slot.month}'),
                        const Divider(height: 1, color: MnaraColors.line),
                        row('عدد الطلبة', '$count طالب'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const InfoBanner(
                    text:
                        'مفيش نت دلوقتي؟ كمّل عادي. الحصة هتتحفظ على موبايلك وتترفع لوحدها أول ما النت يرجع.',
                  ),
                  if (open != null) ...[
                    const SizedBox(height: 12),
                    const InfoBanner(
                      text: 'فيه حصة مفتوحة للمجموعة دي. هتكمّل عليها.',
                      tone: StatusTone.sel,
                    ),
                  ],
                ],
              ),
            ),
            StickyCta(
              child: PrimaryButton(
                label: 'ابدأ الحصة دلوقتي',
                icon: Icons.play_arrow_rounded,
                onPressed: () {
                  final id = ref.read(appProvider.notifier).startSession(g.id);
                  context.pushReplacement('/session/$id');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
