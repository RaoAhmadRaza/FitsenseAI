import 'package:bloc/bloc.dart';
import 'dart:async';

import '../../core/models/workout_session.dart';
import '../../features/workout/data/workout_session_repository.dart';
import '../../core/models/session_runtime.dart';
import '../../core/models/workout_plan.dart';
import '../../core/utils/plan_exercise_id.dart';
import 'package:hive/hive.dart';

// State holds ongoing + last completed sessions (nullable if absent).
class SessionState {
  final WorkoutSession? ongoing;
  final WorkoutSession? lastCompleted;
  final bool loading;
  final String? error;
  final String? activeExerciseId; // ephemeral focus pointer (not persisted)
  final bool
  recovered; // indicates session reconstructed after app restart without active exercise runtime

  const SessionState({
    this.ongoing,
    this.lastCompleted,
    this.loading = false,
    this.error,
    this.activeExerciseId,
    this.recovered = false,
  });

  SessionState copyWith({
    WorkoutSession? ongoing,
    WorkoutSession? lastCompleted,
    bool? loading,
    String? error,
    String? activeExerciseId,
    bool? recovered,
  }) => SessionState(
    ongoing: ongoing ?? this.ongoing,
    lastCompleted: lastCompleted ?? this.lastCompleted,
    loading: loading ?? this.loading,
    error: error,
    activeExerciseId: activeExerciseId ?? this.activeExerciseId,
    recovered: recovered ?? this.recovered,
  );
}

class SessionCubit extends Cubit<SessionState> {
  final WorkoutSessionRepository _repo;
  SessionCubit(this._repo) : super(const SessionState());

  Box<SessionRuntime> get _runtimeBox =>
      Hive.box<SessionRuntime>('sessionRuntimeBox');

  // Live duration exposure for UI:
  // - liveOngoingSeconds: current seconds for the ongoing session (null if none)
  // - liveOngoingSecondsStream: emits when ongoing duration changes; pauses naturally when session is paused
  // - liveOngoingMinutesStream: minutes version (floor)
  int? get liveOngoingSeconds => state.ongoing?.durationSeconds;
  Stream<int?> get liveOngoingSecondsStream =>
      stream.map((s) => s.ongoing?.durationSeconds).distinct();
  Stream<int> get liveOngoingMinutesStream => stream
      .map((s) => s.ongoing?.durationSeconds ?? 0)
      .map((sec) => sec ~/ 60)
      .distinct();

  Future<SessionRuntime> _upsertRuntime(
    WorkoutSession session, {
    int? currentExerciseIndex,
    int? currentRound,
    int? currentRepsInSet,
    DateTime? exerciseStartedAt,
    bool clearExerciseStartedAt = false,
    int? accumulatedExerciseSeconds,
    String? mode,
    bool? paused,
    DateTime? pausedAt,
    String? planId,
    DateTime? lastActiveAt,
  }) async {
    final key = session.workoutId; // use workoutId as unique runtime key
    SessionRuntime? existing = _runtimeBox.get(key);
    if (existing == null) {
      existing = SessionRuntime(
        sessionWorkoutId: key,
        currentExerciseIndex: currentExerciseIndex ?? 1,
        currentRound: currentRound ?? 1,
        currentRepsInSet: currentRepsInSet ?? 0,
        exerciseStartedAt: exerciseStartedAt,
        accumulatedExerciseSeconds: accumulatedExerciseSeconds ?? 0,
        mode: mode ?? 'ready',
        updatedAt: DateTime.now(),
        paused: paused ?? false,
        pausedAt: pausedAt,
        planId: planId,
        lastActiveAt: lastActiveAt ?? DateTime.now(),
      );
    } else {
      // Manual rebuild to support explicit clearing of exerciseStartedAt
      existing = SessionRuntime(
        sessionWorkoutId: existing.sessionWorkoutId,
        currentExerciseIndex:
            currentExerciseIndex ?? existing.currentExerciseIndex,
        currentRound: currentRound ?? existing.currentRound,
        currentRepsInSet: currentRepsInSet ?? existing.currentRepsInSet,
        exerciseStartedAt: clearExerciseStartedAt
            ? null
            : (exerciseStartedAt ?? existing.exerciseStartedAt),
        accumulatedExerciseSeconds:
            accumulatedExerciseSeconds ?? existing.accumulatedExerciseSeconds,
        mode: mode ?? existing.mode,
        updatedAt: DateTime.now(),
        paused: paused ?? existing.paused,
        pausedAt: pausedAt ?? existing.pausedAt,
        planId: planId ?? existing.planId,
        lastActiveAt: lastActiveAt ?? existing.lastActiveAt ?? DateTime.now(),
      );
    }
    await _runtimeBox.put(key, existing);
    return existing;
  }

