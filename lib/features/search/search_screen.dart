import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/code_badge.dart';
import 'package:assistant/core/design/widgets/common.dart';
import 'package:assistant/core/design/widgets/status_chip.dart';
import 'package:assistant/data/app_controller.dart';
import 'package:assistant/domain/logic.dart';
import 'package:assistant/domain/models.dart';

/// Search students by code or name (works fully offline from local data).
class SearchScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _c = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _query = v);
    });
    setState(() {}); // refresh the clear button immediately
  }

  void _setText(String v) {
    _c.text = v;
    _c.selection = TextSelection.collapsed(offset: v.length);
    setState(() => _query = v);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider);
    final results = searchStudents(s, _query);
    final hasQuery = _query.trim().isNotEmpty;
    final recents = [
      for (final id in s.recentStudentIds)
        if (studentById(s, id) != null) studentById(s, id)!,
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(
              title: 'بحث عن طالب',
              showBack: false,
              trailing: HeaderLogo(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _c,
                onChanged: _onChanged,
                style: MnaraText.body(),
                decoration: mnaraInput(
                  hint: 'كود الطالب (S12) أو الاسم',
                  prefix: const Icon(Icons.search, color: MnaraColors.muted),
                  suffix: _c.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'مسح',
                          icon: const Icon(Icons.close, color: MnaraColors.muted),
                          onPressed: () => _setText(''),
                        ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  if (!hasQuery && recents.isNotEmpty) ...[
                    Text('اللي بحثت عنهم قريب', style: MnaraText.caption()),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final st in recents)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _setText(st.code),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 44),
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: MnaraColors.card,
                                  borderRadius: BorderRadius.circular(
                                    MnaraRadii.pill,
                                  ),
                                  border: Border.all(color: MnaraColors.line),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      st.code,
                                      textDirection: TextDirection.ltr,
                                      style: MnaraText.captionStrong(
                                        MnaraColors.accent,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(st.name, style: MnaraText.caption()),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    hasQuery
                        ? '${results.length} نتيجة'
                        : 'كل الطلبة · ${results.length}',
                    style: MnaraText.caption(),
                  ),
                  const SizedBox(height: 8),
                  if (results.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Text('مفيش طالب بالاسم أو الكود ده', style: MnaraText.h4()),
                          const SizedBox(height: 8),
                          Text(
                            'جرّب الكود (S12) أو جزء من الاسم. لو طالب جديد، أضفه من شاشة الحصة.',
                            textAlign: TextAlign.center,
                            style: MnaraText.body(MnaraColors.muted),
                          ),
                        ],
                      ),
                    ),
                  for (final st in results) ...[
                    _ResultRow(
                      student: st,
                      onTap: () {
                        ref.read(appProvider.notifier).addRecent(st.id);
                        context.push('/students/${st.id}');
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends ConsumerWidget {
  const _ResultRow({required this.student, required this.onTap});

  final Student student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appProvider);
    final g = groupById(s, student.groupId);
    final status = overallPayStatus(s, student);
    final (label, tone) = switch (status) {
      PayStatus.paid => ('مدفوع', StatusTone.green),
      PayStatus.partial => ('جزئي', StatusTone.amber),
      _ => ('لسه ما دفعش', StatusTone.amber),
    };
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      radius: MnaraRadii.r14,
      onTap: onTap,
      child: Row(
        children: [
          CodeBadge(code: student.code),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name, style: MnaraText.bodyStrong()),
                Text('مجموعة ${g?.name ?? ''}', style: MnaraText.caption()),
              ],
            ),
          ),
          StatusChip(label: label, tone: tone),
        ],
      ),
    );
  }
}
