// lib/core/models/workout_session.dart
// Data models for tracking a workout session and per-exercise progress.
// NOTE: UI must not depend directly on Hive box instances; access through repository.
// Chosen Hive typeIds start at 10 to avoid collision with any future adapters.

import 'package:hive/hive.dart';
import 'dart:math';

// We are not using code generation yet; manual adapters defined below.
part 'workout_session.g.dart'; // placeholder (adapters manually written)

@HiveType(typeId: 10)
class ExerciseProgress extends HiveObject {
  @HiveField(0)
  final String exerciseId; // stable identifier (slug/name)
  @HiveField(1)
  final int completedSets;
  @HiveField(2)
  final int completedReps; // cumulative reps across sets so far
  @HiveField(3)
  final int usedWeight; // unit implicit (e.g. lbs) – future: store unit enum
  @HiveField(4)
  final int timeSpentSeconds; // total active time spent for this exercise

  ExerciseProgress({
    required this.exerciseId,
    required this.completedSets,
    required this.completedReps,
    required this.usedWeight,
    required this.timeSpentSeconds,
  });

  ExerciseProgress copyWith({
    String? exerciseId,
    int? completedSets,
    int? completedReps,
    int? usedWeight,
    int? timeSpentSeconds,
  }) => ExerciseProgress(
    exerciseId: exerciseId ?? this.exerciseId,
    completedSets: completedSets ?? this.completedSets,
    completedReps: completedReps ?? this.completedReps,
    usedWeight: usedWeight ?? this.usedWeight,
    timeSpentSeconds: timeSpentSeconds ?? this.timeSpentSeconds,
  );

  Map<String, dynamic> toMap() => {
    'exerciseId': exerciseId,
    'completedSets': completedSets,
    'completedReps': completedReps,
    'usedWeight': usedWeight,
    'timeSpentSeconds': timeSpentSeconds,
  };

  static ExerciseProgress fromMap(Map<String, Object?> map) => ExerciseProgress(
    exerciseId: map['exerciseId'] as String,
    completedSets: (map['completedSets'] as num).toInt(),
    completedReps: (map['completedReps'] as num).toInt(),
    usedWeight: (map['usedWeight'] as num).toInt(),
    timeSpentSeconds: (map['timeSpentSeconds'] as num).toInt(),
  );
}

@HiveType(typeId: 11)
class WorkoutSession extends HiveObject {
  @HiveField(0)
  final String workoutId; // external workout plan id or UUID
  @HiveField(1)
  final DateTime date; // start date/time
  @HiveField(2)
  final int durationSeconds; // running total (can be recomputed later)
  @HiveField(3)
  final List<ExerciseProgress> progress; // per-exercise snapshots
  @HiveField(4)
  final bool completed;

  WorkoutSession({
    required this.workoutId,
    required this.date,
    required this.durationSeconds,
    required this.progress,
    required this.completed,
  });

  WorkoutSession copyWith({
    String? workoutId,
    DateTime? date,
    int? durationSeconds,
    List<ExerciseProgress>? progress,
    bool? completed,
  }) => WorkoutSession(
    workoutId: workoutId ?? this.workoutId,
    date: date ?? this.date,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    progress: progress ?? this.progress,
    completed: completed ?? this.completed,
  );

  Map<String, dynamic> toMap() => {
    'workoutId': workoutId,
    'date': date.toIso8601String(),
    'durationSeconds': durationSeconds,
    'completed': completed ? 1 : 0,
  };

  static WorkoutSession fromMap(
    Map<String, Object?> map, {
    List<ExerciseProgress> progress = const [],
  }) => WorkoutSession(
    workoutId: map['workoutId'] as String,
    date: DateTime.parse(map['date'] as String),
    durationSeconds: (map['durationSeconds'] as num).toInt(),
    progress: progress,
    completed: (map['completed'] as num) == 1,
  );

  static String newId() => _randomId();
}

// Lightweight UUID-ish generator (fallback). In production prefer proper uuid package.
String _randomId() {
  final rand = Random.secure();
  return List<int>.generate(
    16,
    (_) => rand.nextInt(256),
  ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
