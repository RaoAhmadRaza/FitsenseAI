import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import 'package:ai_fitness_tracker/core/models/workout_plan.dart';
import 'package:ai_fitness_tracker/features/workout/data/workout_plan_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkoutPlanRepository', () {
    late WorkoutPlanRepository repo;

    setUp(() async {
      final dir = await Directory.systemTemp.createTemp('hive_plan_repo');
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(13))
        Hive.registerAdapter(PlanExerciseAdapter());
      if (!Hive.isAdapterRegistered(14))
        Hive.registerAdapter(WorkoutPlanAdapter());
      await Hive.openBox<WorkoutPlan>('workoutPlanBox');
      repo = WorkoutPlanRepository();
    });

    tearDown(() async {
      if (Hive.isBoxOpen('workoutPlanBox')) {
        await Hive.box<WorkoutPlan>('workoutPlanBox').deleteFromDisk();
      }
    });

    test('seeds default plans exactly once', () async {
      expect(repo.isSeeded, isFalse);
      await repo.seedDefaultsIfEmpty();
      final firstCount = (await repo.listPlans()).length;
      await repo.seedDefaultsIfEmpty();
      final secondCount = (await repo.listPlans()).length;
      expect(firstCount, greaterThan(0));
      expect(secondCount, equals(firstCount));
    });

    test('addExercise increases exercise count', () async {
      await repo.seedDefaultsIfEmpty();
      final plan = (await repo.listPlans()).first;
      final initial = plan.exercises.length;
      await repo.addExercise(
        plan.id,
        PlanExercise(
          id: 'temp_ex',
          name: 'Temp Exercise',
          targetMuscle: 'Test',
          imagePath: 'assets/images/bench.png',
          gifUrl: '',
          sets: 3,
          reps: 10,
          weight: 0,
        ),
      );
      final updatedPlan = repo.getPlan(plan.id)!;
      expect(updatedPlan.exercises.length, initial + 1);
    });
  });
}
