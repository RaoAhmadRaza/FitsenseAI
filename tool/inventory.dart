// dart run tool/inventory.dart
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';

Future<void> main() async {
  print('== Inventory: Hive Boxes ==');
  try {
    await Hive.initFlutter();
    for (final name in [
      'userBox',
      'sessionBox',
      'exerciseSetBox',
      'workoutPlanBox',
      'sessionRuntimeBox',
      'mealBox',
      'sensorSampleBox',
    ]) {
      try {
        if (!Hive.isBoxOpen(name)) {
          await Hive.openBox(name);
        }
        print(
          'Hive box: $name (entries: ' + Hive.box(name).length.toString() + ')',
        );
      } catch (_) {
        print('Hive box: $name (unavailable)');
      }
    }
  } catch (e) {
    print('Hive init error: $e');
  }

  print('\n== Inventory: SQLite ==');
  // This tool is offline; we can only list expected tables by convention.
  const tables = [
    'user_profile',
    'workouts',
    'workout_sessions',
    'exercise_sets',
    'exercise_progress',
    'workout_plans',
    'workout_plan_exercises',
    'workout_plan_equipment',
    'meals',
  ];
  for (final t in tables) {
    print('SQLite table (expected): $t');
  }

  // Exit cleanly for CI
  exit(0);
}
