import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:assistant/core/sync/write_service.dart';
import 'package:assistant/data/models/enums.dart';
import 'package:assistant/data/models/models.dart';
import 'package:assistant/data/providers.dart';
import 'package:assistant/domain/session_logic.dart';
import 'package:assistant/features/shared/derived.dart';

/// UI state of the session screen.
class SessionUiState {
  /// Creates the state.
  const SessionUiState({
    this.records = const {},
    this.extras = const [],
    this.openId,
    this.query = '',
    this.maxExam = 20,
    this.noExam = false,
    this.hydrated = false,
    this.undoIds = const [],
  });

  /// Local copy of every row's data, keyed by student id.
  final Map<String, SessionRecord> records;

  /// Student ids shown above the roster (makeup and new students).
  final List<String> extras;

  /// Id of the expanded row, if any.
  final String? openId;

  /// Search text.
  final String query;

  /// Maximum exam score.
  final int maxExam;

  /// Session has no exam.
  final bool noExam;

  /// Whether stored data has been loaded into [records].
  final bool hydrated;

  /// Rows marked by the last "mark all present" (for undo).
  final List<String> undoIds;

  /// Copy with changes.
  SessionUiState copyWith({
    Map<String, SessionRecord>? records,
    List<String>? extras,
    String? openId,
    bool clearOpen = false,
    String? query,
    int? maxExam,
    bool? noExam,
    bool? hydrated,
    List<String>? undoIds,
  }) {
    return SessionUiState(
      records: records ?? this.records,
      extras: extras ?? this.extras,
      openId: clearOpen ? null : (openId ?? this.openId),
      query: query ?? this.query,
      maxExam: maxExam ?? this.maxExam,
      noExam: noExam ?? this.noExam,
      hydrated: hydrated ?? this.hydrated,
      undoIds: undoIds ?? this.undoIds,
    );
  }
}

/// Controller of one session. Local state is the source of truth while the
/// screen is open; every change is written through to the repository (and so
/// to the on-device Firestore cache) right away, which is what makes Resume work.
class SessionController extends FamilyNotifier<SessionUiState, String> {
  final Map<String, Timer> _timers = {};
  late final WriteService _writes;
  String _title = '';

  @override
  SessionUiState build(String arg) {
    _writes = ref.read(writeServiceProvider);
    ref.onDispose(() {
      for (final t in _timers.values) {
        t.cancel();
      }
    });
    final session = ref.read(sessionMapProvider)[arg];
    ref.listen<AsyncValue<List<SessionRecord>>>(sessionRecordsProvider(arg), (
      previous,
      next,
    ) {
      final list = next.valueOrNull;
      if (list != null) _hydrate(list);
    });
    Future<void>.microtask(() {
      final stored = ref.read(sessionRecordsProvider(arg)).valueOrNull;
      if (stored != null) _hydrate(stored);
    });
    if (session != null) {
      _title = session.label.split(' · ').first;
      return SessionUiState(
        maxExam: session.maxExam ?? 20,
        noExam: session.noExam,
      );
    }
    return const SessionUiState();
  }

  void _hydrate(List<SessionRecord> stored) {
    if (state.hydrated) return;
    final map = {for (final r in stored) r.studentId: r};
    final extras = [
      for (final r in stored)
        if (r.kind != RecordKind.regular) r.studentId,
    ];
    state = state.copyWith(records: map, extras: extras, hydrated: true);
  }

  Session? get _session => ref.read(sessionMapProvider)[arg];

  void _persist(String studentId) {
    _timers.remove(studentId)?.cancel();
    final r = state.records[studentId];
    if (r == null) return;
    if (r.attendance == null) {
      _writes.deleteRecord(arg, studentId);
    } else {
      _writes.saveRecord(arg, r, title: _title);
    }
  }

  void _debounced(String studentId) {
    _timers[studentId]?.cancel();
    _timers[studentId] = Timer(
      const Duration(milliseconds: 600),
      () => _persist(studentId),
    );
  }

  void _put(SessionRecord r, {bool debounce = false}) {
    state = state.copyWith(records: {...state.records, r.studentId: r});
    if (debounce) {
      _debounced(r.studentId);
    } else {
      _persist(r.studentId);
    }
  }

  SessionRecord _recordFor(String studentId) =>
      state.records[studentId] ??
      SessionRecord(studentId: studentId, sessionId: arg);

