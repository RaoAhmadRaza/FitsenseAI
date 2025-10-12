import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// High-level error types for Gemini client calls
enum GeminiErrorType { network, rateLimit, unauthorized, server, unknown }

class GeminiException implements Exception {
  final GeminiErrorType type;
  final String
  code; // e.g., unauthorized, rateLimit, serverError, networkOffline, unknown
  final String message;
  final int? statusCode;
  final Object? cause;

  GeminiException(
    this.type,
    this.message, {
    this.statusCode,
    this.cause,
    String? code,
  }) : code = code ?? _typeToCode(type);

  static String _typeToCode(GeminiErrorType t) {
    switch (t) {
      case GeminiErrorType.unauthorized:
        return 'unauthorized';
      case GeminiErrorType.rateLimit:
        return 'rateLimit';
      case GeminiErrorType.server:
        return 'serverError';
      case GeminiErrorType.network:
        return 'networkOffline';
      case GeminiErrorType.unknown:
        return 'unknown';
    }
  }

  @override
  String toString() =>
      'GeminiException($code, http=$statusCode, message=$message)';
}

class GeminiClient {
  final Dio _dio;
  final String _apiKey;
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';
  static const String _streamUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:streamGenerateContent';

  GeminiClient(String apiKey, {Dio? dio})
    : _apiKey = apiKey,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              headers: const {'Content-Type': 'application/json'},
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 30),
            ),
          ) {
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          request: false, // don't log method/URI (may include API key)
          requestHeader: false,
          requestBody: false,
          responseHeader: false,
          responseBody: true,
          error: true,
          logPrint: (obj) {
            // Best-effort redaction in case any key-like patterns slip through.
            final s = obj.toString();
            final redacted = s
                .replaceAll(RegExp(r'key=[^&\s]+'), 'key=REDACTED')
                .replaceAll(
                    RegExp(r'(x-goog-api-key\"?\s*[:=]\s*\"?)[^\"\s]+',
                        caseSensitive: false),
                    'REDACTED');
            debugPrint(redacted);
          },
        ),
      );
    }
  }

  /// Sends a simple text prompt to Gemini 2.0 Flash.
  /// Returns raw JSON response map.
  Future<Map<String, dynamic>> sendPrompt(
    String prompt, {
    CancelToken? cancelToken,
  }) async {
    try {
      final body = {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': prompt},
            ],
          },
        ],
      };

      final resp = await _dio.post(
        _baseUrl,
        data: body,
        queryParameters: {'key': _apiKey},
        cancelToken: cancelToken,
      );
      return _asMap(resp.data);
    } on DioException catch (e) {
      final type = _mapError(e);
      final status = e.response?.statusCode;
      final msg = e.message ?? e.response?.statusMessage ?? 'Request failed';
      throw GeminiException(type, msg, statusCode: status, cause: e);
    } catch (e) {
      throw GeminiException(GeminiErrorType.unknown, e.toString(), cause: e);
    }
  }

  /// Extracts token usage if available (usageMetadata.totalTokenCount)
  int? extractTokenCount(Map<String, dynamic> response) {
    final usage = response['usageMetadata'];
    if (usage is Map) {
      final t = usage['totalTokenCount'];
      if (t is int) return t;
      if (t is num) return t.toInt();
    }
    return null;
  }

  GeminiErrorType _mapError(DioException e) {
    final code = e.response?.statusCode;
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return GeminiErrorType.network;
    }
    if (e.type == DioExceptionType.connectionError) {
      return GeminiErrorType.network;
    }
    if (code == 401) return GeminiErrorType.unauthorized;
    if (code == 429) return GeminiErrorType.rateLimit;
    if (code != null && code >= 500) return GeminiErrorType.server;
    return GeminiErrorType.unknown;
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        // fall-through
      }
    }
    return <String, dynamic>{'data': data};
  }

  /// Streaming prompt using Server-Sent Events (SSE).
  /// Emits text chunks as they arrive.
  Stream<String> streamPrompt(
    String prompt, {
    CancelToken? cancelToken,
  }) async* {
    final body = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
          ],
        },
      ],
    };
    Response<ResponseBody> resp;
    try {
      resp = await _dio.post<ResponseBody>(
        _streamUrl,
        data: body,
        queryParameters: {'key': _apiKey},
        options: Options(
          responseType: ResponseType.stream,
          headers: const {'Accept': 'text/event-stream'},
        ),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw GeminiException(
        _mapError(e),
        e.message ?? 'Stream request failed',
        statusCode: e.response?.statusCode,
        cause: e,
      );
    }

    final byteStream = resp.data?.stream;
    if (byteStream == null) return;

    // Decide how to parse based on content-type; some backends respond with JSON instead of SSE.
    final contentType = resp.headers.map['content-type']?.join(',') ?? '';
    final isSse = contentType.contains('text/event-stream');

    if (isSse) {
      // Standard SSE parsing path
      final decoder = utf8.decoder;
      String carry = '';
      await for (final chunk in byteStream) {
        final decoded = decoder.convert(chunk);
        final combined = carry + decoded;
        final lines = combined.split('\n');
        // keep last partial line in carry
        carry = lines.isNotEmpty ? lines.removeLast() : '';
        for (final raw in lines) {
          final line = raw.trim();
          if (line.isEmpty || line.startsWith(':'))
            continue; // comments/keep-alives
          if (!line.startsWith('data:')) continue;
          final dataStr = line.substring(5).trim();
          if (dataStr.isEmpty || dataStr == '[DONE]') continue;
          try {
            final map = jsonDecode(dataStr) as Map<String, dynamic>;
            final chunks = _extractTexts(map);
            for (final t in chunks) {
              if (t.isNotEmpty) yield t;
            }
          } catch (_) {
            // ignore malformed lines
          }
        }
      }
      return;
    }

    // Fallback: Buffer and parse as JSON or NDJSON when content-type isn't SSE (e.g., application/json)
    final buffer = StringBuffer();
    await for (final chunk in byteStream) {
      buffer.write(utf8.decode(chunk));
    }
    final text = buffer.toString().trim();
    if (kDebugMode) {
      final ct = contentType.isEmpty ? 'unknown-content-type' : contentType;
      final preview = text.substring(0, text.length > 160 ? 160 : text.length);
      debugPrint(
        '[GeminiClient] Non-SSE response ($ct). First 160 chars:\n$preview',
      );
    }
    if (text.isEmpty) return;
    // Try full JSON object
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        final chunks = _extractTexts(decoded);
        for (final t in chunks) {
          if (t.isNotEmpty) yield t;
        }
        return;
      } else if (decoded is List) {
        for (final el in decoded) {
          if (el is Map<String, dynamic>) {
            final chunks = _extractTexts(el);
            for (final t in chunks) {
              if (t.isNotEmpty) yield t;
            }
          }
        }
        return;
      }
    } catch (_) {
      // Not a single JSON payload; fall through to NDJSON parsing
    }

    // Try NDJSON (one JSON object per line). Some backends/tests prefix lines with 'data: '.
    for (final raw in text.split('\n')) {
      var line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('data:')) {
        line = line.substring(5).trim();
        if (line.isEmpty) continue;
      }
      try {
        final map = jsonDecode(line) as Map<String, dynamic>;
        final chunks = _extractTexts(map);
        for (final t in chunks) {
          if (t.isNotEmpty) yield t;
        }
      } catch (_) {
        // ignore non-JSON lines
      }
    }
  }

  List<String> _extractTexts(Map<String, dynamic> data) {
    final List<String> out = [];
    final candidates = data['candidates'];
    if (candidates is List && candidates.isNotEmpty) {
      final content = candidates.first['content'];
      if (content is Map && content['parts'] is List) {
        for (final p in (content['parts'] as List)) {
          final txt = p is Map ? p['text'] : null;
          if (txt is String && txt.isNotEmpty) out.add(txt);
        }
      }
    }
    return out;
  }
}
