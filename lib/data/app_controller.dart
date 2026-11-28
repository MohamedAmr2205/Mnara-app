import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:assistant/core/security/pin_hasher.dart';
import 'package:assistant/core/util/date_utils.dart';
import 'package:assistant/core/util/text_utils.dart';
import 'package:assistant/data/seed.dart';
import 'package:assistant/domain/app_state.dart';
import 'package:assistant/domain/logic.dart';
import 'package:assistant/domain/models.dart';

/// Overridden in `main()` with the opened [SharedPreferences].
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider must be overridden'),
);

/// Clock used by the controller; overridden in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Whether the PIN gate is open for this app run (memory only).
final unlockedProvider = StateProvider<bool>((ref) => false);

/// The single app store.
final appProvider = NotifierProvider<AppController, AppState>(
  AppController.new,
);

/// Result of a PIN check.
class PinResult {
  /// Creates a result.
  const PinResult({
    required this.ok,
    required this.locked,
    required this.remaining,
  });

  /// PIN was correct.
  final bool ok;

  /// Too many wrong attempts; unlocking is blocked.
  final bool locked;

  /// Attempts left before the lock (0 when locked).
  final int remaining;
}

/// How a new student paid when added in a session.
enum NewStudentPay { session, month, none }

/// Local-only store: all data lives in [SharedPreferences] as one JSON blob.
class AppController extends Notifier<AppState> {
  static const String _key = 'mnara_state_v1';

