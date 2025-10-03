import 'dart:async';
import 'package:hive/hive.dart';

import '../../../core/models/meal_entry.dart';

/// Minimal repository scaffolding for meals: Hive primary path + SQLite stubs.
class MealRepository {
  MealRepository();

  Box<MealEntry> get _box => Hive.box<MealEntry>('mealBox');

  Future<MealEntry> addMeal({
    required DateTime date,
    required String name,
    required int calories,
    required int proteinGrams,
    required int carbsGrams,
    required int fatGrams,
  }) async {
    final entry = MealEntry(
      id: MealEntry.newId(),
      date: date,
      name: name,
      calories: calories,
      proteinGrams: proteinGrams,
      carbsGrams: carbsGrams,
      fatGrams: fatGrams,
    );
    await _box.add(entry);
    // TODO: mirror to SQLite via AppDatabase (stub)
    unawaited(_mirrorInsert(entry));
    return entry;
  }

  Future<List<MealEntry>> listMealsByDay(DateTime day) async {
    final d0 = DateTime(day.year, day.month, day.day);
    final d1 = d0.add(const Duration(days: 1));
    final list = _box.values
        .where((m) => m.date.isAtSameMomentAs(d0) || (m.date.isAfter(d0) && m.date.isBefore(d1)))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  Future<void> deleteMeal(String id) async {
    final items = _box.values.toList();
    for (var i = 0; i < items.length; i++) {
      if (items[i].id == id) {
        await _box.deleteAt(i);
        // TODO: mirror delete to SQLite (stub)
        unawaited(_mirrorDelete(id));
        return;
      }
    }
  }

  // ============================
  // SQLite stubs (implement later)
  // ============================
  Future<void> _mirrorInsert(MealEntry m) async {
    // TODO: insert into SQLite meals table when available
  }

  Future<void> _mirrorDelete(String id) async {
    // TODO: delete from SQLite meals table
  }
}
