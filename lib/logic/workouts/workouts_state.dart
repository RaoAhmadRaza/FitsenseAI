part of 'workouts_cubit.dart';

enum WorkoutsStatus { initial, loading, ready, error }

class WorkoutsState {
  final WorkoutsStatus status;
  final List<WorkoutPlan> plans;
  final String? selectedPlanId;
  final String? errorMessage;

  const WorkoutsState({
    required this.status,
    required this.plans,
    this.selectedPlanId,
    this.errorMessage,
  });

  const WorkoutsState.initial()
    : status = WorkoutsStatus.initial,
      plans = const [],
      selectedPlanId = null,
      errorMessage = null;

  WorkoutsState copyWith({
    WorkoutsStatus? status,
    List<WorkoutPlan>? plans,
    String? selectedPlanId,
    String? errorMessage,
    bool clearError = false,
  }) => WorkoutsState(
    status: status ?? this.status,
    plans: plans ?? this.plans,
    selectedPlanId: selectedPlanId ?? this.selectedPlanId,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );

  WorkoutPlan? get selectedPlan {
    if (selectedPlanId == null) return null;
    for (final p in plans) {
      if (p.id == selectedPlanId) return p;
    }
    return null;
  }
}
