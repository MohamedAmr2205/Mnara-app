import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:assistant/app/routes.dart';
import 'package:assistant/core/design/tokens.dart';
import 'package:assistant/core/design/widgets/code_badge.dart';
import 'package:assistant/core/design/widgets/status_chip.dart';
import 'package:assistant/core/design/widgets/screen_parts.dart';
import 'package:assistant/core/security/auth_controller.dart';
import 'package:assistant/core/utils/arabic_text.dart';
import 'package:assistant/data/models/models.dart';
import 'package:assistant/data/providers.dart';
import 'package:assistant/domain/payments.dart';
import 'package:assistant/features/shared/derived.dart';

/// Student search over the on-device cache.
class SearchScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const _recentKey = 'recent.students';
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  List<String> _recent = const [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    try {
      final raw = await ref.read(keyValueStoreProvider).read(_recentKey);
      if (raw != null && mounted) {
        setState(() => _recent = raw.split(',').where((e) => e.isNotEmpty).toList());
      }
    } catch (_) {}
  }

  Future<void> _remember(String id) async {
    final next = [id, ..._recent.where((e) => e != id)].take(8).toList();
    setState(() => _recent = next);
    try {
      await ref.read(keyValueStoreProvider).write(_recentKey, next.join(','));
    } catch (_) {}
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = v);
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(studentsProvider).valueOrNull ?? const <Student>[];
    final groups = ref.watch(groupMapProvider);
    final map = ref.watch(studentMapProvider);
    final results = [
      for (final s in students)
        if (matchesStudent(query: _query, code: s.code, name: s.name)) s,
    ]..sort((a, b) => a.name.compareTo(b.name));
    final hasQuery = _query.trim().isNotEmpty;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TabTitle(title: 'بحث عن طالب'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: MnaraTextField(
              controller: _controller,
              height: 54,
              hint: 'كود الطالب (S12) أو الاسم',
              prefix: const Icon(Icons.search, color: MnaraColors.muted),
              suffix: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح',
                      icon: const Icon(Icons.close, color: MnaraColors.muted),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                    ),
              onChanged: _onChanged,
            ),
          ),
          if (!hasQuery && _recent.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('اللي بحثت عنهم قريب', style: MnaraText.small(MnaraColors.muted)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final id in _recent)
                        if (map[id] != null)
                          ChoicePill(
                            label: '${map[id]!.code} ${map[id]!.name}',
                            selected: false,
                            onTap: () {
                              _controller.text = map[id]!.code;
                              setState(() => _query = map[id]!.code);
                            },
                          ),
                    ],
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Text(hasQuery ? '${results.length} نتيجة' : 'كل الطلبة · ${students.length}', style: MnaraText.small(MnaraColors.muted)),
          ),
          Expanded(
            child: results.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Text('مفيش طالب بالاسم أو الكود ده', style: MnaraText.h4(), textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text(
                          'جرّب الكود (S12) أو جزء من الاسم. لو طالب جديد، أضفه من شاشة الحصة.',
                          style: MnaraText.small(MnaraColors.muted),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final s = results[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ResultRow(
                          student: s,
                          groupName: groups[s.groupId]?.name ?? '',
                          onTap: () {
                            _remember(s.id);
                            context.push(AppRoutes.studentPath(s.id));
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends ConsumerWidget {
  const _ResultRow({required this.student, required this.groupName, required this.onTap});

  final Student student;
  final String groupName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pay = ref.watch(currentPaymentProvider(student.id));
    final (label, tone) = switch (pay.status) {
      PayStatus.paid => ('مدفوع', StatusTone.green),
      PayStatus.partial => ('جزئي', StatusTone.amber),
      _ => ('لسه ما دفعش', StatusTone.amber),
    };
    return MnaraCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          CodeBadge(code: student.code),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name, style: MnaraText.bodyStrong(), overflow: TextOverflow.ellipsis),
                Text('مجموعة $groupName', style: MnaraText.caption()),
              ],
            ),
          ),
          StatusChip(label: label, tone: tone),
        ],
      ),
    );
  }
}
