// Repository for WorkoutSession persistence.
// Fast path: Hive (sessionBox) for quick access to ongoing + last sessions.
// Durability: SQLite mirror (fire-and-forget writes) via AppDatabase helpers.
// No UI manipulation here; consumers can poll or listen via a future Cubit.

import 'dart:async';
import 'package:hive/hive.dart';

import '../../../core/models/workout_session.dart';
import '../../../core/models/exercise_set.dart';
import '../../../core/db/app_database.dart';
import '../../../core/utils/logger.dart';
import '../../../core/models/session_runtime.dart';
import '../../../core/db/session_index.dart';

class WorkoutSessionRepository {
  WorkoutSessionRepository();

  Box<WorkoutSession> get _box => Hive.box<WorkoutSession>('sessionBox');
  Box<ExerciseSet> get _setBox => Hive.box<ExerciseSet>('exerciseSetBox');

  Future<WorkoutSession> startSession({required String workoutId}) async {
    // Enforce single ongoing session policy.
    final existing = getOngoingSessionSync();
    if (existing != null) {
      // Option: auto-complete existing. For now mark completed to avoid orphan state.
      final idx = _box.values.toList().indexOf(existing);
      if (idx != -1) {
        final updated = existing.copyWith(completed: true);
        await _box.putAt(idx, updated);
      }
    }
    final session = WorkoutSession(
      workoutId: workoutId,
      date: DateTime.now(),
      durationSeconds: 0,
      progress: const [],
      completed: false,
    );
    await _box.add(session);
    // Update index: mark ongoing
    unawaited(
      SessionIndex.onOngoingChanged(workoutId: workoutId, isOngoing: true),
    );
    // Mirror to SQLite (ignore errors for now)
    unawaited(_mirrorInsert(session));
    return session;
  }

  Future<void> _mirrorInsert(WorkoutSession s) async {
    try {
      final id = await WorkoutSessionSqlHelpers.insertWorkoutSession(
        workoutId: s.workoutId,
        date: s.date,
      );
      // Persist the rowId mapping for reliable future updates
      await SessionIndex.setSessionRowId(workoutId: s.workoutId, rowId: id);
    } catch (e, st) {
      logError('Mirror insert workout_session failed: $e', st);
    }
  }

  WorkoutSession? getOngoingSessionSync() {
    final sessions = _box.values.where((s) => !s.completed).toList();
    if (sessions.isEmpty) return null;
    sessions.sort((a, b) => b.date.compareTo(a.date));
    return sessions.first;
  }

  WorkoutSession? getLastCompletedSessionSync() {
    final sessions = _box.values.where((s) => s.completed).toList();
    if (sessions.isEmpty) return null;
    sessions.sort((a, b) => b.date.compareTo(a.date));
    return sessions.first;
  }

  // getOngoingSession implemented below to backfill SQLite rowId mapping

  // Ensure we have a SQLite rowId mapping for a given session (best-effort, non-blocking call sites can unawait).
  Future<void> _ensureRowMapping(WorkoutSession s) async {
    try {
      if (SessionIndex.getSessionRowId(s.workoutId) != null) return;
      final row = await WorkoutSessionSqlHelpers.getSessionRowByWorkoutId(
        s.workoutId,
      );
      final id = row?['id'] as int?;
      if (id != null) {
        await SessionIndex.setSessionRowId(workoutId: s.workoutId, rowId: id);
      }
    } catch (_) {
      // best-effort; ignore
    }
  }

  Future<WorkoutSession?> getOngoingSession() async {
    final s = getOngoingSessionSync();
    if (s != null) {
      unawaited(_ensureRowMapping(s));
    }
    return s;
  }

  Future<WorkoutSession?> getLastCompletedSession() async =>
      getLastCompletedSessionSync();

  Future<WorkoutSession> updateDuration(
    String sessionId,
    int deltaSeconds,
  ) async {
    final idx = _findIndexBySessionId(sessionId);
    if (idx == -1) throw ArgumentError('Session not found');
    final s = _box.getAt(idx)!;
    final updated = s.copyWith(
      durationSeconds: s.durationSeconds + deltaSeconds,
    );
    await _box.putAt(idx, updated);
    // Index: if still ongoing, no daily accumulation yet; when completed we add final.
    // Optionally, you could keep a rolling daily tally, but to avoid double-count we wait for completion.
    // Mirror duration update (best-effort)
    unawaited(_mirrorUpdateDuration(updated));
    return updated;
  }

