import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/config/secrets.dart';
import '../models/altrix_message.dart';
import '../models/altrix_thread.dart';
import 'altrix_local_source.dart';
import 'altrix_analytics_logger.dart';
import '../../../core/db/app_database.dart';
import '../../../core/network/gemini_client.dart';
import 'package:dio/dio.dart' show CancelToken;

class AltrixRepository {
  AltrixRepository({
    required AltrixLocalSource local,
    required AltrixAnalyticsLogger analytics,
  }) : _local = local,
       _analytics = analytics;

  final AltrixLocalSource _local;
  final AltrixAnalyticsLogger _analytics;
  GeminiClient? _gemini; // late-initialized if API key available

  Future<void> init() async {
    await _local.init();
    await _analytics.init();
    // Initialize Gemini client using secure storage first, then dotenv as fallback
    try {
      final key = await Secrets.getGeminiApiKey();
      if (key != null && key.isNotEmpty) {
        _gemini = GeminiClient(key);
        if (kDebugMode)
          debugPrint('[AltrixRepository] Gemini client initialized');
      } else {
        if (kDebugMode)
          debugPrint(
            '[AltrixRepository] No GEMINI_API_KEY found; using mock flow',
          );
      }
    } catch (_) {
      // keep _gemini null -> mock path
    }
  }

  // Testing hook: allow injecting a fake Gemini client
  @visibleForTesting
  void setGeminiClientForTest(GeminiClient client) {
    _gemini = client;
  }

  // Threads
  List<AltrixThread> getThreads() => _local.getAllThreads();

  // ===== Telemetry passthroughs for UI/streaming flows =====
  Future<void> recordGeminiRequest({String? threadId}) async {
    try {
      await _analytics.recordGeminiRequest(threadId: threadId);
    } catch (_) {}
  }

  Future<void> recordGeminiSuccess({
    String? threadId,
    int tokensUsed = 0,
    int latencyMs = 0,
    String model = 'gemini-2.0-flash',
  }) async {
    try {
      await _analytics.recordGeminiSuccess(
        threadId: threadId,
        tokensUsed: tokensUsed,
        latencyMs: latencyMs,
        model: model,
      );
    } catch (_) {}
  }

  Future<void> recordGeminiError({
    String? threadId,
    required String code,
  }) async {
    try {
      await _analytics.recordGeminiError(threadId: threadId, code: code);
    } catch (_) {}
  }

  Future<AltrixThread> createThread({
    String? firstMessage,
    String? title,
  }) async {
    final now = DateTime.now();
    final id = AltrixThread.newId();
    final t = AltrixThread(
      id: id,
      title: (title != null && title.trim().isNotEmpty)
          ? title.trim()
          : (firstMessage != null && firstMessage.trim().isNotEmpty)
          ? _deriveTitle(firstMessage)
          : 'New chat',
      createdAt: now,
      updatedAt: now,
      messageCount: 0,
      model: 'gemini-2.0-flash',
      promptCount: 0,
      avgLatencyMs: 0,
    );
    await _local.upsertThread(t);
    // Mirror to SQLite (best-effort)
    try {
      await AltrixSqlHelpers.upsertAltrixThread(
        id: id,
        title: t.title,
        createdAt: t.createdAt,
        updatedAt: t.updatedAt,
        messageCount: t.messageCount,
        model: t.model,
        promptCount: t.promptCount,
        avgLatencyMs: t.avgLatencyMs,
      );
    } catch (_) {}
    await _analytics.logEvent('thread_created', {'id': id});
    return t;
  }

  /// Streams Gemini text chunks if configured, otherwise yields a simulated stream.
  Stream<String> streamGeminiText(
    String prompt, {
    CancelToken? cancelToken,
  }) async* {
    if (_gemini != null) {
      yield* _gemini!.streamPrompt(prompt, cancelToken: cancelToken);
      return;
    }
    // Fallback: simulate streaming by revealing the prompt echoed with tips
    final fake =
        'Here\'s a quick take: ' +
        prompt +
        '\n\n' +
        '• Keep hydrated.\n• Warm up 3–5 min.\n• Focus on form.';
    final words = fake.split(' ');
    for (final w in words) {
      await Future.delayed(const Duration(milliseconds: 60));
      yield w + ' ';
    }
  }

