import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:assistant/data/models/models.dart';
import 'package:assistant/data/providers.dart';
import 'package:assistant/domain/payments.dart';
import 'package:assistant/domain/session_logic.dart';

/// Fallback teacher used until the teacher document is cached.
const Teacher kDefaultTeacher = Teacher(id: '', name: '');

/// Teacher (or defaults while loading).
final teacherOrDefaultProvider = Provider<Teacher>(
  (ref) => ref.watch(teacherProvider).valueOrNull ?? kDefaultTeacher,
);

/// Groups by id.
final groupMapProvider = Provider<Map<String, Group>>(
  (ref) => {
    for (final g in ref.watch(groupsProvider).valueOrNull ?? const <Group>[])
      g.id: g,
  },
);

/// Students by id.
final studentMapProvider = Provider<Map<String, Student>>(
  (ref) => {
    for (final s in ref.watch(studentsProvider).valueOrNull ?? const <Student>[])
      s.id: s,
  },
);

/// Sessions by id.
final sessionMapProvider = Provider<Map<String, Session>>(
  (ref) => {
    for (final s in ref.watch(sessionsProvider).valueOrNull ?? const <Session>[])
      s.id: s,
  },
);

/// Current month of a group.
final groupMonthProvider = Provider.family<int, String>((ref, groupId) {
  final sessions = ref.watch(sessionsProvider).valueOrNull ?? const <Session>[];
  return currentMonthOf(sessions.where((s) => s.groupId == groupId));
});

/// Next session (number, month) of a group.
final nextSessionProvider = Provider.family<NextSession, String>((ref, groupId) {
  final sessions = ref.watch(sessionsProvider).valueOrNull ?? const <Session>[];
  final teacher = ref.watch(teacherOrDefaultProvider);
  return nextSessionFor(
    sessions.where((s) => s.groupId == groupId),
    perMonth: teacher.sessionsPerMonth,
  );
});

/// Payment figures of a student for a given month.
final monthPaymentProvider =
    Provider.family<MonthPayment, ({String studentId, int month})>((ref, key) {
      final students = ref.watch(studentMapProvider);
      final groups = ref.watch(groupMapProvider);
      final teacher = ref.watch(teacherOrDefaultProvider);
      final payments = (ref.watch(paymentsProvider).valueOrNull ?? const <Payment>[])
          .where((p) => p.studentId == key.studentId);
      final student = students[key.studentId];
      final group = student == null ? null : groups[student.groupId];
      final current = student == null
          ? 1
          : ref.watch(groupMonthProvider(student.groupId));
      return monthPayment(
        month: key.month,
        due: monthDue(teacher, group),
        payments: payments,
        currentMonth: current,
      );
    });

/// Payment figures of a student for the current month of their group.
final currentPaymentProvider = Provider.family<MonthPayment, String>((ref, studentId) {
  final student = ref.watch(studentMapProvider)[studentId];
  final month = student == null ? 1 : ref.watch(groupMonthProvider(student.groupId));
  return ref.watch(monthPaymentProvider((studentId: studentId, month: month)));
});
