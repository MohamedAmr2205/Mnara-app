// ignore_for_file: always_use_package_imports
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:assistant/data/app_controller.dart';
import 'package:assistant/domain/logic.dart';
import 'package:assistant/domain/models.dart';

import '../helpers.dart';

void main() {
  group('sessions', () {
    test('startSession opens session 3 of month 2 with the roster', () async {
      final (c, _) = await makeContainer();
      addTearDown(c.dispose);
      final ctl = c.read(appProvider.notifier);
      final gid = c.read(appProvider).groups.first.id;

      final xid = ctl.startSession(gid);
      final s = c.read(appProvider);
      final x = sessionById(s, xid)!;

      expect(x.status, SessionStatus.open);
      expect((x.number, x.month), (3, 2));
      expect(x.order.length, 12);
      expect(s.activeSessionId, xid);
    });

    test('startSession twice resumes the same open session', () async {
      final (c, _) = await makeContainer();
      addTearDown(c.dispose);
      final ctl = c.read(appProvider.notifier);
      final gid = c.read(appProvider).groups.first.id;

      final a = ctl.startSession(gid);
      final b = ctl.startSession(gid);
      expect(a, b);
      expect(c.read(appProvider).sessions.where((x) => x.id == a).length, 1);
    });

    test('attendance toggles and clears homework/exam when absent', () async {
      final (c, _) = await makeContainer();
      addTearDown(c.dispose);
      final ctl = c.read(appProvider.notifier);
      final xid = ctl.startSession(c.read(appProvider).groups.first.id);
      final sid = sessionById(c.read(appProvider), xid)!.order.first;

      ctl.setAttendance(xid, sid, Attendance.present);
      ctl.setHomework(xid, sid, Homework.good);
      ctl.setExam(xid, sid, 15.5);
      var r = sessionById(c.read(appProvider), xid)!.recordOf(sid);
      expect(r.attendance, Attendance.present);
      expect(r.homework, Homework.good);
      expect(r.exam, 15.5);

      ctl.setAttendance(xid, sid, Attendance.absent);
      r = sessionById(c.read(appProvider), xid)!.recordOf(sid);
      expect(r.attendance, Attendance.absent);
      expect(r.homework, isNull);
      expect(r.exam, isNull);

      // Tapping the selected value clears it.
      ctl.setAttendance(xid, sid, Attendance.absent);
      r = sessionById(c.read(appProvider), xid)!.recordOf(sid);
      expect(r.attendance, isNull);
    });

    test('markAllPresent only touches unmarked students and undoes', () async {
      final (c, _) = await makeContainer();
      addTearDown(c.dispose);
      final ctl = c.read(appProvider.notifier);
      final xid = ctl.startSession(c.read(appProvider).groups.first.id);
      final order = sessionById(c.read(appProvider), xid)!.order;
      ctl.setAttendance(xid, order.first, Attendance.absent);

      final changed = ctl.markAllPresent(xid);
      expect(changed.length, order.length - 1);
      var x = sessionById(c.read(appProvider), xid)!;
      expect(x.recordOf(order.first).attendance, Attendance.absent);
      expect(countsOf(x).unmarked, 0);

      ctl.undoMarkAll(xid, changed);
      x = sessionById(c.read(appProvider), xid)!;
      expect(countsOf(x).unmarked, order.length - 1);
      expect(x.recordOf(order.first).attendance, Attendance.absent);
    });

    test('noExam drops entered scores', () async {
      final (c, _) = await makeContainer();
      addTearDown(c.dispose);
      final ctl = c.read(appProvider.notifier);
      final xid = ctl.startSession(c.read(appProvider).groups.first.id);
      final sid = sessionById(c.read(appProvider), xid)!.order.first;
      ctl.setAttendance(xid, sid, Attendance.present);
      ctl.setExam(xid, sid, 12);
      ctl.setNoExam(xid, true);
      final x = sessionById(c.read(appProvider), xid)!;
      expect(x.noExam, isTrue);
      expect(x.recordOf(sid).exam, isNull);
    });
  });

  group('make-up and new students', () {
    test('compensation links to an absence once', () async {
      final (c, _) = await makeContainer();
      addTearDown(c.dispose);
      final ctl = c.read(appProvider.notifier);
      final s0 = c.read(appProvider);
      final g1 = s0.groups.first.id;

      // A student from another group with an uncovered absence.
      final other = s0.students.firstWhere(
        (st) => st.groupId != g1 && missedSessions(s0, st.id).isNotEmpty,
      );
      final missed = missedSessions(s0, other.id).first;

      final xid = ctl.startSession(g1);
      expect(
        ctl.addCompensation(xid, other.id, forSessionId: missed.session.id),
        isTrue,
      );
      final x = sessionById(c.read(appProvider), xid)!;
      expect(x.order.first, other.id);
      expect(x.recordOf(other.id).attendance, Attendance.present);
      expect(x.recordOf(other.id).compensationFor, missed.session.id);
      expect(x.recordOf(other.id).tag, contains('تعويض عن حصة'));

      // Adding the same student again is refused.
      expect(ctl.addCompensation(xid, other.id), isFalse);
    });

    test('new student gets a temp code and a payment', () async {
      final (c, _) = await makeContainer();
      addTearDown(c.dispose);
      final ctl = c.read(appProvider.notifier);
      final g1 = c.read(appProvider).groups.first.id;
      final xid = ctl.startSession(g1);

      final st = ctl.addNewStudent(
        xid,
        name: 'طالب تجريبي',
        studentPhone: '01012345678',
        parentPhone: '01112345678',
        pay: NewStudentPay.month,
        amount: 700,
        method: PayMethod.instapay,
      );
      final s = c.read(appProvider);
      expect(st.tempCode, isTrue);
      expect(st.code, startsWith('N-'));
      expect(st.groupId, g1);
      expect(sessionById(s, xid)!.order.first, st.id);
      expect(sessionById(s, xid)!.recordOf(st.id).isNew, isTrue);
      expect(paidFor(s, st.id, 2), 700);
    });

    test('cancelSession removes new students and their payments', () async {
      final (c, _) = await makeContainer();
      addTearDown(c.dispose);
      final ctl = c.read(appProvider.notifier);
      final before = c.read(appProvider);
      final xid = ctl.startSession(before.groups.first.id);
      ctl.addNewStudent(
        xid,
        name: 'مؤقت',
        studentPhone: '01012345678',
        parentPhone: '01112345678',
        pay: NewStudentPay.session,
        amount: 175,
      );
      ctl.cancelSession(xid);
      final after = c.read(appProvider);
      expect(after.sessions.length, before.sessions.length);
      expect(after.students.length, before.students.length);
      expect(after.payments.length, before.payments.length);
      expect(after.activeSessionId, isNull);
    });
  });

  group('finishing and sync', () {
    test('finishing while offline keeps everything pending', () async {
      final (c, _) = await makeContainer();
      addTearDown(c.dispose);
      final ctl = c.read(appProvider.notifier);
      ctl.setOnline(false);
      final xid = ctl.startSession(c.read(appProvider).groups.first.id);
      final st = ctl.addNewStudent(
        xid,
        name: 'طالب',
        studentPhone: '01012345678',
        parentPhone: '01112345678',
        pay: NewStudentPay.none,
      );
      ctl.finishSession(xid, 'ملاحظة');

      var s = c.read(appProvider);
      final x = sessionById(s, xid)!;
      expect(x.status, SessionStatus.closed);
      expect(x.notes, 'ملاحظة');
      expect(x.syncedAt, isNull);
      expect(s.activeSessionId, isNull);
      expect(pendingCount(s), greaterThanOrEqualTo(2)); // session + student
      expect(studentById(s, st.id)!.tempCode, isTrue);

      // Back online: auto-upload converts the temp code and clears pending.
      ctl.setOnline(true);
      s = c.read(appProvider);
      expect(pendingCount(s), 0);
      final uploaded = studentById(s, st.id)!;
      expect(uploaded.tempCode, isFalse);
      expect(uploaded.code, 'S1001');
    });

    test('with auto-upload off nothing uploads until asked', () async {
      final (c, _) = await makeContainer();
      addTearDown(c.dispose);
      final ctl = c.read(appProvider.notifier);
      ctl.setAutoUpload(false);
      final xid = ctl.startSession(c.read(appProvider).groups.first.id);
      ctl.finishSession(xid, '');
      expect(pendingCount(c.read(appProvider)), 1);
      ctl.uploadAll();
      expect(pendingCount(c.read(appProvider)), 0);
    });

    test('uploadAll does nothing while offline', () async {
      final (c, _) = await makeContainer();
      addTearDown(c.dispose);
      final ctl = c.read(appProvider.notifier);
      ctl.setAutoUpload(false);
      ctl.setOnline(false);
      final xid = ctl.startSession(c.read(appProvider).groups.first.id);
      ctl.finishSession(xid, '');
      ctl.uploadAll();
      expect(pendingCount(c.read(appProvider)), 1);
    });

    test('editing a saved session makes it pending again', () async {
      final (c, _) = await makeContainer();
      addTearDown(c.dispose);
      final ctl = c.read(appProvider.notifier);
      final s0 = c.read(appProvider);
      final x0 = s0.sessions.first;
      expect(x0.syncedAt, isNotNull);
      ctl.setAutoUpload(false);
      final sid = x0.order.first;
      ctl.setAttendance(x0.id, sid, Attendance.late);
      expect(sessionById(c.read(appProvider), x0.id)!.syncedAt, isNull);
    });
  });

  group('payments', () {
    test('addPayment adds up and completes the month', () async {
      final (c, _) = await makeContainer();
      addTearDown(c.dispose);
      final ctl = c.read(appProvider.notifier);
      final s0 = c.read(appProvider);
      final st = s0.students.firstWhere(
        (x) => paidFor(s0, x.id, 3) == 0,
      );
      ctl.addPayment(
        studentId: st.id,
        month: 3,
        amount: 400,
        method: PayMethod.cash,
        date: testNow,
      );
      expect(remainingFor(c.read(appProvider), st.id, 3), 300);
      ctl.addPayment(
        studentId: st.id,
        month: 3,
        amount: 300,
        method: PayMethod.vodafoneCash,
        date: testNow,
      );
      expect(remainingFor(c.read(appProvider), st.id, 3), 0);
    });
  });

  group('PIN', () {
    test('setPin then verify; wrong PIN counts attempts; locks at 10', () async {
      final (c, _) = await makeContainer();
      addTearDown(c.dispose);
      final ctl = c.read(appProvider.notifier);
      expect(ctl.hasPin, isFalse);

      ctl.setPin('2580');
      expect(ctl.hasPin, isTrue);
      expect(ctl.verifyPin('2580').ok, isTrue);

      final first = ctl.verifyPin('1111');
      expect(first.ok, isFalse);
      expect(first.remaining, 9);

      for (var i = 0; i < 8; i++) {
        ctl.verifyPin('1111');
      }
      final last = ctl.verifyPin('1111');
      expect(last.locked, isTrue);
      expect(last.remaining, 0);

      // Even the right PIN is refused while locked.
      expect(ctl.verifyPin('2580').ok, isFalse);
      expect(ctl.verifyPin('2580').locked, isTrue);

      ctl.resetLock();
      expect(ctl.hasPin, isFalse);
      expect(c.read(appProvider).failedAttempts, 0);
    });

    test('a correct PIN resets the failure counter', () async {
      final (c, _) = await makeContainer();
      addTearDown(c.dispose);
      final ctl = c.read(appProvider.notifier);
      ctl.setPin('2580');
      ctl.verifyPin('0000');
      ctl.verifyPin('0000');
      expect(c.read(appProvider).failedAttempts, 2);
      expect(ctl.verifyPin('2580').ok, isTrue);
      expect(c.read(appProvider).failedAttempts, 0);
    });

    test('the PIN is not stored in clear text', () async {
      final (c, prefs) = await makeContainer();
      addTearDown(c.dispose);
      c.read(appProvider.notifier).setPin('2580');
      final raw = prefs.getString('mnara_state_v1')!;
      final pin =
          (jsonDecode(raw) as Map<String, dynamic>)['pin'] as Map<String, dynamic>;
      expect(pin.keys.toSet(), {'salt', 'hash'});
      expect(pin['hash'], isNot('2580'));
      expect((pin['hash'] as String).length, 64);
    });
  });

  group('persistence', () {
    test('state is restored after a restart', () async {
      final (c1, prefs) = await makeContainer();
      final ctl = c1.read(appProvider.notifier);
      final gid = c1.read(appProvider).groups.first.id;
      final xid = ctl.startSession(gid);
      final sid = sessionById(c1.read(appProvider), xid)!.order.first;
      ctl.setAttendance(xid, sid, Attendance.late);
      ctl.setPin('2580');
      c1.dispose();

      final (c2, _) = await makeContainer(prefs: prefs);
      addTearDown(c2.dispose);
      final s = c2.read(appProvider);
      expect(s.activeSessionId, xid);
      expect(
        sessionById(s, xid)!.recordOf(sid).attendance,
        Attendance.late,
      );
      expect(c2.read(appProvider.notifier).verifyPin('2580').ok, isTrue);
    });
  });
}
