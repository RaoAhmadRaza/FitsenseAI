import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ai_fitness_tracker/logic/workouts/workouts_cubit.dart';
import 'package:ai_fitness_tracker/core/models/workout_plan.dart';
import 'package:ai_fitness_tracker/features/home/pages/plan_detail_screen.dart';

class MockWorkoutsCubit extends Mock implements WorkoutsCubit {}

void main() {
  // No global fallback needed; we stub state & stream directly.

  group('PlanDetailScreen', () {
    late MockWorkoutsCubit workoutsCubit;
    late WorkoutPlan plan;

    setUp(() {
      workoutsCubit = MockWorkoutsCubit();
      plan = WorkoutPlan(
        id: 'p1',
        name: 'Upper Body Blast',
        level: 'Intermediate',
        durationDisplay: '35 min',
        equipment: const ['Dumbbells'],
        exercises: [
          PlanExercise(
            id: 'e1',
            name: 'Bench Press',
            sets: 3,
            reps: 10,
            targetMuscle: 'Chest',
            imagePath: 'assets/images/bench.png',
            gifUrl: '',
            weight: 50,
          ),
          PlanExercise(
            id: 'e2',
            name: 'Dumbbell Row',
            sets: 3,
            reps: 12,
            targetMuscle: 'Back',
            imagePath: 'assets/images/dumbbell.png',
            gifUrl: '',
            weight: 30,
          ),
        ],
      );
    });

    testWidgets('renders metadata & exercise count', (tester) async {
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

      await tester.pumpWidget(
        BlocProvider<WorkoutsCubit>.value(
          value: workoutsCubit,
          child: const MaterialApp(home: PlanDetailScreen(planId: 'p1')),
        ),
      );

      // Wait a frame.
      await tester.pump();

      expect(find.text('Upper Body Blast'), findsOneWidget);
      expect(find.text('Level'), findsOneWidget);
      expect(find.text('Intermediate'), findsOneWidget);
      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('35 min'), findsOneWidget);
      expect(find.text('Equipment'), findsOneWidget);
      expect(find.textContaining('Dumbbells'), findsOneWidget);
      expect(find.text('Exercises (2)'), findsOneWidget);
      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('Dumbbell Row'), findsOneWidget);
    });
  });
}
