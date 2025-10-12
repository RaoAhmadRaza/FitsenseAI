import 'dart:math';
import 'package:hive/hive.dart';
import '../utils/altrix_constants.dart';

part 'altrix_thread.g.dart';

@HiveType(typeId: AltrixConstants.threadTypeId)
class AltrixThread {
  @HiveField(0)
  final String id; // ULID/UUID

  @HiveField(1)
  final String title; // derived from first user message

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  final DateTime updatedAt;

  @HiveField(4)
  final int messageCount;

  @HiveField(5)
  final bool archived;

  @HiveField(6)
  final bool pinned;

  // 🆕 Gemini model + analytics (appended indices for backward compatibility)
  @HiveField(7)
  final String model; // e.g. "gemini-2.0-flash"

  @HiveField(8)
  final int promptCount;

  @HiveField(9)
  final double avgLatencyMs;

  const AltrixThread({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messageCount,
    this.archived = false,
    this.pinned = false,
    String? model,
    int? promptCount,
    double? avgLatencyMs,
  }) : model = model ?? 'gemini-2.0-flash',
       promptCount = promptCount ?? 0,
       avgLatencyMs = avgLatencyMs ?? 0;

  AltrixThread copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? messageCount,
    bool? archived,
    bool? pinned,
    String? model,
    int? promptCount,
    double? avgLatencyMs,
  }) => AltrixThread(
    id: id ?? this.id,
    title: title ?? this.title,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    messageCount: messageCount ?? this.messageCount,
    archived: archived ?? this.archived,
    pinned: pinned ?? this.pinned,
    model: model ?? this.model,
    promptCount: promptCount ?? this.promptCount,
    avgLatencyMs: avgLatencyMs ?? this.avgLatencyMs,
  );

  static String newId() {
    final rand = Random.secure();
    return List<int>.generate(
      16,
      (_) => rand.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // Mapping helpers for analytics/SQL mirroring
  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'messageCount': messageCount,
    'archived': archived,
    'pinned': pinned,
    'model': model,
    'promptCount': promptCount,
    'avgLatencyMs': avgLatencyMs,
  };

  factory AltrixThread.fromMap(Map<String, Object?> map) => AltrixThread(
    id: (map['id'] ?? '') as String,
    title: (map['title'] ?? 'New chat') as String,
    createdAt: map['createdAt'] is String
        ? DateTime.parse(map['createdAt'] as String)
        : (map['createdAt'] as DateTime? ?? DateTime.now()),
    updatedAt: map['updatedAt'] is String
        ? DateTime.parse(map['updatedAt'] as String)
        : (map['updatedAt'] as DateTime? ?? DateTime.now()),
    messageCount: (map['messageCount'] as int?) ?? 0,
    archived: (map['archived'] as bool?) ?? false,
    pinned: (map['pinned'] as bool?) ?? false,
    model: (map['model'] as String?) ?? 'gemini-2.0-flash',
    promptCount: (map['promptCount'] as int?) ?? 0,
    avgLatencyMs: (map['avgLatencyMs'] as num?)?.toDouble() ?? 0,
  );
}
