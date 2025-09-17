import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'dart:io';

import 'package:ai_fitness_tracker/core/models/workout_session.dart';
import 'package:ai_fitness_tracker/core/models/exercise_set.dart';
import 'package:ai_fitness_tracker/features/workout/data/workout_session_repository.dart';
import 'package:ai_fitness_tracker/core/models/session_runtime.dart';
import 'package:ai_fitness_tracker/logic/session/session_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionCubit workflow', () {
    late WorkoutSessionRepository repo;
    late SessionCubit cubit;

    setUp(() async {
      final dir = await Directory.systemTemp.createTemp('hive_session_cubit');
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(10))
        Hive.registerAdapter(ExerciseProgressAdapter());
      if (!Hive.isAdapterRegistered(11))
        Hive.registerAdapter(WorkoutSessionAdapter());
      if (!Hive.isAdapterRegistered(12))
        Hive.registerAdapter(ExerciseSetAdapter());
      if (!Hive.isAdapterRegistered(15))
        Hive.registerAdapter(SessionRuntimeAdapter());
      await Hive.openBox<WorkoutSession>('sessionBox');
      await Hive.openBox<ExerciseSet>('exerciseSetBox');
      await Hive.openBox<SessionRuntime>('sessionRuntimeBox');
      repo = WorkoutSessionRepository();
      // start a session to operate on
      await repo.startSession(workoutId: 'session_1');
      cubit = SessionCubit(repo);
      await cubit.refresh();
    });

    tearDown(() async {
      if (Hive.isBoxOpen('sessionBox')) {
        await Hive.box<WorkoutSession>('sessionBox').deleteFromDisk();
      }
      if (Hive.isBoxOpen('exerciseSetBox')) {
        await Hive.box<ExerciseSet>('exerciseSetBox').deleteFromDisk();
      }
      if (Hive.isBoxOpen('sessionRuntimeBox')) {
        await Hive.box<SessionRuntime>('sessionRuntimeBox').deleteFromDisk();
      }
      await cubit.close();
    });

    test('start -> reps -> set -> complete session', () async {
      // Start exercise
      await cubit.startExercise('exercise_1');
      expect(
        cubit.state.ongoing!.progress
            .where((p) => p.exerciseId == 'exercise_1')
            .length,
        1,
      );

      // Increment reps 5 times
      for (var i = 0; i < 5; i++) {
        await cubit.incrementRep('exercise_1');
      }
      final pAfterReps = cubit.state.ongoing!.progress.firstWhere(
        (p) => p.exerciseId == 'exercise_1',
      );
      expect(pAfterReps.completedReps, 5);

      // Complete set with 5 reps (should now have completedSets = 1 and reps = 10 total)
      await cubit.completeSet(
        'exercise_1',
        repsInSet: 5,
        weight: 50,
        durationSeconds: 30,
      );
      final pAfterSet = cubit.state.ongoing!.progress.firstWhere(
        (p) => p.exerciseId == 'exercise_1',
      );
      expect(pAfterSet.completedSets, 1);
      expect(pAfterSet.completedReps, 10); // cumulative reps (5 + 5)

      // Complete session
      await cubit.completeSession();
      expect(cubit.state.ongoing!.completed, true);
    });
  });
}
