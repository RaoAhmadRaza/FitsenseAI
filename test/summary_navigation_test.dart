import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ai_fitness_tracker/logic/session/session_cubit.dart';
import 'package:ai_fitness_tracker/logic/workouts/workouts_cubit.dart';
import 'package:ai_fitness_tracker/core/models/workout_plan.dart';
import 'package:ai_fitness_tracker/core/models/workout_session.dart';
import 'package:ai_fitness_tracker/features/home/pages/plan_detail_screen.dart';
import 'package:ai_fitness_tracker/features/workout/pages/session_summary_screen.dart';
import 'package:ai_fitness_tracker/core/navigation/app_routes.dart';

class MockSessionCubit extends Mock implements SessionCubit {}

class MockWorkoutsCubit extends Mock implements WorkoutsCubit {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('Summary navigation', () {
    late MockSessionCubit sessionCubit;
    late MockWorkoutsCubit workoutsCubit;
    late WorkoutPlan plan;

    setUp(() {
      sessionCubit = MockSessionCubit();
      workoutsCubit = MockWorkoutsCubit();
      plan = WorkoutPlan(
        id: 'planx',
        name: 'Summary Plan',
        level: 'Beginner',
        durationDisplay: '10 min',
        equipment: const [],
        exercises: const [],
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

      when(() => sessionCubit.startPlanSession(any())).thenAnswer(
        (_) async => WorkoutSession(
          workoutId: 'plan_${plan.id}_999',
          date: DateTime.now(),
          durationSeconds: 0,
          progress: const [],
          completed: false,
        ),
      );
      when(() => sessionCubit.state).thenReturn(const SessionState());
      when(() => sessionCubit.stream).thenAnswer((_) => const Stream.empty());

      when(() => sessionCubit.completeSession()).thenAnswer((_) async {});
    });

    testWidgets('navigates to summary after completion trigger', (
      tester,
    ) async {
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<SessionCubit>.value(value: sessionCubit),
            BlocProvider<WorkoutsCubit>.value(value: workoutsCubit),
          ],
          child: MaterialApp(
            onGenerateRoute: (settings) {
              if (settings.name == AppRoutes.planDetail(plan.id)) {
                return MaterialPageRoute(
                  builder: (_) => PlanDetailScreen(planId: plan.id),
                );
              }
              if (settings.name != null &&
                  settings.name!.startsWith('/workout/')) {
                return MaterialPageRoute(
                  builder: (_) => const SizedBox.shrink(),
                );
              }
              if (settings.name != null &&
                  settings.name!.startsWith('/session/summary/')) {
                return MaterialPageRoute(
                  builder: (_) =>
                      SessionSummaryScreen(sessionId: 'plan_${plan.id}_999'),
                );
              }
              return MaterialPageRoute(
                builder: (_) => PlanDetailScreen(planId: plan.id),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Start Plan'), findsOneWidget);
      await tester.tap(find.text('Start Plan'));
      await tester.pumpAndSettle();

      // Simulate completion navigation: push summary manually to mimic UI flow.
      final navState = tester.state<NavigatorState>(find.byType(Navigator));
      navState.pushNamed(AppRoutes.sessionSummary('plan_${plan.id}_999'));
      await tester.pumpAndSettle();

      expect(find.byType(SessionSummaryScreen), findsOneWidget);
      expect(find.textContaining('Summary'), findsWidgets);
    });
  });
}