  Future<void> _mirrorUpdateDuration(WorkoutSession s) async {
    try {
      // Defensive: if runtime is paused, do not mirror duration updates
      try {
        final rt = Hive.box<SessionRuntime>(
          'sessionRuntimeBox',
        ).get(s.workoutId);
        if (rt?.paused == true) return;
      } catch (_) {}
      // Use mapped rowId first; fall back to lookup by workoutId
      int? rowId = SessionIndex.getSessionRowId(s.workoutId);
      if (rowId == null) {
        final row = await WorkoutSessionSqlHelpers.getSessionRowByWorkoutId(
          s.workoutId,
        );
        rowId = row?['id'] as int?;
        if (rowId != null) {
          await SessionIndex.setSessionRowId(
            workoutId: s.workoutId,
            rowId: rowId,
          );
        }
      }
      if (rowId != null) {
        await WorkoutSessionSqlHelpers.updateWorkoutSession(
          id: rowId,
          durationSeconds: s.durationSeconds,
        );
      }
    } catch (e, st) {
      logError('Mirror update duration failed: $e', st);
    }
  }

  Future<WorkoutSession> upsertExerciseProgress(
    String sessionId,
    ExerciseProgress progress,
  ) async {
    final idx = _findIndexBySessionId(sessionId);
    if (idx == -1) throw ArgumentError('Session not found');
    final s = _box.getAt(idx)!;
    final list = [...s.progress];
    final existingIdx = list.indexWhere(
      (p) => p.exerciseId == progress.exerciseId,
    );
    if (existingIdx == -1) {
      list.add(progress);
    } else {
      list[existingIdx] = progress;
    }
    final updated = s.copyWith(progress: list);
    await _box.putAt(idx, updated);
    // Mirror to SQLite (best-effort). We need session row id; approximate by ongoing or last completed.
    unawaited(_mirrorUpsertExercise(progress));
    return updated;
  }

  Future<void> _mirrorUpsertExercise(ExerciseProgress p) async {
    try {
      // Resolve current session row id by ongoing or mapping (prefer mapping)
      int? sessionId;
      // Try mapping by inspecting current ongoing from Hive
      final ongoing = getOngoingSessionSync();
      if (ongoing != null) {
        sessionId = SessionIndex.getSessionRowId(ongoing.workoutId);
        sessionId ??=
            (await WorkoutSessionSqlHelpers.getSessionRowByWorkoutId(
                  ongoing.workoutId,
                ))?['id']
                as int?;
      }
      sessionId ??=
          (await WorkoutSessionSqlHelpers.getOngoingSessionRow())?['id']
              as int?;
      if (sessionId == null) return; // can't map
      await WorkoutSessionSqlHelpers.upsertExerciseProgress(
        sessionId: sessionId,
        exerciseId: p.exerciseId,
        completedSets: p.completedSets,
        completedReps: p.completedReps,
        usedWeight: p.usedWeight,
        timeSpent: p.timeSpentSeconds,
      );
    } catch (e, st) {
      logError('Mirror upsert exercise failed: $e', st);
    }
  }

  Future<WorkoutSession> completeSession(String sessionId) async {
    final idx = _findIndexBySessionId(sessionId);
    if (idx == -1) throw ArgumentError('Session not found');
    final s = _box.getAt(idx)!;
    if (s.completed) return s;
    final updated = s.copyWith(completed: true);
    await _box.putAt(idx, updated);
    // Update index: mark not ongoing and add to daily bucket
    unawaited(
      SessionIndex.onOngoingChanged(workoutId: sessionId, isOngoing: false),
    );
    unawaited(SessionIndex.onSessionCompleted(updated));
    unawaited(_mirrorComplete(updated));
    return updated;
  }

  Future<void> _mirrorComplete(WorkoutSession s) async {
    try {
      int? rowId = SessionIndex.getSessionRowId(s.workoutId);
      rowId ??=
          (await WorkoutSessionSqlHelpers.getSessionRowByWorkoutId(
                s.workoutId,
              ))?['id']
              as int?;
      rowId ??=
          (await WorkoutSessionSqlHelpers.getOngoingSessionRow())?['id']
              as int?;
      if (rowId != null) {
        await WorkoutSessionSqlHelpers.updateWorkoutSession(
          id: rowId,
          completed: true,
          durationSeconds: s.durationSeconds,
        );
        // Once completed, mapping can be retained for history; no need to clear.
      }
    } catch (e, st) {
      logError('Mirror complete failed: $e', st);
    }
  }

