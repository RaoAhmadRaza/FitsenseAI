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
    // Mirror to SQLite (ignore errors for now)
    unawaited(_mirrorInsert(session));
    return session;
  }

  Future<void> _mirrorInsert(WorkoutSession s) async {
    try {
      await WorkoutSessionSqlHelpers.insertWorkoutSession(
        workoutId: s.workoutId,
        date: s.date,
      );
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

  Future<WorkoutSession?> getOngoingSession() async => getOngoingSessionSync();
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
    // Mirror duration update (best-effort)
    unawaited(_mirrorUpdateDuration(updated));
    return updated;
  }

  Future<void> _mirrorUpdateDuration(WorkoutSession s) async {
    try {
      // Need the SQLite row id; for now we just update the latest ongoing row.
      final row = await WorkoutSessionSqlHelpers.getOngoingSessionRow();
      if (row != null) {
        await WorkoutSessionSqlHelpers.updateWorkoutSession(
          id: row['id'] as int,
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
      final row = await WorkoutSessionSqlHelpers.getOngoingSessionRow();
      if (row == null) return; // can't map
      final sessionId = row['id'] as int;
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
    unawaited(_mirrorComplete(updated));
    return updated;
  }

  Future<void> _mirrorComplete(WorkoutSession s) async {
    try {
      final row = await WorkoutSessionSqlHelpers.getOngoingSessionRow();
      if (row != null) {
        await WorkoutSessionSqlHelpers.updateWorkoutSession(
          id: row['id'] as int,
          completed: true,
          durationSeconds: s.durationSeconds,
        );
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
}