  Future<void> renameThread(String threadId, String title) async {
    final box = _local.threadsBox;
    final t = box.get(threadId);
    if (t == null) return;
    await _local.upsertThread(
      t.copyWith(title: title, updatedAt: DateTime.now()),
    );
  }

  Future<void> deleteThread(String threadId) async {
    await _local.deleteThread(threadId);
    // Mirror delete to SQLite (best-effort cascade)
    try {
      await AltrixSqlHelpers.deleteAltrixThreadCascade(threadId);
    } catch (_) {}
    await _analytics.logEvent('thread_deleted', {'id': threadId});
  }

  // Messages
  List<AltrixMessage> getMessages(String threadId) =>
      _local.getMessagesForThread(threadId);

  Future<AltrixThread?> getThread(String threadId) async {
    return _local.threadsBox.get(threadId);
  }

  Future<AltrixMessage> addUserMessage(String threadId, String content) async {
    // Create in 'sending' state to support optimistic UI
    final msg = AltrixMessage(
      id: _genId(),
      threadId: threadId,
      role: 'user',
      content: content,
      createdAt: DateTime.now(),
      meta: null,
      status: 'sending',
    );
    await _local.addMessage(msg);
    // Mirror to SQLite (best-effort)
    try {
      await AltrixSqlHelpers.insertAltrixMessage(
        id: msg.id,
        threadId: threadId,
        role: msg.role,
        content: msg.content,
        createdAt: msg.createdAt,
        status: msg.status,
      );
    } catch (_) {}
    await _bumpThreadCounter(threadId);
    await _analytics.logEvent('message_user', {'threadId': threadId});
    return msg;
  }

  Future<AltrixMessage> addAssistantMessage(
    String threadId,
    String content, {
    Map<String, dynamic>? meta,
  }) async {
    final now = DateTime.now();
    // Compute response time based on the most recent user message in this thread
    final all = _local.getMessagesForThread(threadId);
    final lastUser = all.lastWhere(
      (m) => m.role == 'user',
      orElse: () => AltrixMessage(
        id: '0',
        threadId: threadId,
        role: 'user',
        content: '',
        createdAt: now,
        meta: null,
      ),
    );
    final int responseTimeMs = now
        .difference(lastUser.createdAt)
        .inMilliseconds;

    // Sample metadata; in future, populate from real LLM call
    final int tokensUsed = (meta != null && meta['tokensUsed'] is int)
        ? meta['tokensUsed'] as int
        : 0;
    final int latencyMs = responseTimeMs;
    final bool isGemini = (meta != null && meta['isGeminiResponse'] == true);

    final msg = AltrixMessage(
      id: _genId(),
      threadId: threadId,
      role: 'assistant',
      content: content,
      createdAt: now,
      meta: meta,
      status: 'success',
      tokensUsed: tokensUsed,
      latencyMs: latencyMs,
      isGeminiResponse: isGemini,
    );
    await _local.addMessage(msg);
    // Mirror to SQLite (best-effort)
    try {
      await AltrixSqlHelpers.insertAltrixMessage(
        id: msg.id,
        threadId: threadId,
        role: msg.role,
        content: msg.content,
        createdAt: msg.createdAt,
        status: msg.status,
        tokensUsed: msg.tokensUsed,
        latencyMs: msg.latencyMs,
        isGeminiResponse: msg.isGeminiResponse,
      );
    } catch (_) {}
    await _bumpThreadCounter(threadId);
    await _analytics.logEvent('message_assistant', {'threadId': threadId});
    // Update per-thread aggregates (analytics store + thread snapshot)
    try {
      await _analytics.updateThreadMetrics(threadId, responseTimeMs);
    } catch (_) {}
    await _updateThreadStats(threadId, responseTimeMs, updatedAt: now);
    return msg;
  }