  SessionRuntime? getRuntime(String workoutId) => _runtimeBox.get(workoutId);

  static const _tickInterval = Duration(seconds: 5);
  Timer? _ticker;
  Timer?
  _runtimeFlushTimer; // periodically flush exercise elapsed time while active
  static const _runtimeFlushInterval = Duration(seconds: 15);

  void _ensureTicker() {
    final hasOngoing =
        state.ongoing != null && state.ongoing!.completed == false;
    // Respect paused state from runtime; don't tick while paused
    bool paused = false;
    if (hasOngoing) {
      final rt = getRuntime(state.ongoing!.workoutId);
      paused = rt?.paused == true;
    }
    if (hasOngoing && !paused && _ticker == null) {
      _ticker = Timer.periodic(_tickInterval, (_) async {
        final current = state.ongoing;
        if (current == null || current.completed) {
          _stopTicker();
          return;
        }
        // Skip ticking if paused mid-flight
        final rt = getRuntime(current.workoutId);
        if (rt?.paused == true) {
          _stopTicker();
          return;
        }
        try {
          // Increment by interval seconds.
          final updated = await _repo.updateDuration(
            current.workoutId,
            _tickInterval.inSeconds,
          );
          // Emit updated state without a full refresh to keep it light.
          emit(state.copyWith(ongoing: updated));
          // Also bump lastActiveAt since we just accounted for time
          try {
            await _upsertRuntime(updated, lastActiveAt: DateTime.now());
          } catch (_) {}
        } catch (_) {
          // Silent for now; could log.
        }
      });
      // Start runtime flush timer (idempotent)
      _runtimeFlushTimer ??= Timer.periodic(_runtimeFlushInterval, (_) {
        _flushActiveExerciseElapsed();
      });
    } else if (!hasOngoing || paused) {
      _stopTicker();
    }
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    _runtimeFlushTimer?.cancel();
    _runtimeFlushTimer = null;
  }

  Future<void> refresh() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      var ongoing = await _repo.getOngoingSession();
      final last = await _repo.getLastCompletedSession();
      // Reconciliation: if ongoing exists, recompute duration from bounded baseline to avoid drift.
      if (ongoing != null) {
        final now = DateTime.now();
        final runtime = getRuntime(ongoing.workoutId);
        final isPaused = runtime?.paused == true;
        final defaultBaseline = ongoing.date.add(
          Duration(seconds: ongoing.durationSeconds),
        );
        final baseline = runtime?.lastActiveAt ?? defaultBaseline;
        final boundedDiff = now.isAfter(baseline)
            ? now.difference(baseline).inSeconds
            : 0;
        // Defensive: if paused, ensure exerciseStartedAt is null to avoid stale deltas on resume
        if (isPaused && runtime?.exerciseStartedAt != null) {
          await _upsertRuntime(
            ongoing,
            exerciseStartedAt: null,
            clearExerciseStartedAt: true,
          );
        }
        if (!isPaused && boundedDiff > 0) {
          // Update local duration by the missing amount since lastActiveAt
          ongoing = await _repo.updateDuration(ongoing.workoutId, boundedDiff);
          // Advance baseline to now
          await _upsertRuntime(ongoing, lastActiveAt: now);
        }
        // Stale session cleanup (e.g., > 8 hours old and not completed => auto-complete)
        const staleThreshold = Duration(hours: 8);
        if (!ongoing.completed &&
            now.difference(ongoing.date) > staleThreshold) {
          ongoing = await _repo.completeSession(ongoing.workoutId);
        }
      }
      // Recovery detection: if we have an ongoing session with progress but runtime lacks active exercise start timestamp.
      bool recovered = false;
      if (ongoing != null) {
        final runtime = getRuntime(ongoing.workoutId);
        if (ongoing.progress.isNotEmpty &&
            (runtime == null || runtime.exerciseStartedAt == null)) {
          recovered = true;
        }
      }
      emit(
        state.copyWith(
          ongoing: ongoing,
          lastCompleted: last,
          loading: false,
          recovered: recovered,
        ),
      );
      _ensureTicker();
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  // =============================
  // Exercise Lifecycle Methods
  // =============================