  @override
  AppState build() {
    final prefs = ref.read(prefsProvider);
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        return AppState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // Corrupt blob: fall through to fresh demo data.
      }
    }
    final fresh = buildSeedState(ref.read(clockProvider)());
    unawaited(prefs.setString(_key, jsonEncode(fresh.toJson())));
    return fresh;
  }

  DateTime get _now => ref.read(clockProvider)();

  void _set(AppState next) {
    state = next;
    unawaited(
      ref.read(prefsProvider).setString(_key, jsonEncode(next.toJson())),
    );
  }

  // --------------------------------------------------------------------- PIN

  /// Whether a PIN has been chosen.
  bool get hasPin => state.pin != null;

  /// Whether the lock is engaged (too many wrong attempts).
  bool get isLocked => state.failedAttempts >= maxPinAttempts;

  /// Stores a new PIN and clears the failure counter.
  void setPin(String pin) {
    final salt = newSalt();
    _set(
      state.copyWith(
        pin: PinData(salt: salt, hash: hashPin(pin, salt)),
        failedAttempts: 0,
      ),
    );
  }

  /// Checks [pin] and updates the failure counter.
  PinResult verifyPin(String pin) {
    final data = state.pin;
    if (data == null) {
      return const PinResult(ok: false, locked: false, remaining: 0);
    }
    if (isLocked) {
      return const PinResult(ok: false, locked: true, remaining: 0);
    }
    if (hashesEqual(hashPin(pin, data.salt), data.hash)) {
      if (state.failedAttempts != 0) {
        _set(state.copyWith(failedAttempts: 0));
      }
      return const PinResult(ok: true, locked: false, remaining: 0);
    }
    final attempts = state.failedAttempts + 1;
    _set(state.copyWith(failedAttempts: attempts));
    final left = maxPinAttempts - attempts;
    return PinResult(
      ok: false,
      locked: left <= 0,
      remaining: left < 0 ? 0 : left,
    );
  }

  /// Demo-only way out of the lock: forgets the PIN so a new one is chosen.
  void resetLock() {
    _set(state.copyWith(pin: null, failedAttempts: 0));
  }

  // ------------------------------------------------------------------ groups

  /// Replaces all data with fresh demo data (keeps PIN and preferences).
  void reloadDemoData() {
    _set(buildSeedState(_now, keep: state));
  }

  // ---------------------------------------------------------------- sessions

  /// Starts (or resumes) the open session of [groupId]; returns its id.
  String startSession(String groupId) {
    for (final x in state.sessions) {
      if (x.groupId == groupId && x.status == SessionStatus.open) {
        _set(state.copyWith(activeSessionId: x.id));
        return x.id;
      }
    }
    final slot = nextSessionSlot(state, groupId);
    final roster = studentsOfGroup(state, groupId);
    final session = Session(
      id: newId('x'),
      groupId: groupId,
      date: dateKey(_now),
      number: slot.number,
      month: slot.month,
      status: SessionStatus.open,
      order: roster.map((e) => e.id).toList(),
      records: const {},
      createdAtMs: _now.millisecondsSinceEpoch,
    );
    _set(
      state.copyWith(
        sessions: [...state.sessions, session],
        activeSessionId: session.id,
      ),
    );
    return session.id;
  }

  void _updateSession(String xid, Session Function(Session) change) {
    final list = state.sessions.map((x) {
      if (x.id != xid) return x;
      var next = change(x);
      // Editing a saved session makes it pending again.
      if (x.status == SessionStatus.closed) {
        next = next.copyWith(syncedAt: null);
      }
      return next;
    }).toList();
    _set(state.copyWith(sessions: list));
  }

  void _updateRecord(
    String xid,
    String studentId,
    SessionRecord Function(SessionRecord) change,
  ) {
    _updateSession(xid, (x) {
      final records = Map<String, SessionRecord>.from(x.records);
      records[studentId] = change(x.recordOf(studentId));
      return x.copyWith(records: records);
    });
  }

  /// Sets attendance; tapping the selected value clears it.
  void setAttendance(String xid, String studentId, Attendance value) {
    _updateRecord(xid, studentId, (r) {
      final next = r.attendance == value ? null : value;
      final attended = next?.attended ?? false;
      return r.copyWith(
        attendance: next,
        homework: attended ? r.homework : null,
        exam: attended ? r.exam : null,
      );
    });
  }

  /// Sets homework; tapping the selected value clears it.
  void setHomework(String xid, String studentId, Homework value) {
    _updateRecord(
      xid,
      studentId,
      (r) => r.copyWith(homework: r.homework == value ? null : value),
    );
  }

  /// Sets or clears (null) the exam score.
  void setExam(String xid, String studentId, double? value) {
    _updateRecord(xid, studentId, (r) => r.copyWith(exam: value));
  }

  /// Sets the per-student note.
  void setStudentNote(String xid, String studentId, String note) {
    _updateRecord(xid, studentId, (r) => r.copyWith(note: note));
  }

  /// Toggles "no exam" for the session.
  void setNoExam(String xid, bool value) {
    _updateSession(xid, (x) {
      if (!value) return x.copyWith(noExam: false);
      // Dropping the exam also drops entered scores.
      final records = x.records.map(
        (k, v) => MapEntry(k, v.copyWith(exam: null)),
      );
      return x.copyWith(noExam: true, records: records);
    });
  }

  /// Sets the maximum exam score.
  void setExamMax(String xid, int max) {
    _updateSession(xid, (x) => x.copyWith(examMax: max));
  }

  /// Marks every not-yet-marked student present; returns the ids changed.
  List<String> markAllPresent(String xid) {
    final x = sessionById(state, xid);
    if (x == null) return const [];
    final changed = <String>[];
    final records = Map<String, SessionRecord>.from(x.records);
    for (final id in x.order) {
      final r = x.recordOf(id);
      if (r.attendance == null) {
        records[id] = r.copyWith(attendance: Attendance.present);
        changed.add(id);
      }
    }
    if (changed.isNotEmpty) {
      _updateSession(xid, (s) => s.copyWith(records: records));
    }
    return changed;
  }

  /// Reverts [markAllPresent] for [ids].
  void undoMarkAll(String xid, List<String> ids) {
    _updateSession(xid, (x) {
      final records = Map<String, SessionRecord>.from(x.records);
      for (final id in ids) {
        records[id] = x.recordOf(id).copyWith(attendance: null);
      }
      return x.copyWith(records: records);
    });
  }

  /// Adds a make-up student (from another group) at the top of the list.
  ///
  /// Returns false when the student is already in the session.
  bool addCompensation(
    String xid,
    String studentId, {
    String? forSessionId,
  }) {
    final x = sessionById(state, xid);
    final st = studentById(state, studentId);
    if (x == null || st == null || x.order.contains(studentId)) return false;
    final String tag;
    final target = forSessionId == null
        ? null
        : sessionById(state, forSessionId);
    if (target != null) {
      tag = 'تعويض عن حصة ${target.number} · شهر ${target.month}';
    } else {
      final g = groupById(state, st.groupId);
      tag = 'تعويض · ${g?.name ?? ''}';
    }
    _updateSession(xid, (s) {
      final records = Map<String, SessionRecord>.from(s.records);
      records[studentId] = SessionRecord(
        attendance: Attendance.present,
        tag: tag,
        tagTone: TagTone.amber,
        compensationFor: target?.id,
      );
      return s.copyWith(order: [studentId, ...s.order], records: records);
    });
    return true;
  }

  String _tempCode() {
    const alphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final rng = math.Random();
    while (true) {
      final code =
          'N-${List<String>.generate(4, (_) => alphabet[rng.nextInt(36)]).join()}';
      if (!state.students.any((s) => s.code == code)) return code;
    }
  }

  /// Adds a brand-new student to the session (temporary code), optionally
  /// with a payment, in one state change. Returns the new student.
  Student addNewStudent(
    String xid, {
    required String name,
    required String studentPhone,
    required String parentPhone,
    required NewStudentPay pay,
    int amount = 0,
    PayMethod? method,
  }) {
    final x = sessionById(state, xid)!;
    final student = Student(
      id: newId('s'),
      code: _tempCode(),
      name: name.trim(),
      studentPhone: studentPhone,
      parentPhone: parentPhone,
      groupId: x.groupId,
      tempCode: true,
    );
    final paid = pay != NewStudentPay.none && amount > 0;
    final kind = pay == NewStudentPay.session ? 'حصة' : 'شهر';
    final record = SessionRecord(
      attendance: Attendance.present,
      isNew: true,
      tag: paid
          ? 'طالب جديد · دفع $amount ج ($kind)'
          : 'طالب جديد · لسه ما دفعش',
      tagTone: paid ? TagTone.mint : TagTone.amber,
    );
    final sessions = state.sessions.map((s) {
      if (s.id != xid) return s;
      final records = Map<String, SessionRecord>.from(s.records)
        ..[student.id] = record;
      return s.copyWith(order: [student.id, ...s.order], records: records);
    }).toList();
    final payments = [...state.payments];
    if (paid) {
      payments.add(
        Payment(
          id: newId('p'),
          studentId: student.id,
          month: x.month,
          amount: amount,
          method: method ?? PayMethod.cash,
          date: dateKey(_now),
          createdAtMs: _now.millisecondsSinceEpoch,
        ),
      );
    }
    _set(
      state.copyWith(
        students: [...state.students, student],
        sessions: sessions,
        payments: payments,
      ),
    );
    return student;
  }

  /// Saves the session: closes it, stores [notes] and clears the resume flag.
  void finishSession(String xid, String notes) {
    var next = state.copyWith(
      sessions: state.sessions.map((x) {
        if (x.id != xid) return x;
        return x.copyWith(
          status: SessionStatus.closed,
          notes: notes.trim(),
          syncedAt: null,
        );
      }).toList(),
      activeSessionId: state.activeSessionId == xid
          ? null
          : state.activeSessionId,
    );
    if (next.online && next.autoUpload) next = _upload(next);
    _set(next);
  }

  /// Deletes an open session with the students/payments created inside it.
  void cancelSession(String xid) {
    final x = sessionById(state, xid);
    if (x == null) return;
    final newIds = <String>{
      for (final e in x.records.entries)
        if (e.value.isNew) e.key,
    };
    _set(
      state.copyWith(
        sessions: state.sessions.where((s) => s.id != xid).toList(),
        students: state.students.where((s) => !newIds.contains(s.id)).toList(),
        payments: state.payments
            .where((p) => !newIds.contains(p.studentId))
            .toList(),
        activeSessionId: state.activeSessionId == xid
            ? null
            : state.activeSessionId,
      ),
    );
  }

  // ---------------------------------------------------------------- payments

  /// Records a payment for [month]; amount is a positive whole EGP value.
  void addPayment({
    required String studentId,
    required int month,
    required int amount,
    required PayMethod method,
    required DateTime date,
  }) {
    final p = Payment(
      id: newId('p'),
      studentId: studentId,
      month: month,
      amount: amount,
      method: method,
      date: dateKey(date),
      createdAtMs: _now.millisecondsSinceEpoch,
    );
    var next = state.copyWith(payments: [...state.payments, p]);
    if (next.online && next.autoUpload) next = _upload(next);
    _set(next);
  }

  // ------------------------------------------------------------------ search

  /// Remembers a student in the recent-search chips.
  void addRecent(String studentId) {
    final list = [
      studentId,
      ...state.recentStudentIds.where((e) => e != studentId),
    ].take(8).toList();
    _set(state.copyWith(recentStudentIds: list));
  }

  // -------------------------------------------------------------------- sync

  /// Simulated connectivity switch (debug only in the UI).
  void setOnline(bool value) {
    var next = state.copyWith(online: value);
    if (value && next.autoUpload) next = _upload(next);
    _set(next);
  }

  /// Toggles automatic upload.
  void setAutoUpload(bool value) {
    var next = state.copyWith(autoUpload: value);
    if (value && next.online) next = _upload(next);
    _set(next);
  }

  /// Uploads everything pending (local mode: marks items as synced and turns
  /// temporary student codes into permanent ones).
  void uploadAll() {
    if (!state.online) return;
    _set(_upload(state));
  }

  AppState _upload(AppState s) {
    final now = _now.millisecondsSinceEpoch;
    final inOpenSession = <String>{
      for (final x in s.sessions)
        if (x.status == SessionStatus.open)
          for (final e in x.records.entries)
            if (e.value.isNew) e.key,
    };
    var counter = s.studentCounter;
    final students = s.students.map((st) {
      if (!st.tempCode || inOpenSession.contains(st.id)) return st;
      counter++;
      return st.copyWith(code: 'S$counter', tempCode: false, syncedAt: now);
    }).toList();
    final sessions = s.sessions.map((x) {
      if (x.status == SessionStatus.closed && x.syncedAt == null) {
        return x.copyWith(syncedAt: now);
      }
      return x;
    }).toList();
    final payments = s.payments
        .map((p) => p.syncedAt == null ? p.withSyncedAt(now) : p)
        .toList();
    return s.copyWith(
      students: students,
      sessions: sessions,
      payments: payments,
      studentCounter: counter,
      lastUploadAtMs: now,
    );
  }
}
