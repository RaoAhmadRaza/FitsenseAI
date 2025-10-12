import 'package:hive/hive.dart';
import '../utils/altrix_constants.dart';

part 'altrix_message.g.dart';

@HiveType(typeId: AltrixConstants.messageTypeId)
class AltrixMessage {
  @HiveField(0)
  final String id; // ULID/UUID

  @HiveField(1)
  final String threadId;

  @HiveField(2)
  final String role; // 'user' | 'assistant' | 'system'

  @HiveField(3)
  final String content; // plain text for now; can evolve to rich blocks

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final Map<String, dynamic>? meta; // e.g., tokens, model, durations

  // New fields (appended with higher field indices to preserve backward compatibility)
  @HiveField(6)
  final String status; // 'sending' | 'success' | 'error'

  @HiveField(7)
  final int tokensUsed; // From Gemini/LLM metadata

  @HiveField(8)
  final int latencyMs; // Round-trip time for this message

  @HiveField(9)
  final bool isGeminiResponse; // true if assistant message came from Gemini

  // Error text for failed messages (appended as new field index)
  @HiveField(10)
  final String? error; // descriptive error for UI retry block

  const AltrixMessage({
    required this.id,
    required this.threadId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.meta,
    this.status = 'success',
    this.tokensUsed = 0,
    this.latencyMs = 0,
    this.isGeminiResponse = false,
    this.error,
  });

  /// Serialize to a plain Map for transport/SQL/etc.
  Map<String, Object?> toMap() => {
    'id': id,
    'threadId': threadId,
    'role': role,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'meta': meta,
    'status': status,
    'tokensUsed': tokensUsed,
    'latencyMs': latencyMs,
    'isGeminiResponse': isGeminiResponse,
    'error': error,
  };

  /// Create from a Map; applies defaults for newly added fields.
  factory AltrixMessage.fromMap(Map<String, Object?> map) => AltrixMessage(
    id: (map['id'] ?? '') as String,
    threadId: (map['threadId'] ?? '') as String,
    role: (map['role'] ?? 'user') as String,
    content: (map['content'] ?? '') as String,
    createdAt: map['createdAt'] is String
        ? DateTime.parse(map['createdAt'] as String)
        : (map['createdAt'] as DateTime? ?? DateTime.now()),
    meta: (map['meta'] as Map?)?.cast<String, dynamic>(),
    status: (map['status'] as String?) ?? 'success',
    tokensUsed: (map['tokensUsed'] as int?) ?? 0,
    latencyMs: (map['latencyMs'] as int?) ?? 0,
    isGeminiResponse: (map['isGeminiResponse'] as bool?) ?? false,
    error: map['error'] as String?,
  );

  AltrixMessage copyWith({
    String? id,
    String? threadId,
    String? role,
    String? content,
    DateTime? createdAt,
    Map<String, dynamic>? meta,
    String? status,
    int? tokensUsed,
    int? latencyMs,
    bool? isGeminiResponse,
    String? error,
  }) {
    return AltrixMessage(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      meta: meta ?? this.meta,
      status: status ?? this.status,
      tokensUsed: tokensUsed ?? this.tokensUsed,
      latencyMs: latencyMs ?? this.latencyMs,
      isGeminiResponse: isGeminiResponse ?? this.isGeminiResponse,
      error: error ?? this.error,
    );
  }
}