  // -----------------------------
  // Hybrid Session Creation
  // -----------------------------
  /// Explicitly start a new workout session if none is ongoing.
  /// Idempotent: if an ongoing session already exists it is returned unchanged.
  /// Returns the active (existing or newly created) session.
  Future<WorkoutSession?> startSession(
    String workoutId, {
    String? planId,
  }) async {
    var existing = state.ongoing;
    if (existing != null && !existing.completed) {
      return existing;
    }
    try {
      final created = await _repo.startSession(workoutId: workoutId);
      // TODO: analytics: session_started($workoutId)
      emit(state.copyWith(ongoing: created));
      _ensureTicker();
      await _upsertRuntime(
        created,
        mode: 'ready',
        currentExerciseIndex: 1,
        currentRound: 1,
        // If a planId was explicitly provided store it; else try to derive lazily from workoutId pattern.
        // WorkoutId pattern for plan sessions currently: plan_<planId>_<timestamp>
        // We intentionally do not attempt derivation if workoutId does not match pattern.
        // This lets future non-plan sessions co-exist without polluting runtime metadata.
        planId: planId ?? extractPlanIdFromWorkoutId(workoutId),
      );
      return created;
    } catch (e) {
      emit(state.copyWith(error: 'Failed to start session: $e'));
      return null;
    }
  }

  /// Start a session derived from a WorkoutPlan template and pre-seed deterministic exercises.
  /// Pre-seeding creates zero-progress ExerciseProgress entries for ordering / upcoming UI.
  Future<WorkoutSession?> startPlanSession(WorkoutPlan plan) async {
    final sessionId =
        'plan_${plan.id}_${DateTime.now().millisecondsSinceEpoch}';
    final session = await startSession(sessionId, planId: plan.id);
    if (session == null) return null;
    WorkoutSession current = session;
    if (plan.exercises.isNotEmpty) {
      // Seed all exercises with zero progress (idempotent: repository upsert logic handles duplicates)
      for (var i = 0; i < plan.exercises.length; i++) {
        final exId = PlanExerciseId.build(plan.id, i + 1);
        final already = current.progress.any((p) => p.exerciseId == exId);
        if (!already) {
          current = await _repo.upsertExerciseProgress(
            current.workoutId,
            ExerciseProgress(
              exerciseId: exId,
              completedSets: 0,
              completedReps: 0,
              usedWeight: plan.exercises[i].weight ?? 0,
              timeSpentSeconds: 0,
            ),
          );
        }
      }
      // Activate first exercise (sets runtime exercising state)
      await startExercise(PlanExerciseId.build(plan.id, 1));
    }
    return state.ongoing; // updated reference
  }

  /// Ensure an ExerciseProgress entry exists for [exerciseId].
  Future<void> startExercise(String exerciseId) async {
    var session = state.ongoing;
    // Defensive fallback: if no session, auto-start with exerciseId-derived workout id.
    if (session == null) {
      session = await startSession(
        'auto_${DateTime.now().millisecondsSinceEpoch}',
      );
    }
    if (session == null || session.completed) return; // still no active session
    // Idempotent: search manually.
    final exists = session.progress.any((p) => p.exerciseId == exerciseId);
    if (!exists) {
      final updatedSession = await _repo.upsertExerciseProgress(
        session.workoutId,
        ExerciseProgress(
          exerciseId: exerciseId,
          completedSets: 0,
          completedReps: 0,
          usedWeight: 0,
          timeSpentSeconds: 0,
        ),
      );
      emit(
        state.copyWith(ongoing: updatedSession, activeExerciseId: exerciseId),
      );
      await _upsertRuntime(
        updatedSession,
        currentExerciseIndex: _parseExerciseIndex(exerciseId),
        mode: 'exercising',
        exerciseStartedAt: DateTime.now(),
      );
    } else {
      emit(state.copyWith(activeExerciseId: exerciseId));
      await _upsertRuntime(
        session,
        currentExerciseIndex: _parseExerciseIndex(exerciseId),
        mode: 'exercising',
        exerciseStartedAt: DateTime.now(),
      );
    }
    // TODO: analytics: exercise_start($exerciseId)
  }

