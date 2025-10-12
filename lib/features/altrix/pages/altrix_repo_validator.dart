import 'package:flutter/material.dart';
import '../../altrix/utils/altrix_constants.dart';
import '../data/altrix_repository.dart';
import '../data/altrix_local_source.dart';
import '../data/altrix_analytics_logger.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/db/app_database.dart';

class AltrixRepoValidatorPage extends StatefulWidget {
  const AltrixRepoValidatorPage({super.key});

  @override
  State<AltrixRepoValidatorPage> createState() =>
      _AltrixRepoValidatorPageState();
}

class _AltrixRepoValidatorPageState extends State<AltrixRepoValidatorPage> {
  String _log = '';
  bool _running = false;

  void _append(String s) {
    setState(() => _log += s + '\n');
  }

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _log = '';
    });
    final storage = LocalStorageService();
    final repo = AltrixRepository(
      local: AltrixLocalSource(storage),
      analytics: LocalAltrixAnalyticsLogger(storage),
    );
    await repo.init();
    _append('Initialized repository.');

    // Test 1 — User + Assistant message pipeline
    final thread = await repo.createThread(title: 'Validation Chat');
    _append('Created thread: ${thread.id}');
    await repo.sendMessageToGemini(thread.id, 'Hello Gemini!');
    _append('Sent message and got assistant reply.');

    // Validate counts via local (Hive) and mirror (SQLite)
    final msgs = repo.getMessages(thread.id);
    _append('Hive says thread has ${msgs.length} messages.');
    final db = await AppDatabase.instance();
    final rows = await db.query(
      AppDatabase.tableAltrixMessages,
      where: 'thread_id = ?',
      whereArgs: [thread.id],
    );
    _append('SQLite says thread has ${rows.length} messages.');

    // Check assistant metadata in SQLite
    final assistant = rows.lastWhere(
      (r) => r['role'] == 'assistant',
      orElse: () => {},
    );
    final tok = (assistant['tokens_used'] as int?) ?? 0;
    final lat = (assistant['latency_ms'] as int?) ?? 0;
    final gem = (assistant['is_gemini_response'] as int?) == 1;
    _append(
      'Assistant metadata -> tokens_used: $tok, latency_ms: $lat, gemini: $gem',
    );

    // Test 2 — Analytics update
    final t = await repo.getThread(thread.id);
    if (t != null) {
      _append(
        'Thread metrics -> promptCount: ${t.promptCount}, avgLatencyMs: ${t.avgLatencyMs.toStringAsFixed(1)}',
      );
    }
    // Drawer metrics source (analytics box)
    try {
      final box = await storage.openEncryptedDynamicBox(
        AltrixConstants.analyticsBox,
      );
      final m = box.get('metrics_${thread.id}');
      _append('Analytics box: $m');
    } catch (_) {}

    setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Altrix Repo Validator')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _running ? null : _run,
                  child: const Text('Run Validation'),
                ),
                const SizedBox(width: 12),
                if (_running) const CircularProgressIndicator(),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                _log.isEmpty ? 'Press Run to start tests.' : _log,
                style: const TextStyle(fontFamily: 'SF Pro Text'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
