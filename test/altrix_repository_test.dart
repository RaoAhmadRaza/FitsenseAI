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

/// Test encryption service to avoid platform secure storage in unit tests.
class TestEncryptionService extends EncryptionService {
  const TestEncryptionService();
  @override
  Future<HiveAesCipher> getCipher(String keyName) async {
    // Use a deterministic 32-byte key for tests
    final key = List<int>.filled(32, 1);
    return HiveAesCipher(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AltrixRepository', () {
    late Directory tempDir;
    late LocalStorageService storage;
    late AltrixRepository repo;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_altrix_repo');
      // Initialize Hive in temp directory for isolation
      Hive.init(tempDir.path);

      // Register adapters if not already registered
      if (!Hive.isAdapterRegistered(AltrixThreadAdapter().typeId)) {
        Hive.registerAdapter(AltrixThreadAdapter());
      }
      if (!Hive.isAdapterRegistered(AltrixMessageAdapter().typeId)) {
        Hive.registerAdapter(AltrixMessageAdapter());
      }

      // Provide a test storage service with deterministic cipher
      storage = LocalStorageService(encryption: const TestEncryptionService());
      final local = AltrixLocalSource(storage);
      final analytics = LocalAltrixAnalyticsLogger(storage);
      repo = AltrixRepository(local: local, analytics: analytics);
      await repo.init();
    });

    tearDown(() async {
      // Close all boxes and clean up temp directory
      await Hive.close();
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    test('creates thread with default analytics', () async {
      final t = await repo.createThread(title: 'Test');
      expect(t.model, 'gemini-2.0-flash');
      expect(t.promptCount, 0);
      expect(t.avgLatencyMs, 0);
    });

    test(
      'updates prompt count and latency average',
      () async {
        final t = await repo.createThread();
        // Simulate message send to Gemini (has built-in delay ~2s)
        await repo.sendMessageToGemini(t.id, 'Ping');
        final updated = await repo.getThread(t.id);
        expect(updated, isNotNull);
        expect(updated!.promptCount, 1);
        expect(updated.avgLatencyMs, greaterThan(0));
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );
  });
}