  /// Increment cumulative reps for an exercise (auto-start if missing).
  Future<void> incrementRep(String exerciseId, {int delta = 1}) async {
    if (delta <= 0) return;
    final session = state.ongoing;
    if (session == null || session.completed) return;
    var progress = session.progress;
    var targetIdx = progress.indexWhere((p) => p.exerciseId == exerciseId);
    ExerciseProgress ep;
    if (targetIdx == -1) {
      // Auto-start
      ep = ExerciseProgress(
        exerciseId: exerciseId,
        completedSets: 0,
        completedReps: delta,
        usedWeight: 0,
        timeSpentSeconds: 0,
      );
    } else {
      final existing = progress[targetIdx];
      ep = existing.copyWith(completedReps: existing.completedReps + delta);
    }
    final updatedSession = await _repo.upsertExerciseProgress(
      session.workoutId,
      ep,
    );
    emit(state.copyWith(ongoing: updatedSession, activeExerciseId: exerciseId));
    final runtime = getRuntime(session.workoutId);
    final currentReps = (runtime?.currentRepsInSet ?? 0) + delta;
    await _upsertRuntime(
      updatedSession,
      currentExerciseIndex: _parseExerciseIndex(exerciseId),
      currentRepsInSet: currentReps,
      mode: 'exercising',
    );
  }

  /// Mark a set complete. Optionally record set details via per-set storage.
  Future<void> completeSet(
    String exerciseId, {
    int repsInSet = 0,
    int? weight,
    int durationSeconds = 0,
  }) async {
    final session = state.ongoing;
    if (session == null || session.completed) return;
    var progress = session.progress;
    var targetIdx = progress.indexWhere((p) => p.exerciseId == exerciseId);
    ExerciseProgress ep;
    if (targetIdx == -1) {
      // Start implicitly with one completed set.
      ep = ExerciseProgress(
        exerciseId: exerciseId,
        completedSets: 1,
        completedReps: repsInSet,
        usedWeight: weight ?? 0,
        timeSpentSeconds: durationSeconds,
      );
    } else {
      final existing = progress[targetIdx];
      ep = existing.copyWith(
        completedSets: existing.completedSets + 1,
        completedReps: existing.completedReps + repsInSet,
        usedWeight: weight ?? existing.usedWeight,
        timeSpentSeconds: existing.timeSpentSeconds + durationSeconds,
      );
    }
    final updatedSession = await _repo.upsertExerciseProgress(
      session.workoutId,
      ep,
    );

    // Persist granular set (setIndex = new completedSets - 1)
    final setIndex = ep.completedSets - 1;
    await _repo.addExerciseSet(
      sessionWorkoutId: session.workoutId,
      exerciseId: exerciseId,
      setIndex: setIndex,
      reps: repsInSet,
      weight: weight ?? ep.usedWeight,
      durationSeconds: durationSeconds,
    );
    emit(state.copyWith(ongoing: updatedSession, activeExerciseId: exerciseId));
    final runtime = getRuntime(session.workoutId);
    final nextRound = (runtime?.currentRound ?? 1) + 1;
    await _upsertRuntime(
      updatedSession,
      currentExerciseIndex: _parseExerciseIndex(exerciseId),
      currentRound: nextRound,
      currentRepsInSet: 0,
      mode: 'ready',
      accumulatedExerciseSeconds:
          (runtime?.accumulatedExerciseSeconds ?? 0) + durationSeconds,
    );
    // TODO: analytics: set_complete($exerciseId, setIndex=${ep.completedSets})
  }

  /// Record a set explicitly (does not alter cumulative reps/sets automatically).
  Future<void> logSet(
    String exerciseId, {
    required int setIndex,
    required int reps,
    required int weight,
    int durationSeconds = 0,
  }) async {
    final session = state.ongoing;
    if (session == null || session.completed) return;
    await _repo.addExerciseSet(
      sessionWorkoutId: session.workoutId,
      exerciseId: exerciseId,
      setIndex: setIndex,
      reps: reps,
      weight: weight,
      durationSeconds: durationSeconds,
    );
  }

  /// Focus a different exercise without mutation.
  void selectExercise(String exerciseId) {
    if (state.ongoing == null) return;
    emit(state.copyWith(activeExerciseId: exerciseId));
  }

