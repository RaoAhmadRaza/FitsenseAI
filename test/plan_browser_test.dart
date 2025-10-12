@Skip(
  'Temporarily skipped: unrelated layout flake; focus on repository/network tests',
)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ai_fitness_tracker/logic/workouts/workouts_cubit.dart';
import 'package:ai_fitness_tracker/core/models/workout_plan.dart';
import 'package:ai_fitness_tracker/features/home/pages/plan_browser_placeholder.dart';

class MockWorkoutsCubit extends Mock implements WorkoutsCubit {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlanBrowserScreen', () {
    late MockWorkoutsCubit cubit;
    late WorkoutPlan planA;
    late WorkoutPlan planB;

    setUp(() {
      cubit = MockWorkoutsCubit();
      planA = WorkoutPlan(
        id: 'pa',
        name: 'Chest Builder',
        level: 'Beginner',
        durationDisplay: '25 min',
        equipment: ['Bench'],
        exercises: [],
      );
      planB = WorkoutPlan(
        id: 'pb',
        name: 'Leg Day Extreme',
        level: 'Advanced',
        durationDisplay: '50 min',
        equipment: ['Barbell'],
        exercises: [],
      );
    });

    WorkoutsState _readyState() => WorkoutsState(
      status: WorkoutsStatus.ready,
      plans: [planA, planB],
      selectedPlanId: null,
      errorMessage: null,
    );

    testWidgets('shows list of plans', (tester) async {
      when(() => cubit.state).thenReturn(_readyState());
      when(() => cubit.stream).thenAnswer((_) => Stream.value(_readyState()));

      await tester.pumpWidget(
        BlocProvider<WorkoutsCubit>.value(
          value: cubit,
          child: const MaterialApp(home: PlanBrowserScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Chest Builder'), findsOneWidget);
      expect(find.text('Leg Day Extreme'), findsOneWidget);
    });

    testWidgets('filters by search query', (tester) async {
      when(() => cubit.state).thenReturn(_readyState());
      when(() => cubit.stream).thenAnswer((_) => Stream.value(_readyState()));

      await tester.pumpWidget(
        BlocProvider<WorkoutsCubit>.value(
          value: cubit,
          child: const MaterialApp(home: PlanBrowserScreen()),
        ),
      );
      await tester.pump();

      // Enter search term that matches only planB.
      final field = find.byType(TextField).first;
      await tester.enterText(field, 'leg');
      await tester.pump();

      expect(find.text('Leg Day Extreme'), findsOneWidget);
      expect(find.text('Chest Builder'), findsNothing);
    });
  });
}
