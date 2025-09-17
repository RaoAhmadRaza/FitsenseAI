import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ai_fitness_tracker/logic/workouts/workouts_cubit.dart';
import 'package:ai_fitness_tracker/logic/session/session_cubit.dart';
import 'package:ai_fitness_tracker/core/models/workout_plan.dart';
import 'package:ai_fitness_tracker/core/models/workout_session.dart';
import 'package:ai_fitness_tracker/features/home/pages/plan_detail_screen.dart';
import 'package:ai_fitness_tracker/core/navigation/app_routes.dart';

class MockWorkoutsCubit extends Mock implements WorkoutsCubit {}

class MockSessionCubit extends Mock implements SessionCubit {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Start Plan Integration', () {
    late MockWorkoutsCubit workoutsCubit;
    late MockSessionCubit sessionCubit;
    late WorkoutPlan plan;

    setUp(() {
      workoutsCubit = MockWorkoutsCubit();
      sessionCubit = MockSessionCubit();

      plan = WorkoutPlan(
        id: 'plan123abc',
        name: 'Full Body Intro',
        level: 'Beginner',
        durationDisplay: '30 min',
        equipment: const ['Mat'],
        exercises: [
          PlanExercise(
            id: 'ex1',
            name: 'Push Ups',
            targetMuscle: 'Chest',
            imagePath: 'assets/images/bench.png',
            gifUrl: '',
            sets: 2,
            reps: 8,
          ),
          PlanExercise(
            id: 'ex2',
            name: 'Bodyweight Squat',
            targetMuscle: 'Legs',
            imagePath: 'assets/images/bench.png',
            gifUrl: '',
            sets: 2,
            reps: 10,
          ),
        ],
      );

      final readyState = WorkoutsState(
        status: WorkoutsStatus.ready,
        plans: [plan],
        selectedPlanId: null,
        errorMessage: null,
      );
      when(() => workoutsCubit.state).thenReturn(readyState);
      when(
        () => workoutsCubit.stream,
      ).thenAnswer((_) => Stream.value(readyState));

      // Mock startPlanSession returning a fake session object minimal shape.
      when(() => sessionCubit.startPlanSession(any())).thenAnswer((
        invocation,
      ) async {
        return WorkoutSession(
          workoutId: 'plan_${plan.id}_123456789',
          date: DateTime.now(),
          durationSeconds: 0,
          progress: const [],
          completed: false,
        );
      });
      when(() => sessionCubit.state).thenReturn(const SessionState());
      when(() => sessionCubit.stream).thenAnswer((_) => const Stream.empty());
      when(() => sessionCubit.refresh()).thenAnswer((_) async {});
    });
    setUpAll(() {
      registerFallbackValue(
        WorkoutPlan(
          id: 'fallback',
          name: 'Fallback',
          level: 'Beginner',
          durationDisplay: '0',
          equipment: const [],
          exercises: const [],
        ),
      );
    });

    testWidgets('taps Start Plan -> navigates to workout screen with queue', (
      tester,
    ) async {
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<WorkoutsCubit>.value(value: workoutsCubit),
            BlocProvider<SessionCubit>.value(value: sessionCubit),
          ],
          child: MaterialApp(
            onGenerateRoute: (settings) {
              if (settings.name == AppRoutes.planDetail('plan123abc')) {
                return MaterialPageRoute(
                  builder: (_) => const PlanDetailScreen(planId: 'plan123abc'),
                );
              }
              if (settings.name != null &&
                  settings.name!.startsWith('/workout/')) {
                return MaterialPageRoute(
                  builder: (_) =>
                      const Scaffold(body: Text('Workout Placeholder')),
                );
              }
              return MaterialPageRoute(
                builder: (_) => const PlanDetailScreen(planId: 'plan123abc'),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify we are on detail and button exists.
      expect(find.text('Start Plan'), findsOneWidget);

      await tester.tap(find.text('Start Plan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should have navigated; verify placeholder present.
      expect(find.text('Workout Placeholder'), findsOneWidget);

      // Verify startPlanSession called.
      verify(() => sessionCubit.startPlanSession(any())).called(1);
    });
  });
}

// Minimal WorkoutSession model inline (test-only) if not imported. Adjust import if exists.
// (No test-only stand-in needed now that real model is imported.)