  /// Pause the session (stops duration ticker; retains runtime with pause timestamp)
  Future<void> pauseSession() async {
    final session = state.ongoing;
    if (session == null || session.completed) return;
    _stopTicker();
    final runtime = getRuntime(session.workoutId);
    if (runtime != null) {
      // If currently exercising, add elapsed since start into accumulated seconds.
      int extra = 0;
      if (!runtime.paused &&
          runtime.exerciseStartedAt != null &&
          runtime.mode == 'exercising') {
        extra = DateTime.now().difference(runtime.exerciseStartedAt!).inSeconds;
      }
      await _upsertRuntime(
        session,
        accumulatedExerciseSeconds: runtime.accumulatedExerciseSeconds + extra,
        exerciseStartedAt: null,
        clearExerciseStartedAt: true,
        paused: true,
        pausedAt: DateTime.now(),
        mode: runtime.mode == 'exercising' ? 'ready' : runtime.mode,
        lastActiveAt: DateTime.now(),
      );
      // Ensure the paused flag is flushed to disk before app can be killed
      try {
        await _runtimeBox.flush();
      } catch (_) {}
    }
  }

  /// Resume a previously paused session (restarts ticker and sets exerciseStartedAt if needed)
  Future<void> resumeSession() async {
    final session = state.ongoing;
    if (session == null || session.completed) return;
    final runtime = getRuntime(session.workoutId);
    if (runtime != null) {
      await _upsertRuntime(
        session,
        paused: false,
        pausedAt: null,
        exerciseStartedAt: DateTime.now(),
        mode: runtime.mode == 'ready' ? 'exercising' : runtime.mode,
        lastActiveAt: DateTime.now(),
      );
    }
    // Start ticker after runtime updated
    _ensureTicker();
  }

  /// Flush currently accruing exercise elapsed seconds into accumulatedExerciseSeconds.
  Future<void> _flushActiveExerciseElapsed() async {
    final session = state.ongoing;
    if (session == null) return;
    final runtime = getRuntime(session.workoutId);
    if (runtime == null) return;
    if (runtime.paused) return; // nothing to do while paused
    if (runtime.mode != 'exercising') return;
    if (runtime.exerciseStartedAt == null) return;
    final extra = DateTime.now()
        .difference(runtime.exerciseStartedAt!)
        .inSeconds;
    if (extra <= 0) return;
    await _upsertRuntime(
      session,
      accumulatedExerciseSeconds: runtime.accumulatedExerciseSeconds + extra,
      exerciseStartedAt:
          DateTime.now(), // reset baseline so we don't double count
      lastActiveAt: DateTime.now(),
    );
  }

  /// Complete the entire session (stop ticker + persist completion flag).
  Future<void> completeSession() async {
    final session = state.ongoing;
    if (session == null || session.completed) return;
    final updated = await _repo.completeSession(session.workoutId);
    // TODO: analytics: session_complete(${session.workoutId})
    // Emit intermediate state with completed session (will be cleared after refresh)
    emit(state.copyWith(ongoing: updated));
    _stopTicker();
    final runtime = getRuntime(session.workoutId);
    if (runtime != null) {
      await _runtimeBox.delete(session.workoutId);
    }
    // Refresh to relocate completed session into lastCompleted and null out ongoing per repository rules.
    // This avoids the home screen still showing a 'completed' session as active.
    unawaited(refresh());
  }

  int _parseExerciseIndex(String exerciseId) {
    final m = RegExp(r'^plan_[a-f0-9]+ex(\d+)$').firstMatch(exerciseId);
    if (m != null) {
      return int.tryParse(m.group(1)!) ?? 1;
    }
    final parts = exerciseId.split('_');
    if (parts.length == 2) {
      return int.tryParse(parts[1]) ?? 1;
    }
    return 1;
  }

  /// Extract planId from a workout/session id if it follows the plan session pattern.
  /// Pattern: plan_<planId>_<epochMillis>
  String? extractPlanIdFromWorkoutId(String workoutId) {
    final m = RegExp(r'^plan_([a-f0-9]+)_\d{5,}$').firstMatch(workoutId);
    if (m != null) return m.group(1);
    return null;
  }

  /// Convenience accessor for UI: returns originating planId if current session is plan-based.
  String? get currentPlanId {
    final s = state.ongoing;
    if (s == null) return null;
    final runtime = getRuntime(s.workoutId);
    return runtime?.planId ?? extractPlanIdFromWorkoutId(s.workoutId);
  }

  @override
  Future<void> close() {
    _stopTicker();
    return super.close();
  }
}
