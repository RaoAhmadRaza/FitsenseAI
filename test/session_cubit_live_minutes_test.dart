import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:ai_fitness_tracker/core/models/workout_session.dart';
import 'package:ai_fitness_tracker/core/models/session_runtime.dart';
import 'package:ai_fitness_tracker/features/workout/data/workout_session_repository.dart';
import 'package:ai_fitness_tracker/logic/session/session_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionCubit live minutes ticks & pauses', () {
    late WorkoutSessionRepository repo;
    late SessionCubit cubit;

    setUp(() async {
      final dir = await Directory.systemTemp.createTemp('hive_test_live');
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(10))
        Hive.registerAdapter(ExerciseProgressAdapter());
      if (!Hive.isAdapterRegistered(11))
        Hive.registerAdapter(WorkoutSessionAdapter());
      if (!Hive.isAdapterRegistered(15))
        Hive.registerAdapter(SessionRuntimeAdapter());
      await Hive.openBox<WorkoutSession>('sessionBox');
      await Hive.openBox<SessionRuntime>('sessionRuntimeBox');
      repo = WorkoutSessionRepository();
      cubit = SessionCubit(repo);
    });

    tearDown(() async {
      await cubit.close();
      if (Hive.isBoxOpen('sessionRuntimeBox'))
        await Hive.box<SessionRuntime>('sessionRuntimeBox').deleteFromDisk();
      if (Hive.isBoxOpen('sessionBox'))
        await Hive.box<WorkoutSession>('sessionBox').deleteFromDisk();
    });

    test(
      'ticks up while running, stays frozen when paused',
      () async {
        await repo.startSession(workoutId: 'live_1');
        // seed cubit state
        await cubit.refresh();

        final initial = cubit.state.ongoing?.durationSeconds ?? 0;
        expect(initial, 0);

        // wait slightly more than one tick (5s)
        await Future.delayed(const Duration(seconds: 6));
        final afterTick = cubit.state.ongoing?.durationSeconds ?? 0;
        expect(afterTick >= initial + 5, true);

        // Pause and wait another 5s; value should stay the same
        await cubit.pauseSession();
        final pausedValue = cubit.state.ongoing?.durationSeconds ?? 0;
        await Future.delayed(const Duration(seconds: 6));
        final afterPauseWait = cubit.state.ongoing?.durationSeconds ?? 0;
        expect(afterPauseWait, pausedValue);
      },
      timeout: Timeout(const Duration(seconds: 25)),
    );
  });
}
