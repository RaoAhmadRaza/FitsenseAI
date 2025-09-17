import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ai_fitness_tracker/logic/session/session_cubit.dart';
import 'package:ai_fitness_tracker/logic/workouts/workouts_cubit.dart';

class MockSessionCubit extends Mock implements SessionCubit {}

class MockWorkoutsCubit extends Mock implements WorkoutsCubit {}

Widget pumpWithScaffolding({
  required Widget child,
  SessionCubit? sessionCubit,
  WorkoutsCubit? workoutsCubit,
}) {
  return MultiBlocProvider(
    providers: [
      if (sessionCubit != null)
        BlocProvider<SessionCubit>.value(value: sessionCubit),
      if (workoutsCubit != null)
        BlocProvider<WorkoutsCubit>.value(value: workoutsCubit),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}