  /// Sends a message to Gemini (if configured) with simple retry.
  /// Falls back to local mock response when API key is not set.
  Future<AltrixMessage> sendMessageToGemini(
    String threadId,
    String content,
  ) async {
    // 1) Add user message in 'sending' state
    final user = await addUserMessage(threadId, content);
    // Telemetry: record request start
    try {
      await _analytics.recordGeminiRequest(threadId: threadId);
    } catch (_) {}

    // If Gemini not configured, use the previous mock behavior
    if (_gemini == null) {
      await Future.delayed(const Duration(seconds: 1));
      final mock = await addAssistantMessage(
        threadId,
        'This is a simulated reply (no API key configured).',
        meta: const {'tokensUsed': 0, 'isGeminiResponse': false},
      );
      try {
        await markUserMessageStatus(user.id, 'success');
      } catch (_) {}
      return mock;
    }

    // 2) Real API call with exponential backoff retry (1s -> 2s -> 4s)
    final started = DateTime.now();
    Map<String, dynamic>? reply;
    const delays = [1, 2, 4];
    for (var attempt = 0; attempt < delays.length; attempt++) {
      try {
        reply = await _gemini!.sendPrompt(content);
        break; // success
      } on GeminiException catch (ge) {
        // Map error codes for resilience and visibility
        final code = ge
            .code; // unauthorized | rateLimit | serverError | networkOffline | unknown
        // Persist failed status for the user message
        try {
          await markUserMessageStatus(user.id, 'failed');
        } catch (_) {}
        // Increment analytics errorCount
        try {
          await _analytics.incrementErrorCount(threadId);
        } catch (_) {}
        // Retry only for transient conditions (networkOffline, serverError, rateLimit)
        final transient =
            code == 'networkOffline' ||
            code == 'serverError' ||
            code == 'rateLimit';
        final lastAttempt = attempt == delays.length - 1;
        if (!transient || lastAttempt) {
          // Final error outcome -> record telemetry
          try {
            await _analytics.recordGeminiError(threadId: threadId, code: code);
          } catch (_) {}
          rethrow; // surface to caller/UI
        }
        // Exponential backoff
        await Future.delayed(Duration(seconds: delays[attempt]));
      } catch (e) {
        // Unknown failure: treat as transient once
        try {
          await markUserMessageStatus(user.id, 'failed');
        } catch (_) {}
        try {
          await _analytics.incrementErrorCount(threadId);
        } catch (_) {}
        final lastAttempt = attempt == delays.length - 1;
        if (lastAttempt) {
          // Final unknown error outcome -> record telemetry
          try {
            await _analytics.recordGeminiError(
              threadId: threadId,
              code: 'unknown',
            );
          } catch (_) {}
          throw GeminiException(GeminiErrorType.unknown, e.toString());
        }
        await Future.delayed(Duration(seconds: delays[attempt]));
      }
    }

    if (reply == null) {
      // Mark as failed definitively
      try {
        await markUserMessageStatus(user.id, 'failed');
      } catch (_) {}
      try {
        await _analytics.incrementErrorCount(threadId);
      } catch (_) {}
      // Record telemetry for final failure
      try {
        await _analytics.recordGeminiError(threadId: threadId, code: 'unknown');
      } catch (_) {}
      throw GeminiException(
        GeminiErrorType.unknown,
        'No response from Gemini after retries',
      );
    }

    final latency = DateTime.now().difference(started).inMilliseconds;
    // Parse text from Gemini 2.0 Flash shape
    String text = 'No response';
    try {
      final candidates = reply['candidates'];
      if (candidates is List && candidates.isNotEmpty) {
        final contentObj = candidates[0]['content'];
        if (contentObj is Map && contentObj['parts'] is List) {
          final parts = contentObj['parts'] as List;
          if (parts.isNotEmpty && parts[0]['text'] is String) {
            text = parts[0]['text'] as String;
          }
        }
      }
    } catch (_) {}

    // Token count for analytics
    int tokens = 0;
    try {
      final usage = reply['usageMetadata'];
      if (usage is Map && usage['totalTokenCount'] is num) {
        tokens = (usage['totalTokenCount'] as num).toInt();
      }
    } catch (_) {}

    // 3) Add assistant message and mark user message success
    final msg = await addAssistantMessage(
      threadId,
      text,
      meta: {
        'tokensUsed': tokens,
        'latencyMs': latency,
        'isGeminiResponse': true,
      },
    );
    try {
      await markUserMessageStatus(user.id, 'success');
    } catch (_) {}
    // Thread stat updates occur inside addAssistantMessage; also update analytics logger
    try {
      await _analytics.updateThreadMetrics(threadId, latency);
    } catch (_) {}
    // Telemetry: record success outcome
    try {
      await _analytics.recordGeminiSuccess(
        threadId: threadId,
        tokensUsed: tokens,
        latencyMs: latency,
        model: 'gemini-2.0-flash',
      );
    } catch (_) {}
    return msg;
  }

