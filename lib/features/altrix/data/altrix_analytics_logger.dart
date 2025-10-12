import 'package:hive/hive.dart';
import '../utils/altrix_constants.dart';
import '../../../core/services/local_storage_service.dart';

abstract class AltrixAnalyticsLogger {
  Future<void> init();
  Future<void> logEvent(String name, Map<String, Object?> data);
  Future<void> updateThreadMetrics(String threadId, int responseTimeMs);
  Future<void> incrementErrorCount(String threadId);
  // New: Gemini request lifecycle telemetry
  Future<void> recordGeminiRequest({String? threadId});
  Future<void> recordGeminiSuccess({
    String? threadId,
    int tokensUsed = 0,
    int latencyMs = 0,
    String model,
  });
  Future<void> recordGeminiError({String? threadId, required String code});
  Future<Map<String, Object?>> getGlobalGeminiMetrics();
}

class LocalAltrixAnalyticsLogger implements AltrixAnalyticsLogger {
  LocalAltrixAnalyticsLogger(this._storage);

  final LocalStorageService _storage;
  Box? _box;

  @override
  Future<void> init() async {
    _box = await _storage.openEncryptedDynamicBox(AltrixConstants.analyticsBox);
  }

  @override
  Future<void> logEvent(String name, Map<String, Object?> data) async {
    final box = _box ?? (throw StateError('Analytics not initialized'));
    final ts = DateTime.now().toIso8601String();
    await box.add({'name': name, 'data': data, 'ts': ts});
  }

  @override
  Future<void> updateThreadMetrics(String threadId, int responseTimeMs) async {
    final box = _box ?? (throw StateError('Analytics not initialized'));
    final key = 'metrics_$threadId';
    final prev = box.get(key);
    final int oldCount = (prev is Map && prev['promptCount'] is int)
        ? prev['promptCount'] as int
        : 0;
    final double? oldAvg = (prev is Map && prev['avgResponseTime'] is num)
        ? (prev['avgResponseTime'] as num).toDouble()
        : null;
    final int newCount = oldCount + 1;
    final double newAvg = oldAvg == null
        ? responseTimeMs.toDouble()
        : ((oldAvg * oldCount) + responseTimeMs) / newCount;

    await box.put(key, {
      'promptCount': newCount,
      'avgResponseTime': newAvg,
      'updatedAt': DateTime.now().toIso8601String(),
      // preserve existing errorCount if present
      'errorCount': (prev is Map && prev['errorCount'] is int)
          ? prev['errorCount'] as int
          : 0,
    });
  }

  @override
  Future<void> incrementErrorCount(String threadId) async {
    final box = _box ?? (throw StateError('Analytics not initialized'));
    final key = 'metrics_$threadId';
    final prev = box.get(key);
    final int prevErr = (prev is Map && prev['errorCount'] is int)
        ? prev['errorCount'] as int
        : 0;
    final map = <String, Object?>{
      'errorCount': prevErr + 1,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    // keep existing fields if present
    if (prev is Map && prev['promptCount'] != null) {
      map['promptCount'] = prev['promptCount'];
    }
    if (prev is Map && prev['avgResponseTime'] != null) {
      map['avgResponseTime'] = prev['avgResponseTime'];
    }
    await box.put(key, map);
  }

  // ========= Gemini Telemetry =========
  static const String _globalKey = 'gemini_metrics_global';
  static const String _defaultModel = 'gemini-2.0-flash';

  @override
  Future<void> recordGeminiRequest({String? threadId}) async {
    final box = _box ?? (throw StateError('Analytics not initialized'));
    await logEvent('gemini_request', {
      if (threadId != null) 'threadId': threadId,
    });
    // Ensure metrics object exists
    final m = Map<String, Object?>.from(box.get(_globalKey) as Map? ?? {});
    if (!m.containsKey('model')) m['model'] = _defaultModel;
    if (!m.containsKey('recent')) m['recent'] = <String>[];
    if (!m.containsKey('totalTokens')) m['totalTokens'] = 0;
    if (!m.containsKey('successCount')) m['successCount'] = 0;
    if (!m.containsKey('errorCount')) m['errorCount'] = 0;
    if (!m.containsKey('avgLatencyMs')) m['avgLatencyMs'] = 0.0;
    m['updatedAt'] = DateTime.now().toIso8601String();
    await box.put(_globalKey, m);
  }

  @override
  Future<void> recordGeminiSuccess({
    String? threadId,
    int tokensUsed = 0,
    int latencyMs = 0,
    String model = _defaultModel,
  }) async {
    final box = _box ?? (throw StateError('Analytics not initialized'));
    await logEvent('gemini_success', {
      if (threadId != null) 'threadId': threadId,
      'tokens': tokensUsed,
      'latencyMs': latencyMs,
      'model': model,
    });
    final m = Map<String, Object?>.from(box.get(_globalKey) as Map? ?? {});
    final recent = (m['recent'] as List?)?.cast<String>() ?? <String>[];
    recent.add('success');
    while (recent.length > 10) recent.removeAt(0);
    final prevSucc = (m['successCount'] as int?) ?? 0;
    final prevErr = (m['errorCount'] as int?) ?? 0;
    final prevTokens = (m['totalTokens'] as int?) ?? 0;
    final prevAvg = (m['avgLatencyMs'] as num?)?.toDouble() ?? 0.0;
    final succCount = prevSucc + 1;
    final newAvg = prevSucc == 0
        ? latencyMs.toDouble()
        : ((prevAvg * prevSucc) + latencyMs) / succCount;
    final map = <String, Object?>{
      'model': model,
      'recent': recent,
      'successCount': succCount,
      'errorCount': prevErr,
      'totalTokens': prevTokens + tokensUsed,
      'avgLatencyMs': newAvg,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await box.put(_globalKey, map);
  }

  @override
  Future<void> recordGeminiError({
    String? threadId,
    required String code,
  }) async {
    final box = _box ?? (throw StateError('Analytics not initialized'));
    await logEvent('gemini_error', {
      if (threadId != null) 'threadId': threadId,
      'code': code,
    });
    final m = Map<String, Object?>.from(box.get(_globalKey) as Map? ?? {});
    final recent = (m['recent'] as List?)?.cast<String>() ?? <String>[];
    recent.add('error');
    while (recent.length > 10) recent.removeAt(0);
    final prevSucc = (m['successCount'] as int?) ?? 0;
    final prevErr = (m['errorCount'] as int?) ?? 0;
    final map = <String, Object?>{
      'model': (m['model'] as String?) ?? _defaultModel,
      'recent': recent,
      'successCount': prevSucc,
      'errorCount': prevErr + 1,
      'totalTokens': (m['totalTokens'] as int?) ?? 0,
      'avgLatencyMs': (m['avgLatencyMs'] as num?)?.toDouble() ?? 0.0,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await box.put(_globalKey, map);
  }

  @override
  Future<Map<String, Object?>> getGlobalGeminiMetrics() async {
    final box = _box ?? (throw StateError('Analytics not initialized'));
    final m = box.get(_globalKey);
    if (m is Map) return Map<String, Object?>.from(m);
    return <String, Object?>{};
  }
}
