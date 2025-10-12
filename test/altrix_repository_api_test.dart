import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:ai_fitness_tracker/features/altrix/data/altrix_repository.dart';
import 'package:ai_fitness_tracker/features/altrix/data/altrix_local_source.dart';
import 'package:ai_fitness_tracker/features/altrix/data/altrix_analytics_logger.dart';
import 'package:ai_fitness_tracker/features/altrix/models/altrix_thread.dart';
import 'package:ai_fitness_tracker/features/altrix/models/altrix_message.dart';
import 'package:ai_fitness_tracker/core/services/local_storage_service.dart';
import 'package:ai_fitness_tracker/core/services/encryption_service.dart';
import 'package:ai_fitness_tracker/core/network/gemini_client.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:ai_fitness_tracker/features/altrix/utils/altrix_constants.dart';

class _TestEncryptionService extends EncryptionService {
  const _TestEncryptionService();
  @override
  Future<HiveAesCipher> getCipher(String keyName) async {
    final key = List<int>.filled(32, 3);
    return HiveAesCipher(key);
  }
}

class _FakeGeminiClient extends GeminiClient {
  _FakeGeminiClient() : super('test');

  Map<String, dynamic> nextResponse = {
    'candidates': [
      {
        'content': {
          'parts': [
            {'text': 'OK'},
          ],
        },
      },
    ],
    'usageMetadata': {'totalTokenCount': 9},
  };

  @override
  Future<Map<String, dynamic>> sendPrompt(
    String prompt, {
    CancelToken? cancelToken,
  }) async {
    if (_transientFailuresRemaining > 0) {
      _transientFailuresRemaining--;
      throw GeminiException(
        GeminiErrorType.rateLimit,
        'try later',
        code: 'rateLimit',
      );
    }
    return nextResponse;
  }

  final List<String> streamChunks = ['Hello', ' world!'];
  @override
  Stream<String> streamPrompt(
    String prompt, {
    CancelToken? cancelToken,
  }) async* {
    for (final c in streamChunks) {
      await Future.delayed(const Duration(milliseconds: 10));
      yield c;
    }
  }

