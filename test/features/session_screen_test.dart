import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:assistant/data/models/enums.dart';
import 'package:assistant/data/models/models.dart';
import 'package:assistant/features/session/add_student_sheet.dart';
import 'package:assistant/features/session/finish_screen.dart';
import 'package:assistant/features/session/session_screen.dart';

import '../support/fakes.dart';

FakeRepository _repo() {
  final repo = FakeRepository(
    groups: [sampleGroup(), sampleGroup(id: 'g2', name: 'لغات تانية')],
    students: [
      sampleStudent('s1', 'أحمد علي', code: 'S1001'),
      sampleStudent('s2', 'منى محمود', code: 'S1002'),
      sampleStudent('s3', 'يوسف عادل', code: 'S1003'),
      sampleStudent('s9', 'كريم سمير', groupId: 'g2', code: 'S1009'),
    ],
    sessions: [sampleSession()],
  );
  repo.meta = const AppMeta(activeSessionId: 'x1');
  return repo;
}

Future<void> _pump(WidgetTester tester, FakeRepository repo, {Widget? screen}) async {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(testApp(screen ?? const SessionScreen(sessionId: 'x1'), overrides: testOverrides(repo: repo)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the roster with counters', (tester) async {
    await _pump(tester, _repo());
    expect(find.text('لغات أولى'), findsOneWidget);
    expect(find.text('أحمد علي'), findsOneWidget);
    expect(find.text('كريم سمير'), findsNothing); // other group
    expect(find.text('لسه'), findsWidgets);
  });

  testWidgets('marking a student present updates the counters and persists a record', (tester) async {
    final repo = _repo();
    await _pump(tester, repo);

    await tester.tap(find.text('أحمد علي'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(GestureDetector, 'حضر').last);
    await tester.pumpAndSettle();

    expect(repo.records['x1']!['s1']!.attendance, Attendance.present);
  });

  testWidgets('tapping the selected attendance again clears it and removes the record', (tester) async {
    final repo = _repo();
    await _pump(tester, repo);
    await tester.tap(find.text('أحمد علي'));
    await tester.pumpAndSettle();
    final present = find.widgetWithText(GestureDetector, 'حضر').last;
    await tester.tap(present);
    await tester.pumpAndSettle();
    await tester.tap(present);
    await tester.pumpAndSettle();
    expect(repo.records['x1']?['s1'], isNull);
  });

  testWidgets('"الكل حضر" marks only unmarked students and can be undone', (tester) async {
    final repo = _repo();
    repo.seedRecord('x1', const SessionRecord(studentId: 's2', sessionId: 'x1', attendance: Attendance.absent));
    await _pump(tester, repo);

    await tester.tap(find.text('الكل حضر'));
    await tester.pumpAndSettle();
    expect(repo.records['x1']!['s1']!.attendance, Attendance.present);
    expect(repo.records['x1']!['s3']!.attendance, Attendance.present);
    expect(repo.records['x1']!['s2']!.attendance, Attendance.absent);

    await tester.tap(find.textContaining('تراجع'));
    await tester.pumpAndSettle();
    expect(repo.records['x1']!['s1']?.attendance, isNull);
    expect(repo.records['x1']!['s2']!.attendance, Attendance.absent);
  });

  testWidgets('search filters the roster and offers to add a missing student', (tester) async {
    await _pump(tester, _repo());
    await tester.enterText(find.byType(TextField).at(1), 'يوسف');
    await tester.pumpAndSettle();
    expect(find.text('يوسف عادل'), findsOneWidget);
    expect(find.text('أحمد علي'), findsNothing);

    await tester.enterText(find.byType(TextField).at(1), 'غير موجود');
    await tester.pumpAndSettle();
    expect(find.text('مفيش طالب بالاسم أو الكود ده في المجموعة'), findsOneWidget);
    expect(find.text('ضيفه كتعويض أو طالب جديد'), findsOneWidget);
  });

  testWidgets('exam score above the maximum is flagged and not saved', (tester) async {
    final repo = _repo();
    await _pump(tester, repo);
    await tester.tap(find.text('أحمد علي'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(GestureDetector, 'حضر').last);
    await tester.pumpAndSettle();

    final exam = find.byType(TextField).first;
    await tester.enterText(exam, '25');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('الدرجة لازم تكون من 0 لـ 20'), findsOneWidget);
    expect(repo.records['x1']!['s1']!.examScore, isNull);

    await tester.enterText(exam, '17');
    await tester.pump(const Duration(seconds: 1));
    expect(repo.records['x1']!['s1']!.examScore, 17);
  });

  testWidgets('the new-student form stays disabled until it is valid', (tester) async {
    await _pump(tester, _repo());
    await tester.tap(find.text('إضافة طالب (تعويض أو جديد)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('طالب جديد'));
    await tester.pumpAndSettle();

    Finder addBtn() => find.text('إضافة للحصة');
    Future<void> type(int field, String text) async {
      final inSheet = find.descendant(of: find.byType(AddStudentSheet), matching: find.byType(TextField));
      await tester.enterText(inSheet.at(field), text);
      await tester.pumpAndSettle();
    }

    expect(find.textContaining('كود الطالب هيتولّد تلقائي: N-'), findsOneWidget);
    await type(0, 'سلمى حسن');
    await type(1, '0101234');
    expect(find.text('لازم 11 رقم بيبدأ بـ 01 (7 من 11)'), findsOneWidget);
    await type(1, '٠١٠١٢٣٤٥٦٧٨');
    await type(2, '01112345678');
    expect(find.text('الرقم تمام'), findsNWidgets(2));

    // Payment not confirmed yet -> still disabled.
    await tester.tap(addBtn());
    await tester.pumpAndSettle();
    expect(find.text('طالب جديد'), findsWidgets);

    await tester.tap(find.text('لسه ما دفعش'));
    await tester.pumpAndSettle();
    await tester.tap(addBtn());
    await tester.pumpAndSettle();

    expect(find.text('سلمى حسن'), findsOneWidget);
    expect(find.text('طالب جديد · لسه ما دفعش'), findsOneWidget);
  });

  testWidgets('finishing writes one atomic plan with the new student', (tester) async {
    final repo = _repo();
    repo.seedRecord(
      'x1',
      const SessionRecord(
        studentId: 'n1',
        sessionId: 'x1',
        attendance: Attendance.present,
        kind: RecordKind.newStudent,
        newStudent: NewStudentDraft(
          studentId: 'n1',
          name: 'سلمى حسن',
          phone: '01012345678',
          parentPhone: '01112345678',
          code: 'N-ABCD',
          pay: NewStudentPay.month,
          amountEgp: 700,
        ),
      ),
    );
    await _pump(tester, repo, screen: const FinishScreen(sessionId: 'x1'));
    // Hydration of the controller happens after the first frame.
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'ملاحظة');
    await tester.tap(find.text('إنهاء وحفظ الحصة'));
    await tester.pumpAndSettle();

    expect(repo.finishCalls, 1);
    expect(repo.lastPlan!.session.status, SessionStatus.finished);
    expect(repo.lastPlan!.session.notes, 'ملاحظة');
    expect(repo.lastPlan!.newStudents.single.name, 'سلمى حسن');
    expect(repo.meta.activeSessionId, isNull);
    expect(find.text('اتحفظت الحصة'), findsOneWidget);
  });
}
