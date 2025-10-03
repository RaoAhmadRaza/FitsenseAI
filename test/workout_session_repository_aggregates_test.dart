import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:ai_fitness_tracker/core/models/workout_session.dart';
import 'package:ai_fitness_tracker/features/workout/data/workout_session_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkoutSessionRepository.getTotalMinutes', () {
    late Box<WorkoutSession> sessionBox;
    late WorkoutSessionRepository repo;

    setUp(() async {
      final dir = await Directory.systemTemp.createTemp('hive_test_sessions');
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(10)) {
        Hive.registerAdapter(ExerciseProgressAdapter());
      }
      if (!Hive.isAdapterRegistered(11)) {
        Hive.registerAdapter(WorkoutSessionAdapter());
      }
      sessionBox = await Hive.openBox<WorkoutSession>('sessionBox');
      repo = WorkoutSessionRepository();

      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      // Today completed: 1800s
      await sessionBox.add(WorkoutSession(
        workoutId: 't1',
        date: startOfToday.add(const Duration(hours: 1)),
        durationSeconds: 1800,
        progress: const [],
        completed: true,
      ));
      // Today ongoing: 600s (should not count in completed minutes)
      await sessionBox.add(WorkoutSession(
        workoutId: 't2',
        date: startOfToday.add(const Duration(hours: 2)),
        durationSeconds: 600,
        progress: const [],
        completed: false,
      ));
      // Yesterday completed: 3600s
      await sessionBox.add(WorkoutSession(
        workoutId: 'y1',
        date: startOfToday.subtract(const Duration(days: 1)).add(const Duration(hours: 3)),
        durationSeconds: 3600,
        progress: const [],
        completed: true,
      ));
      // 8 days ago completed: 600s (outside 7-day window)
      await sessionBox.add(WorkoutSession(
        workoutId: 'old1',
        date: startOfToday.subtract(const Duration(days: 8)),
        durationSeconds: 600,
        progress: const [],
        completed: true,
      ));
    });

    tearDown(() async {
      if (Hive.isBoxOpen('sessionBox')) {
        await Hive.box<WorkoutSession>('sessionBox').deleteFromDisk();
      }
    });

    test('today only', () async {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));
      final minutes = await repo.getTotalMinutes(from: start, to: end);
      expect(minutes, 30); // 1800s => 30m
    });

    test('last 7 days', () async {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      final end = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      final minutes = await repo.getTotalMinutes(from: start, to: end);
      expect(minutes, 90); // today 30m + yesterday 60m
    });

    test('all time', () async {
      final minutes = await repo.getTotalMinutes();
      expect(minutes, 100); // 30 + 60 + 10 (8 days ago) = 100m
    });
  });
}