  /// Expands [id] (null collapses).
  void open(String? id) {
    if (state.openId != null && state.openId != id) _flush(state.openId!);
    state = id == null ? state.copyWith(clearOpen: true) : state.copyWith(openId: id);
  }

  void _flush(String id) {
    if (_timers.containsKey(id)) _persist(id);
  }

  /// Sets the search text.
  void setQuery(String q) => state = state.copyWith(query: q);

  /// Sets (or clears, when the same value is tapped again) the attendance.
  void setAttendance(String studentId, Attendance? a) {
    final cur = _recordFor(studentId);
    final cleared = a == null || cur.attendance == a;
    var next = cleared
        ? cur.copyWith(clearAttendance: true, clearHomework: true, clearExam: true)
        : cur.copyWith(attendance: a);
    if (!cleared && !a.attended) {
      next = next.copyWith(clearHomework: true, clearExam: true);
    }
    _put(next);
  }

  /// Sets the homework grade (tap the same grade to clear).
  void setHomework(String studentId, Homework h) {
    final cur = _recordFor(studentId);
    _put(
      cur.homework == h ? cur.copyWith(clearHomework: true) : cur.copyWith(homework: h),
    );
  }

  /// Sets the exam score (null clears).
  void setExam(String studentId, num? score) {
    final cur = _recordFor(studentId);
    _put(
      score == null ? cur.copyWith(clearExam: true) : cur.copyWith(examScore: score),
      debounce: true,
    );
  }

  /// Sets the per-student note.
  void setNote(String studentId, String note) {
    _put(_recordFor(studentId).copyWith(note: note), debounce: true);
  }

  /// Marks every unmarked row present and remembers which ones for undo.
  void markAllPresent(List<String> rosterIds) {
    final marked = <String>[];
    final next = {...state.records};
    for (final id in rosterIds) {
      final cur = next[id] ?? SessionRecord(studentId: id, sessionId: arg);
      if (cur.attendance == null) {
        next[id] = cur.copyWith(attendance: Attendance.present);
        marked.add(id);
      }
    }
    state = state.copyWith(records: next, undoIds: marked);
    for (final id in marked) {
      _persist(id);
    }
  }

  /// Reverts the last "mark all present".
  void undoMarkAll() {
    final next = {...state.records};
    for (final id in state.undoIds) {
      final cur = next[id];
      if (cur != null) {
        next[id] = cur.copyWith(clearAttendance: true);
      }
    }
    final ids = state.undoIds;
    state = state.copyWith(records: next, undoIds: const []);
    for (final id in ids) {
      _persist(id);
    }
  }

  /// Adds a makeup student (optionally linked to a missed session).
  void addMakeup(Student student, MissedSession? missed) {
    final record = SessionRecord(
      studentId: student.id,
      sessionId: arg,
      attendance: Attendance.present,
      kind: RecordKind.makeup,
      makeupForSessionId: missed?.sessionId,
      makeupForNumber: missed?.number,
      makeupForMonth: missed?.month,
    );
    state = state.copyWith(
      records: {...state.records, student.id: record},
      extras: [student.id, ...state.extras.where((e) => e != student.id)],
      openId: student.id,
    );
    _persist(student.id);
  }

  /// Adds a brand-new student (created for real when the session finishes).
  void addNewStudent(NewStudentDraft draft) {
    final record = SessionRecord(
      studentId: draft.studentId,
      sessionId: arg,
      attendance: Attendance.present,
      kind: RecordKind.newStudent,
      newStudent: draft,
    );
    state = state.copyWith(
      records: {...state.records, draft.studentId: record},
      extras: [draft.studentId, ...state.extras],
      openId: draft.studentId,
    );
    _persist(draft.studentId);
  }

  /// Sets the maximum exam score.
  void setMaxExam(int value) {
    state = state.copyWith(maxExam: value);
    _saveSettings();
  }

  /// Toggles "no exam".
  void toggleNoExam() {
    state = state.copyWith(noExam: !state.noExam);
    _saveSettings();
  }

  void _saveSettings() {
    final s = _session;
    if (s == null) return;
    ref
        .read(dataRepositoryProvider)
        .updateSessionDraft(s.copyWith(maxExam: state.maxExam, noExam: state.noExam))
        .catchError((Object _) {});
  }

  /// Writes any debounced changes now (called before leaving the screen).
  void flushAll() {
    for (final id in _timers.keys.toList()) {
      _persist(id);
    }
  }
}

/// Session controller.
final sessionControllerProvider =
    NotifierProvider.family<SessionController, SessionUiState, String>(
      SessionController.new,
    );
