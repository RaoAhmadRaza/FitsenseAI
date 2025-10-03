import 'dart:io';

import 'package:ai_fitness_tracker/core/models/session_runtime.dart';
import 'package:ai_fitness_tracker/core/models/workout_session.dart';
import 'package:ai_fitness_tracker/logic/session/session_cubit.dart';
import 'package:ai_fitness_tracker/features/workout/data/workout_session_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

class MockWorkoutSessionRepository extends Mock
    implements WorkoutSessionRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionCubit pause/restart/resume', () {
    late Directory tempDir;
    late MockWorkoutSessionRepository repo;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_session_cubit');
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(15)) {
        Hive.registerAdapter(SessionRuntimeAdapter());
      }
      if (!Hive.isAdapterRegistered(10)) {
        Hive.registerAdapter(ExerciseProgressAdapter());
      }
      if (!Hive.isAdapterRegistered(11)) {
        Hive.registerAdapter(WorkoutSessionAdapter());
      }
      await Hive.openBox<SessionRuntime>('sessionRuntimeBox');
      repo = MockWorkoutSessionRepository();
    });

    tearDown(() async {
      if (Hive.isBoxOpen('sessionRuntimeBox')) {
        await Hive.box<SessionRuntime>('sessionRuntimeBox').deleteFromDisk();
      }
      await Hive.close();
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    test(
      'Start → pause → restart app → resume → durationSeconds should not jump',
      () async {
        // Arrange initial session: started 2 hours ago but only 60s duration recorded
        final startTime = DateTime.now().subtract(const Duration(hours: 2));
        final session = WorkoutSession(
          workoutId: 'w1',
          date: startTime,
          durationSeconds: 60,
          progress: const [],
          completed: false,
        );

        // Seed runtime as paused before refresh (simulating user paused before app kill)
        final runtimeBox = Hive.box<SessionRuntime>('sessionRuntimeBox');
        await runtimeBox.put(
          session.workoutId,
          SessionRuntime(
            sessionWorkoutId: session.workoutId,
            currentExerciseIndex: 1,
            currentRound: 1,
            currentRepsInSet: 0,
            // If this were non-null, refresh() should clear it while paused
            exerciseStartedAt: startTime.add(const Duration(minutes: 1)),
            accumulatedExerciseSeconds: 40,
            mode: 'exercising',
            updatedAt: DateTime.now(),
            paused: true,
            pausedAt: DateTime.now(),
            planId: null,
          ),
        );

        // Repository returns the ongoing session; make updateDuration observable
        when(() => repo.getOngoingSession()).thenAnswer((_) async => session);
        when(
          () => repo.getLastCompletedSession(),
        ).thenAnswer((_) async => null);
        when(() => repo.updateDuration(any(), any())).thenAnswer((
          invocation,
        ) async {
          final delta = invocation.positionalArguments[1] as int;
          return session.copyWith(
            durationSeconds: session.durationSeconds + delta,
          );
        });

        // Act 1: First app boot -> refresh should NOT reconcile while paused
        final cubit1 = SessionCubit(repo);
        await cubit1.refresh();

        // Assert 1: duration unchanged and updateDuration not called
        expect(cubit1.state.ongoing?.durationSeconds, 60);
        verifyNever(() => repo.updateDuration(any(), any()));

        // Also assert refresh cleared stale exerciseStartedAt while paused
        final rtAfterRefresh = runtimeBox.get(session.workoutId);
        expect(rtAfterRefresh?.paused, isTrue);
        expect(rtAfterRefresh?.exerciseStartedAt, isNull);

        // Simulate app restart: dispose cubit and create a new one reusing same Hive dir
        await cubit1.close();

        // Act 2: New app instance boot -> refresh again (still paused)
        final cubit2 = SessionCubit(repo);
        await cubit2.refresh();
        expect(cubit2.state.ongoing?.durationSeconds, 60);
        verifyNever(() => repo.updateDuration(any(), any()));

        // Act 3: User resumes session
        await cubit2.resumeSession();

        // Immediately verify no jump occurred on resume (before any ticker tick)
        expect(cubit2.state.ongoing?.durationSeconds, 60);

        // Cleanup
        await cubit2.close();
      },
    );
  });
}
