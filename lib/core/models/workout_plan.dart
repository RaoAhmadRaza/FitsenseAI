// lib/core/models/workout_plan.dart
// Workout plan template models (distinct from active WorkoutSession).
// Provides reusable structure (exercises, equipment, metadata) used when starting a session.
// Stored in Hive for fast access and mirrored (optionally) to SQLite.

import 'package:hive/hive.dart';
import 'dart:math';

// (No code generation; manual adapters below – keep this placeholder commented)
// part 'workout_plan.g.dart';

@HiveType(typeId: 13)
class PlanExercise extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String targetMuscle;
  @HiveField(3)
  final String imagePath; // local asset path
  @HiveField(4)
  final String gifUrl; // remote animation URL (optional if blank)
  @HiveField(5)
  final int sets;
  @HiveField(6)
  final int reps;
  @HiveField(7)
  final int? weight; // optional starting weight suggestion

  PlanExercise({
    required this.id,
    required this.name,
    required this.targetMuscle,
    required this.imagePath,
    required this.gifUrl,
    required this.sets,
    required this.reps,
    this.weight,
  });

  PlanExercise copyWith({
    String? id,
    String? name,
    String? targetMuscle,
    String? imagePath,
    String? gifUrl,
    int? sets,
    int? reps,
    int? weight,
  }) => PlanExercise(
    id: id ?? this.id,
    name: name ?? this.name,
    targetMuscle: targetMuscle ?? this.targetMuscle,
    imagePath: imagePath ?? this.imagePath,
    gifUrl: gifUrl ?? this.gifUrl,
    sets: sets ?? this.sets,
    reps: reps ?? this.reps,
    weight: weight ?? this.weight,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'target_muscle': targetMuscle,
    'image_path': imagePath,
    'gif_url': gifUrl,
    'sets': sets,
    'reps': reps,
    'weight': weight,
  };
}

@HiveType(typeId: 14)
class WorkoutPlan extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String level; // e.g., Beginner / Intermediate / Advanced
  @HiveField(3)
  final String durationDisplay; // e.g., "60 Min"
  @HiveField(4)
  final List<String> equipment; // lightweight list
  @HiveField(5)
  final List<PlanExercise> exercises;

  WorkoutPlan({
    required this.id,
    required this.name,
    required this.level,
    required this.durationDisplay,
    required this.equipment,
    required this.exercises,
  });

  WorkoutPlan copyWith({
    String? id,
    String? name,
    String? level,
    String? durationDisplay,
    List<String>? equipment,
    List<PlanExercise>? exercises,
  }) => WorkoutPlan(
    id: id ?? this.id,
    name: name ?? this.name,
    level: level ?? this.level,
    durationDisplay: durationDisplay ?? this.durationDisplay,
    equipment: equipment ?? this.equipment,
    exercises: exercises ?? this.exercises,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'level': level,
    'duration_display': durationDisplay,
  };

  static String newId() => _randId();
}

String _randId() {
  final r = Random.secure();
  return List<int>.generate(
    12,
    (_) => r.nextInt(256),
  ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

// ======================
// Manual Hive Adapters
// ======================

class PlanExerciseAdapter extends TypeAdapter<PlanExercise> {
  @override
  final int typeId = 13;

  @override
  PlanExercise read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return PlanExercise(
      id: fields[0] as String,
      name: fields[1] as String,
      targetMuscle: fields[2] as String,
      imagePath: fields[3] as String,
      gifUrl: fields[4] as String,
      sets: fields[5] as int,
      reps: fields[6] as int,
      weight: fields[7] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, PlanExercise obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.targetMuscle)
      ..writeByte(3)
      ..write(obj.imagePath)
      ..writeByte(4)
      ..write(obj.gifUrl)
      ..writeByte(5)
      ..write(obj.sets)
      ..writeByte(6)
      ..write(obj.reps)
      ..writeByte(7)
      ..write(obj.weight);
  }
}

class WorkoutPlanAdapter extends TypeAdapter<WorkoutPlan> {
  @override
  final int typeId = 14;

  @override
  WorkoutPlan read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return WorkoutPlan(
      id: fields[0] as String,
      name: fields[1] as String,
      level: fields[2] as String,
      durationDisplay: fields[3] as String,
      equipment: (fields[4] as List).cast<String>(),
      exercises: (fields[5] as List).cast<PlanExercise>(),
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutPlan obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.level)
      ..writeByte(3)
      ..write(obj.durationDisplay)
      ..writeByte(4)
      ..write(obj.equipment)
      ..writeByte(5)
      ..write(obj.exercises);
  }
}
