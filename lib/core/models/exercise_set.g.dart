// Manual Hive adapter for ExerciseSet.
part of 'exercise_set.dart';

class ExerciseSetAdapter extends TypeAdapter<ExerciseSet> {
  @override
  final int typeId = 12;

  @override
  ExerciseSet read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return ExerciseSet(
      sessionWorkoutId: fields[0] as String,
      exerciseId: fields[1] as String,
      setIndex: fields[2] as int,
      reps: fields[3] as int,
      weight: fields[4] as int,
      durationSeconds: fields[5] as int,
      recordedAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ExerciseSet obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.sessionWorkoutId)
      ..writeByte(1)
      ..write(obj.exerciseId)
      ..writeByte(2)
      ..write(obj.setIndex)
      ..writeByte(3)
      ..write(obj.reps)
      ..writeByte(4)
      ..write(obj.weight)
      ..writeByte(5)
      ..write(obj.durationSeconds)
      ..writeByte(6)
      ..write(obj.recordedAt);
  }
}
