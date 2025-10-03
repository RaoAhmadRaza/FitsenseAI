import 'package:flutter_test/flutter_test.dart';
import 'package:ai_fitness_tracker/logic/session/session_cubit.dart';
import 'package:ai_fitness_tracker/features/workout/data/workout_session_repository.dart';
import 'package:ai_fitness_tracker/core/models/workout_session.dart';
import 'package:ai_fitness_tracker/core/models/exercise_set.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import 'package:ai_fitness_tracker/core/models/session_runtime.dart';

class MockWorkoutSessionRepository extends Mock
    implements WorkoutSessionRepository {}

class FakeBox<T> extends Fake implements Box<T> {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseExerciseIndex (indirect)', () {
    late MockWorkoutSessionRepository repo;
    late SessionCubit cubit;

    setUp(() async {
      repo = MockWorkoutSessionRepository();
      cubit = SessionCubit(repo);
      // Initialize Hive in temp directory for runtime box
      final dir = await Directory.systemTemp.createTemp('hive_test_runtime');
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(15))
        Hive.registerAdapter(SessionRuntimeAdapter());
      await Hive.openBox<SessionRuntime>('sessionRuntimeBox');
      registerFallbackValue(
        ExerciseProgress(
          exerciseId: 'tmp',
          completedSets: 0,
          completedReps: 0,
          usedWeight: 0,
          timeSpentSeconds: 0,
        ),
      );
    });
    tearDown(() async {
      if (Hive.isBoxOpen('sessionRuntimeBox')) {
        await Hive.box<SessionRuntime>('sessionRuntimeBox').deleteFromDisk();
      }
    });

    Future<void> _mockStart(String id) async {
      when(
        () => repo.startSession(workoutId: any(named: 'workoutId')),
      ).thenAnswer(
        (_) async => WorkoutSession(
          workoutId: id,
          date: DateTime.now(),
          durationSeconds: 0,
          progress: const [],
          completed: false,
        ),
      );
      when(() => repo.upsertExerciseProgress(any(), any())).thenAnswer((
        invocation,
      ) async {
        final session = cubit.state.ongoing!;
        final list = List<ExerciseProgress>.from(session.progress);
        final ep = invocation.positionalArguments[1] as ExerciseProgress;
        final idx = list.indexWhere((p) => p.exerciseId == ep.exerciseId);
        if (idx == -1) {
          list.add(ep);
        } else {
          list[idx] = ep;
        }
        return session.copyWith(progress: list);
      });
      when(
        () => repo.addExerciseSet(
          sessionWorkoutId: any(named: 'sessionWorkoutId'),
          exerciseId: any(named: 'exerciseId'),
          setIndex: any(named: 'setIndex'),
          reps: any(named: 'reps'),
          weight: any(named: 'weight'),
          durationSeconds: any(named: 'durationSeconds'),
        ),
      ).thenAnswer(
        (invocation) async => ExerciseSet(
          sessionWorkoutId:
              invocation.namedArguments[#sessionWorkoutId] as String,
          exerciseId: invocation.namedArguments[#exerciseId] as String,
          setIndex: invocation.namedArguments[#setIndex] as int,
          reps: invocation.namedArguments[#reps] as int,
          weight: invocation.namedArguments[#weight] as int,
          durationSeconds: invocation.namedArguments[#durationSeconds] as int,
          recordedAt: DateTime.now(),
        ),
      );
      when(
        () => repo.updateDuration(any(), any()),
      ).thenAnswer((_) async => cubit.state.ongoing!);
      when(
        () => repo.getOngoingSession(),
      ).thenAnswer((_) async => cubit.state.ongoing);
      when(() => repo.getLastCompletedSession()).thenAnswer((_) async => null);
      when(
        () => repo.completeSession(any()),
      ).thenAnswer((_) async => cubit.state.ongoing!.copyWith(completed: true));
    }

    test('plan deterministic id parses index', () async {
      await _mockStart('plan_demo_1');
      await cubit.startSession('plan_demo_1');
      await cubit.startExercise('plan_deadbeefex3');
      final runtime = cubit.getRuntime(cubit.state.ongoing!.workoutId);
      expect(runtime?.currentExerciseIndex, 3);
    });

    test('fallback id with underscore uses last segment int', () async {
      await _mockStart('w_55');
      await cubit.startSession('w_55');
      await cubit.startExercise('exercise_7');
      final runtime = cubit.getRuntime(cubit.state.ongoing!.workoutId);
      expect(runtime?.currentExerciseIndex, 7);
    });

    test('invalid id defaults to 1', () async {
      await _mockStart('w_misc');
      await cubit.startSession('w_misc');
      await cubit.startExercise('nonsense');
      final runtime = cubit.getRuntime(cubit.state.ongoing!.workoutId);
      expect(runtime?.currentExerciseIndex, 1);
    });
  });
}
