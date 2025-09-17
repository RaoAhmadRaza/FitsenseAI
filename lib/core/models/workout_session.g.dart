// Manually written Hive adapters (no build_runner needed for now).
// If switching to build_runner later, remove manual code and run generator.

part of 'workout_session.dart';

class ExerciseProgressAdapter extends TypeAdapter<ExerciseProgress> {
  @override
  final int typeId = 10;

  @override
  ExerciseProgress read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return ExerciseProgress(
      exerciseId: fields[0] as String,
      completedSets: fields[1] as int,
      completedReps: fields[2] as int,
      usedWeight: fields[3] as int,
      timeSpentSeconds: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ExerciseProgress obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.exerciseId)
      ..writeByte(1)
      ..write(obj.completedSets)
      ..writeByte(2)
      ..write(obj.completedReps)
      ..writeByte(3)
      ..write(obj.usedWeight)
      ..writeByte(4)
      ..write(obj.timeSpentSeconds);
  }
}

class WorkoutSessionAdapter extends TypeAdapter<WorkoutSession> {
  @override
  final int typeId = 11;

  @override
  WorkoutSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return WorkoutSession(
      workoutId: fields[0] as String,
      date: fields[1] as DateTime,
      durationSeconds: fields[2] as int,
      progress: (fields[3] as List).cast<ExerciseProgress>(),
      completed: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutSession obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.workoutId)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.durationSeconds)
      ..writeByte(3)
      ..write(obj.progress)
      ..writeByte(4)
      ..write(obj.completed);
  }
}
