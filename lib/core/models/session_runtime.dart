import 'package:hive/hive.dart';

/// Ephemeral (but persisted) runtime state to allow accurate resume of an in-progress workout screen
/// without embedding UI-specific ephemeral fields into the core WorkoutSession model.
///
/// This model is intentionally lightweight and can be discarded/recreated without harming
/// authoritative progress data (sets/reps) which lives in WorkoutSession / ExerciseProgress.
@HiveType(typeId: 15)
class SessionRuntime extends HiveObject {
  @HiveField(0)
  String sessionWorkoutId;
  @HiveField(1)
  int currentExerciseIndex; // 1-based index matching synthetic exercise_<n>
  @HiveField(2)
  int currentRound; // 1-based
  @HiveField(3)
  int currentRepsInSet; // reps accumulated in the active (not yet completed) set
  @HiveField(4)
  DateTime? exerciseStartedAt; // when current exercise (set) timing began
  @HiveField(5)
  int accumulatedExerciseSeconds; // carry-over seconds if timer paused / screen left
  @HiveField(6)
  String mode; // 'ready' | 'exercising' | 'resting'
  @HiveField(7)
  DateTime updatedAt;
  @HiveField(8)
  bool paused; // whether session (and exercise timer) are paused
  @HiveField(9)
  DateTime? pausedAt; // when pause initiated
  @HiveField(10)
  String? planId; // nullable: present for plan-derived sessions

  SessionRuntime({
    required this.sessionWorkoutId,
    required this.currentExerciseIndex,
    required this.currentRound,
    required this.currentRepsInSet,
    required this.exerciseStartedAt,
    required this.accumulatedExerciseSeconds,
    required this.mode,
    required this.updatedAt,
    this.paused = false,
    this.pausedAt,
    this.planId,
  });

  SessionRuntime copyWith({
    int? currentExerciseIndex,
    int? currentRound,
    int? currentRepsInSet,
    DateTime? exerciseStartedAt,
    int? accumulatedExerciseSeconds,
    String? mode,
    DateTime? updatedAt,
    bool? paused,
    DateTime? pausedAt,
    String? planId,
  }) => SessionRuntime(
    sessionWorkoutId: sessionWorkoutId,
    currentExerciseIndex: currentExerciseIndex ?? this.currentExerciseIndex,
    currentRound: currentRound ?? this.currentRound,
    currentRepsInSet: currentRepsInSet ?? this.currentRepsInSet,
    exerciseStartedAt: exerciseStartedAt ?? this.exerciseStartedAt,
    accumulatedExerciseSeconds:
        accumulatedExerciseSeconds ?? this.accumulatedExerciseSeconds,
    mode: mode ?? this.mode,
    updatedAt: updatedAt ?? DateTime.now(),
    paused: paused ?? this.paused,
    pausedAt: pausedAt ?? this.pausedAt,
    planId: planId ?? this.planId,
  );
}

class SessionRuntimeAdapter extends TypeAdapter<SessionRuntime> {
  @override
  final int typeId = 15;

  @override
  SessionRuntime read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return SessionRuntime(
      sessionWorkoutId: fields[0] as String,
      currentExerciseIndex: fields[1] as int,
      currentRound: fields[2] as int,
      currentRepsInSet: fields[3] as int,
      exerciseStartedAt: fields[4] as DateTime?,
      accumulatedExerciseSeconds: fields[5] as int,
      mode: fields[6] as String,
      updatedAt: fields[7] as DateTime,
      paused: fields[8] as bool? ?? false,
      pausedAt: fields[9] as DateTime?,
      planId: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SessionRuntime obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.sessionWorkoutId)
      ..writeByte(1)
      ..write(obj.currentExerciseIndex)
      ..writeByte(2)
      ..write(obj.currentRound)
      ..writeByte(3)
      ..write(obj.currentRepsInSet)
      ..writeByte(4)
      ..write(obj.exerciseStartedAt)
      ..writeByte(5)
      ..write(obj.accumulatedExerciseSeconds)
      ..writeByte(6)
      ..write(obj.mode)
      ..writeByte(7)
      ..write(obj.updatedAt)
      ..writeByte(8)
      ..write(obj.paused)
      ..writeByte(9)
      ..write(obj.pausedAt)
      ..writeByte(10)
      ..write(obj.planId);
  }
}
