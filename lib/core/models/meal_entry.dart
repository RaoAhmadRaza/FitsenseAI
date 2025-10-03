import 'dart:math';
import 'package:hive/hive.dart';

@HiveType(typeId: 16)
class MealEntry extends HiveObject {
  @HiveField(0)
  final String id; // stable id for updates/deletes
  @HiveField(1)
  final DateTime date; // when the meal occurred
  @HiveField(2)
  final String name; // e.g., "Breakfast", "Chicken bowl"
  @HiveField(3)
  final int calories; // kcal
  @HiveField(4)
  final int proteinGrams; // g
  @HiveField(5)
  final int carbsGrams; // g
  @HiveField(6)
  final int fatGrams; // g

  MealEntry({
    required this.id,
    required this.date,
    required this.name,
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
  });

  MealEntry copyWith({
    DateTime? date,
    String? name,
    int? calories,
    int? proteinGrams,
    int? carbsGrams,
    int? fatGrams,
  }) => MealEntry(
        id: id,
        date: date ?? this.date,
        name: name ?? this.name,
        calories: calories ?? this.calories,
        proteinGrams: proteinGrams ?? this.proteinGrams,
        carbsGrams: carbsGrams ?? this.carbsGrams,
        fatGrams: fatGrams ?? this.fatGrams,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'name': name,
        'calories': calories,
        'protein_g': proteinGrams,
        'carbs_g': carbsGrams,
        'fat_g': fatGrams,
      };

  static MealEntry fromMap(Map<String, Object?> m) => MealEntry(
        id: m['id'] as String,
        date: DateTime.parse(m['date'] as String),
        name: m['name'] as String,
        calories: (m['calories'] as num).toInt(),
        proteinGrams: (m['protein_g'] as num).toInt(),
        carbsGrams: (m['carbs_g'] as num).toInt(),
        fatGrams: (m['fat_g'] as num).toInt(),
      );

  static String newId() {
    final rand = Random.secure();
    return List<int>.generate(16, (_) => rand.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}

class MealEntryAdapter extends TypeAdapter<MealEntry> {
  @override
  final int typeId = 16;

  @override
  MealEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return MealEntry(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      name: fields[2] as String,
      calories: fields[3] as int,
      proteinGrams: fields[4] as int,
      carbsGrams: fields[5] as int,
      fatGrams: fields[6] as int,
    );
  }

  @override
  void write(BinaryWriter writer, MealEntry obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.calories)
      ..writeByte(4)
      ..write(obj.proteinGrams)
      ..writeByte(5)
      ..write(obj.carbsGrams)
      ..writeByte(6)
      ..write(obj.fatGrams);
  }
}