  int _findIndexBySessionId(String id) {
    final values = _box.values.toList();
    for (var i = 0; i < values.length; i++) {
      if (values[i].workoutId == id) return i;
    }
    return -1;
  }

  // =============================
  // Per-Set APIs (Optional Layer)
  // =============================

  Future<ExerciseSet> addExerciseSet({
    required String sessionWorkoutId,
    required String exerciseId,
    required int setIndex,
    required int reps,
    required int weight,
    required int durationSeconds,
    DateTime? recordedAt,
  }) async {
    // Validate session exists (by workoutId).
    if (_findIndexBySessionId(sessionWorkoutId) == -1) {
      throw ArgumentError('Session not found for workoutId=$sessionWorkoutId');
    }
    final set = ExerciseSet(
      sessionWorkoutId: sessionWorkoutId,
      exerciseId: exerciseId,
      setIndex: setIndex,
      reps: reps,
      weight: weight,
      durationSeconds: durationSeconds,
      recordedAt: recordedAt ?? DateTime.now(),
    );
    await _setBox.add(set);
    // Mirror to SQLite (best-effort) - need session row id.
    unawaited(_mirrorInsertSet(set));
    return set;
  }

  List<ExerciseSet> listExerciseSets(
    String sessionWorkoutId,
    String exerciseId,
  ) {
    return _setBox.values
        .where(
          (s) =>
              s.sessionWorkoutId == sessionWorkoutId &&
              s.exerciseId == exerciseId,
        )
        .toList()
      ..sort((a, b) => a.setIndex.compareTo(b.setIndex));
  }

  Future<void> _mirrorInsertSet(ExerciseSet set) async {
    try {
      final row = await WorkoutSessionSqlHelpers.getOngoingSessionRow();
      if (row == null) return;
      await WorkoutSessionSqlHelpers.upsertExerciseSet(
        sessionRowId: row['id'] as int,
        exerciseId: set.exerciseId,
        setIndex: set.setIndex,
        reps: set.reps,
        weight: set.weight,
        durationSeconds: set.durationSeconds,
        recordedAt: set.recordedAt,
      );
    } catch (e, st) {
      logError('Mirror insert set failed: $e', st);
    }
  }

  // =============================
  // Aggregates (Hive source of truth)
  // =============================

  /// Total minutes across completed sessions within optional [from, to) bounds.
  /// Bounds are inclusive of [from] (start of window) and exclusive of [to] if provided.
  /// If both are null, sums all completed sessions.
  Future<int> getTotalMinutes({DateTime? from, DateTime? to}) async {
    final sessions = _box.values;
    int seconds = 0;
    for (final s in sessions) {
      if (!s.completed) continue;
      final d = s.date;
      if (from != null && d.isBefore(from)) continue;
      if (to != null && !d.isBefore(to)) continue; // exclusive upper bound
      seconds += s.durationSeconds;
    }
    return seconds ~/ 60;
  }

  /// Count of completed sessions in the box.
  Future<int> getCompletedSessionsCount() async {
    return _box.values.where((s) => s.completed).length;
  }

  /// Returns a map of last 7 days (including today) -> minutes for completed sessions.
  /// Keys are the local midnight DateTime for each day.
  Future<Map<DateTime, int>> getLast7DaysBreakdown({DateTime? now}) async {
    final Map<DateTime, int> out = {};
    final n = now ?? DateTime.now();
    DateTime startOfToday = DateTime(n.year, n.month, n.day);
    // Seed all 7 days with 0
    for (int i = 0; i < 7; i++) {
      final day = startOfToday.subtract(Duration(days: i));
      out[day] = 0;
    }
    for (final s in _box.values) {
      if (!s.completed) continue;
      final d = DateTime(s.date.year, s.date.month, s.date.day);
      final diff = startOfToday.difference(d).inDays;
      if (diff >= 0 && diff < 7) {
        out[d] = (out[d] ?? 0) + (s.durationSeconds ~/ 60);
      }
    }
    return out;
  }
}