  Future<void> _updateThreadStats(
    String threadId,
    int latency, {
    DateTime? updatedAt,
  }) async {
    try {
      final box = _local.threadsBox;
      final t = box.get(threadId);
      if (t == null) return;
      final prev = t.promptCount;
      final newCount = prev + 1;
      final newAvg = prev == 0
          ? latency.toDouble()
          : ((t.avgLatencyMs * prev) + latency) / newCount;
      final now = updatedAt ?? DateTime.now();
      await _local.upsertThread(
        t.copyWith(promptCount: newCount, avgLatencyMs: newAvg, updatedAt: now),
      );
      // Mirror thread (best-effort) to keep ordering/fresh updatedAt
      try {
        await AltrixSqlHelpers.upsertAltrixThread(
          id: t.id,
          title: t.title,
          createdAt: t.createdAt,
          updatedAt: now,
          messageCount: t.messageCount,
          model: t.model,
          promptCount: newCount,
          avgLatencyMs: newAvg,
        );
      } catch (_) {}
    } catch (_) {}
  }

  /// Call this when a pending user message transitions to delivered or errored.
  Future<void> markUserMessageStatus(String messageId, String status) async {
    final box = _local.messagesBox;
    final existing = box.get(messageId);
    if (existing == null) return;
    final updated = existing.copyWith(status: status);
    await _local.updateMessage(updated);
    // Mirror to SQLite (best-effort)
    try {
      await AltrixSqlHelpers.updateAltrixMessageStatus(
        id: messageId,
        status: status,
      );
    } catch (_) {}
    // No need to bump thread counter
  }

  // Placeholder for future API/LLM integration. Currently uses local demo logic.
  Future<String> generateAssistantReply(
    String threadId,
    String userText,
  ) async {
    // For now, return echo-like suggestion; later call remote or on-device LLM.
    return 'Got it! You said: "$userText". Here are quick tips to continue.';
  }

  Future<void> _bumpThreadCounter(String threadId) async {
    final box = _local.threadsBox;
    final t = box.get(threadId);
    if (t == null) return;
    await _local.upsertThread(
      t.copyWith(messageCount: t.messageCount + 1, updatedAt: DateTime.now()),
    );
    // Mirror thread change to SQLite (best-effort)
    try {
      final updated = box.get(threadId);
      if (updated != null) {
        await AltrixSqlHelpers.upsertAltrixThread(
          id: updated.id,
          title: updated.title,
          createdAt: updated.createdAt,
          updatedAt: updated.updatedAt,
          messageCount: updated.messageCount,
        );
      }
    } catch (_) {}
  }

  String _deriveTitle(String content) {
    final s = content.trim();
    if (s.isEmpty) return 'New chat';
    final firstLine = s.split('\n').first;
    return firstLine.length <= 48
        ? firstLine
        : '${firstLine.substring(0, 48)}…';
  }

  String _genId() {
    final r = DateTime.now().microsecondsSinceEpoch ^ _rand32();
    return r.toRadixString(16);
  }

  int _rand32() =>
      (Hive.generateSecureKey().first << 24) +
      (Hive.generateSecureKey()[1] << 16) +
      (Hive.generateSecureKey()[2] << 8) +
      Hive.generateSecureKey()[3];
}
