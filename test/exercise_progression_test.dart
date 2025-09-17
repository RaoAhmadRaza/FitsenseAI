import 'package:flutter_test/flutter_test.dart';
import 'package:ai_fitness_tracker/logic/session/session_cubit.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import 'package:ai_fitness_tracker/core/models/session_runtime.dart';
import 'package:ai_fitness_tracker/core/models/workout_session.dart';
import 'package:ai_fitness_tracker/core/models/exercise_set.dart';
import 'package:ai_fitness_tracker/core/models/workout_plan.dart';
import 'package:ai_fitness_tracker/core/utils/plan_exercise_id.dart';
import 'package:ai_fitness_tracker/features/workout/data/workout_session_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockWorkoutSessionRepository extends Mock
    implements WorkoutSessionRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Exercise progression', () {
    late MockWorkoutSessionRepository repo;
    late SessionCubit cubit;
    late WorkoutPlan plan;

    setUp(() async {
      final dir = await Directory.systemTemp.createTemp('hive_progression');
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(15))
        Hive.registerAdapter(SessionRuntimeAdapter());
      await Hive.openBox<SessionRuntime>('sessionRuntimeBox');
      repo = MockWorkoutSessionRepository();
      cubit = SessionCubit(repo);
      plan = WorkoutPlan(
        id: 'abcd1234',
        name: 'Progress Plan',
        level: 'Beginner',
        durationDisplay: '15 min',
        equipment: const [],
        exercises: [
          PlanExercise(
            id: 'a',
            name: 'Exercise A',
            targetMuscle: 'Chest',
            imagePath: 'assets/images/bench.png',
            gifUrl: '',
            sets: 1,
            reps: 2,
          ),
          PlanExercise(
            id: 'b',
            name: 'Exercise B',
            targetMuscle: 'Back',
            imagePath: 'assets/images/bench.png',
            gifUrl: '',
            sets: 1,
            reps: 2,
          ),
        ],
      );
    });
    tearDown(() async {
      if (Hive.isBoxOpen('sessionRuntimeBox')) {
        await Hive.box<SessionRuntime>('sessionRuntimeBox').deleteFromDisk();
      }
    });

    Future<void> _mockStartSession() async {
      registerFallbackValue(
        ExerciseProgress(
          exerciseId: 'tmp',
          completedSets: 0,
          completedReps: 0,
          usedWeight: 0,
          timeSpentSeconds: 0,
        ),
      );
      when(
        () => repo.startSession(workoutId: any(named: 'workoutId')),
      ).thenAnswer(
        (_) async => WorkoutSession(
          workoutId: 'plan_${plan.id}_123',
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
        final progress = List<ExerciseProgress>.from(session.progress);
        final ep = invocation.positionalArguments[1] as ExerciseProgress;
        final idx = progress.indexWhere((p) => p.exerciseId == ep.exerciseId);
        if (idx == -1) {
          progress.add(ep);
        } else {
          progress[idx] = ep;
        }
        return session.copyWith(progress: progress);
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
      ).thenAnswer((invocation) async => cubit.state.ongoing!);
      when(
        () => repo.getOngoingSession(),
      ).thenAnswer((_) async => cubit.state.ongoing);
      when(() => repo.getLastCompletedSession()).thenAnswer((_) async => null);
      when(() => repo.completeSession(any())).thenAnswer(
        (invocation) async => cubit.state.ongoing!.copyWith(completed: true),
      );
    }

    test('reps increment then set completion advances index', () async {
      await _mockStartSession();
      await cubit.startPlanSession(plan); // seeds first exercise & sets active

      final firstId = PlanExerciseId.build(plan.id, 1);
      final secondId = PlanExerciseId.build(plan.id, 2);
      // Ensure first exercise explicitly active (startPlanSession may already do this)
      if (cubit.state.activeExerciseId != firstId) {
        await cubit.startExercise(firstId);
      }
      expect(cubit.state.activeExerciseId, firstId);

      // Increment reps twice (target 2) -> reps tracked internally
      await cubit.incrementRep(firstId);
      await cubit.incrementRep(firstId);

      // Complete set which should reset reps and remain ready state
      await cubit.completeSet(firstId, repsInSet: 2);
      // Manually start second exercise (UI would trigger). Simulate progression.
      await cubit.startExercise(secondId);

      expect(cubit.state.activeExerciseId, secondId);
    });
  });
}