  int _transientFailuresRemaining = 0;
  void setTransientFailures(int n) {
    _transientFailuresRemaining = n;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AltrixRepository API', () {
    late Directory tempDir;
    late LocalStorageService storage;
    late AltrixRepository repo;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_altrix_repo_api');
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(AltrixThreadAdapter().typeId)) {
        Hive.registerAdapter(AltrixThreadAdapter());
      }
      if (!Hive.isAdapterRegistered(AltrixMessageAdapter().typeId)) {
        Hive.registerAdapter(AltrixMessageAdapter());
      }
      storage = LocalStorageService(encryption: const _TestEncryptionService());
      final local = AltrixLocalSource(storage);
      final analytics = LocalAltrixAnalyticsLogger(storage);
      repo = AltrixRepository(local: local, analytics: analytics);
      await repo.init();
    });

    tearDown(() async {
      await Hive.close();
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    test(
      'Repository flow: send prompt persists user+assistant and updates metrics',
      () async {
        final thread = await repo.createThread(title: 'T1');
        final fake = _FakeGeminiClient();
        repo.setGeminiClientForTest(fake);

        final msg = await repo.sendMessageToGemini(thread.id, 'Ping');
        expect(msg.role, 'assistant');
        expect(msg.isGeminiResponse, isTrue);
        expect(msg.tokensUsed, 9);

        final messages = repo.getMessages(thread.id);
        expect(messages.length, 2); // user + assistant
        final user = messages.firstWhere((m) => m.role == 'user');
        expect(user.status, 'success');

        final tUpdated = await repo.getThread(thread.id);
        expect(tUpdated, isNotNull);
        expect(tUpdated!.promptCount, 1);
        expect(tUpdated.avgLatencyMs, greaterThanOrEqualTo(0));
      },
    );

    test(
      'Streaming simulation: chunks collected and final message persisted',
      () async {
        final thread = await repo.createThread(title: 'T2');
        final fake = _FakeGeminiClient();
        repo.setGeminiClientForTest(fake);

        final chunks = <String>[];
        await for (final c in repo.streamGeminiText('hello')) {
          chunks.add(c);
        }
        final finalText = chunks.join();
        expect(finalText, 'Hello world!');

        final assistant = await repo.addAssistantMessage(
          thread.id,
          finalText,
          meta: const {'isGeminiResponse': true},
        );
        expect(assistant.content, 'Hello world!');

        final messages = repo.getMessages(thread.id);
        expect(
          messages.any(
            (m) => m.role == 'assistant' && m.content == 'Hello world!',
          ),
          isTrue,
        );
      },
    );

    test(
      'Fallback flow when no API key: simulated assistant reply and user marked success',
      () async {
        // Leave _gemini as null by not injecting a client
        final thread = await repo.createThread(title: 'NoKey');
        final msg = await repo.sendMessageToGemini(
          thread.id,
          'Test without key',
        );
        expect(msg.role, 'assistant');
        expect(msg.isGeminiResponse, isFalse);
        final user = repo
            .getMessages(thread.id)
            .firstWhere((m) => m.role == 'user');
        expect(user.status, 'success');
      },
    );

    test(
      'Retry on transient errors: marks failures, increments analytics, finally succeeds',
      () async {
        final thread = await repo.createThread(title: 'Retry');
        final fake = _FakeGeminiClient();
        fake.setTransientFailures(2);
        fake.nextResponse = {
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Success after retry'},
                ],
              },
            },
          ],
          'usageMetadata': {'totalTokenCount': 7},
        };
        repo.setGeminiClientForTest(fake);

        final assistant = await repo.sendMessageToGemini(thread.id, 'Hello');
        expect(assistant.content, contains('Success'));
        // User message should be set to success at the end
        final user = repo
            .getMessages(thread.id)
            .firstWhere((m) => m.role == 'user');
        expect(user.status, 'success');

        // Analytics errorCount should have been incremented for each failed attempt (2)
        final box = await storage.openEncryptedDynamicBox(
          AltrixConstants.analyticsBox,
        );
        final metrics = box.get('metrics_${thread.id}') as Map?;
        expect(metrics, isNotNull);
        expect(metrics!['errorCount'], 2);
      },
    );

    test('markUserMessageStatus updates message status in Hive', () async {
      final t = await repo.createThread(title: 'Status');
      final user = await repo.addUserMessage(t.id, 'Hello');
      // Initially 'sending'
      expect(
        repo.getMessages(t.id).firstWhere((m) => m.id == user.id).status,
        'sending',
      );
      await repo.markUserMessageStatus(user.id, 'failed');
      expect(
        repo.getMessages(t.id).firstWhere((m) => m.id == user.id).status,
        'failed',
      );
    });

    test(
      'renameThread and deleteThread modify local storage correctly',
      () async {
        final t1 = await repo.createThread(title: 'Old');
        final t2 = await repo.createThread(title: 'Keep');
        await repo.renameThread(t1.id, 'New Title');
        final updated = await repo.getThread(t1.id);
        expect(updated!.title, 'New Title');
        // Add a message then delete thread; messages should be gone as well
        await repo.addUserMessage(t1.id, 'Hi');
        expect(repo.getMessages(t1.id).length, 1);
        await repo.deleteThread(t1.id);
        expect(repo.getThread(t1.id), completion(isNull));
        expect(repo.getMessages(t1.id), isEmpty);
        // Other thread remains
        expect((await repo.getThread(t2.id)) != null, isTrue);
      },
    );

    test(
      'createThread derives title from firstMessage when no explicit title',
      () async {
        final t = await repo.createThread(
          firstMessage: 'Plan: Push day\nwith accessories',
        );
        expect(t.title.startsWith('Plan: Push day'), isTrue);
      },
    );

    test('fallback streaming yields chunks when no API key', () async {
      final chunks = <String>[];
      await for (final c in repo.streamGeminiText('Hydration')) {
        chunks.add(c);
        if (chunks.length > 10) break; // don't run too long
      }
      expect(chunks, isNotEmpty);
    });

    test('generateAssistantReply returns echo-like text', () async {
      final t = await repo.createThread(title: 'Gen');
      final reply = await repo.generateAssistantReply(t.id, 'Squats');
      expect(reply, contains('Squats'));
    });
  });
}
