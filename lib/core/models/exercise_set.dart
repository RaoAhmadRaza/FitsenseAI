// Individual set details for finer-grained tracking (optional layer).
// Stored in a separate Hive box (exerciseSetBox) to avoid bloating session objects.

import 'package:hive/hive.dart';

part 'exercise_set.g.dart';

@HiveType(typeId: 12)
class ExerciseSet extends HiveObject {
  @HiveField(0)
  final String sessionWorkoutId; // links to WorkoutSession.workoutId (not DB row)
  @HiveField(1)
  final String exerciseId;
  @HiveField(2)
  final int setIndex; // 1-based
  @HiveField(3)
  final int reps;
  @HiveField(4)
  final int weight; // unit consistent with ExerciseProgress.usedWeight
  @HiveField(5)
  final int durationSeconds; // active time for this set
  @HiveField(6)
  final DateTime recordedAt;

  ExerciseSet({
    required this.sessionWorkoutId,
    required this.exerciseId,
    required this.setIndex,
    required this.reps,
    required this.weight,
    required this.durationSeconds,
    required this.recordedAt,
  });
}
