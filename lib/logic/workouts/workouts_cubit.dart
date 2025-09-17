// lib/logic/workouts/workouts_cubit.dart
// Lightweight Cubit managing workout plan templates (no UI changes yet).

import 'package:bloc/bloc.dart';
import '../../features/workout/data/workout_plan_repository.dart';
import '../../core/models/workout_plan.dart';

part 'workouts_state.dart';

class WorkoutsCubit extends Cubit<WorkoutsState> {
  final WorkoutPlanRepository _repo;
  WorkoutsCubit(this._repo) : super(const WorkoutsState.initial());

  Future<void> load() async {
    emit(state.copyWith(status: WorkoutsStatus.loading));
    try {
      await _repo.seedDefaultsIfEmpty();
      final plans = await _repo.listPlans();
      emit(state.copyWith(status: WorkoutsStatus.ready, plans: plans));
    } catch (e) {
      emit(state.copyWith(status: WorkoutsStatus.error, errorMessage: '$e'));
    }
  }

  void selectPlan(String planId) {
    emit(state.copyWith(selectedPlanId: planId));
  }

  Future<void> addExercise(String planId, PlanExercise exercise) async {
    await _repo.addExercise(planId, exercise);
    await load();
    emit(state.copyWith(selectedPlanId: planId));
  }

  Future<void> updateExercise(String planId, PlanExercise exercise) async {
    await _repo.updateExercise(planId, exercise);
    await load();
    emit(state.copyWith(selectedPlanId: planId));
  }

  Future<void> removeExercise(String planId, String exerciseId) async {
    await _repo.removeExercise(planId, exerciseId);
    await load();
    emit(state.copyWith(selectedPlanId: planId));
  }

  // ==============================
  // Plan CRUD (initial stubs)
  // ==============================

  Future<void> createPlan({
    required String name,
    String level = 'Custom',
    String durationDisplay = '--',
    List<String> equipment = const [],
  }) async {
    try {
      final plan = WorkoutPlan(
        id: WorkoutPlan.newId(),
        name: name.trim().isEmpty ? 'Untitled Plan' : name.trim(),
        level: level,
        durationDisplay: durationDisplay,
        equipment: equipment,
        exercises: const [],
      );
      await _repo.addOrUpdatePlan(plan);
      await load();
      emit(state.copyWith(selectedPlanId: plan.id));
    } catch (e) {
      emit(
        state.copyWith(
          status: WorkoutsStatus.error,
          errorMessage: 'Failed to create plan: $e',
        ),
      );
    }
  }

  Future<void> updatePlan(WorkoutPlan plan) async {
    try {
      await _repo.addOrUpdatePlan(plan);
      await load();
      emit(state.copyWith(selectedPlanId: plan.id));
    } catch (e) {
      emit(
        state.copyWith(
          status: WorkoutsStatus.error,
          errorMessage: 'Failed to update plan: $e',
        ),
      );
    }
  }
}
