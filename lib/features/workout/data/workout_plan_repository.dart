// lib/features/workout/data/workout_plan_repository.dart
// Repository for workout plan templates (Hive primary, SQLite mirror best-effort).
// Does not modify UI directly. Provides APIs for future cubit/state layer.

import 'package:hive/hive.dart';
import '../../../core/models/workout_plan.dart';
import '../../../core/db/app_database.dart';
import '../../../core/utils/logger.dart';

class WorkoutPlanRepository {
  static const _planBoxName = 'workoutPlanBox';

  Box<WorkoutPlan> get _box => Hive.box<WorkoutPlan>(_planBoxName);

  bool get isSeeded => _box.isNotEmpty;

  Future<void> seedDefaultsIfEmpty() async {
    if (isSeeded) return; // idempotent guard

    final pushPull = WorkoutPlan(
      id: WorkoutPlan.newId(),
      name: 'Push Day',
      level: 'Beginner',
      durationDisplay: '50 Min',
      equipment: ['Barbell', 'Dumbbells', 'Bench'],
      exercises: [
        PlanExercise(
          id: 'bench_press',
          name: 'Barbell Bench Press',
          targetMuscle: 'Chest',
          imagePath: 'assets/images/bench.png',
          gifUrl: '',
          sets: 4,
          reps: 8,
          weight: 0,
        ),
        PlanExercise(
          id: 'incline_db_press',
          name: 'Incline Dumbbell Press',
          targetMuscle: 'Chest',
          imagePath: 'assets/images/incline-bench-press.jpg',
          gifUrl: '',
          sets: 3,
          reps: 10,
          weight: 0,
        ),
        PlanExercise(
          id: 'dumbbell_lateral_raise',
          name: 'Dumbbell Lateral Raise',
          targetMuscle: 'Shoulders',
          imagePath: 'assets/images/dumbbell-lateral-raise.jpg',
          gifUrl: '',
          sets: 3,
          reps: 12,
          weight: 0,
        ),
      ],
    );

    final pullDay = WorkoutPlan(
      id: WorkoutPlan.newId(),
      name: 'Pull Day',
      level: 'Beginner',
      durationDisplay: '50 Min',
      equipment: ['Barbell', 'Dumbbells'],
      exercises: [
        PlanExercise(
          id: 'barbell_curl',
          name: 'Barbell Curl',
          targetMuscle: 'Biceps',
          imagePath: 'assets/images/barbell-curl.jpg',
          gifUrl: '',
          sets: 3,
          reps: 10,
          weight: 0,
        ),
        PlanExercise(
          id: 'seated_concentration_curl',
          name: 'Seated Concentration Curl',
          targetMuscle: 'Biceps',
          imagePath: 'assets/images/seated-concentration-curl.jpg',
          gifUrl: '',
          sets: 3,
          reps: 12,
          weight: 0,
        ),
        PlanExercise(
          id: 'bent_over_rear_delt_raise',
          name: 'Bent Over Rear Delt Raise',
          targetMuscle: 'Shoulders',
          imagePath: 'assets/images/bent-over-rear-delt-raise.jpg',
          gifUrl: '',
          sets: 3,
          reps: 15,
          weight: 0,
        ),
      ],
    );

    final batch = <WorkoutPlan>[pushPull, pullDay];
    for (final plan in batch) {
      await _box.add(plan);
      _mirrorPlan(plan);
    }
  }

  Future<List<WorkoutPlan>> listPlans() async {
    return _box.values.toList(growable: false);
  }

  WorkoutPlan? getPlan(String id) {
    for (final plan in _box.values) {
      if (plan.id == id) return plan;
    }
    return null;
  }

  Future<void> addOrUpdatePlan(WorkoutPlan plan) async {
    // If existing (match id) replace via delete/put since Hive box keyed by auto index when using add.
    final existingKey = _box.keys.cast<dynamic>().firstWhere((k) {
      final v = _box.get(k);
      return v?.id == plan.id;
    }, orElse: () => null);
    if (existingKey != null) {
      await _box.put(existingKey, plan);
    } else {
      await _box.add(plan);
    }
    _mirrorPlan(plan);
  }

  Future<void> addExercise(String planId, PlanExercise exercise) async {
    final plan = getPlan(planId);
    if (plan == null) return;
    final updated = plan.copyWith(exercises: [...plan.exercises, exercise]);
    await addOrUpdatePlan(updated);
  }

  Future<void> updateExercise(String planId, PlanExercise exercise) async {
    final plan = getPlan(planId);
    if (plan == null) return;
    final updated = plan.copyWith(
      exercises: [
        for (final e in plan.exercises)
          if (e.id == exercise.id) exercise else e,
      ],
    );
    await addOrUpdatePlan(updated);
  }

  Future<void> removeExercise(String planId, String exerciseId) async {
    final plan = getPlan(planId);
    if (plan == null) return;
    final updated = plan.copyWith(
      exercises: [
        for (final e in plan.exercises)
          if (e.id != exerciseId) e,
      ],
    );
    await addOrUpdatePlan(updated);
  }

  // =========================
  // SQLite Mirror (best effort)
  // =========================
  Future<void> _mirrorPlan(WorkoutPlan plan) async {
    try {
      await WorkoutPlanSqlHelpers.upsertWorkoutPlan(
        id: plan.id,
        name: plan.name,
        level: plan.level,
        durationDisplay: plan.durationDisplay,
      );

      await WorkoutPlanSqlHelpers.replacePlanExercises(
        planId: plan.id,
        exercises: [
          for (final e in plan.exercises)
            {
              'exercise_id': e.id,
              'name': e.name,
              'target_muscle': e.targetMuscle,
              'image_path': e.imagePath,
              'gif_url': e.gifUrl,
              'sets': e.sets,
              'reps': e.reps,
              'weight': e.weight,
            },
        ],
      );

      await WorkoutPlanSqlHelpers.replacePlanEquipment(
        planId: plan.id,
        equipment: plan.equipment,
      );
    } catch (e, st) {
      logError('Mirror plan failed: $e', st);
    }
  }
}
