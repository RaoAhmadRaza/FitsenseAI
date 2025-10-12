import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/db/app_database.dart';

class AltrixDbInspectorPage extends StatefulWidget {
  const AltrixDbInspectorPage({super.key});

  @override
  State<AltrixDbInspectorPage> createState() => _AltrixDbInspectorPageState();
}

class _AltrixDbInspectorPageState extends State<AltrixDbInspectorPage> {
  late Future<List<Map<String, Object?>>> _future;
  late Future<_DbInfo> _dbInfoFuture;

  @override
  void initState() {
    super.initState();
    _future = AltrixSqlHelpers.listAltrixThreads();
    _dbInfoFuture = _loadDbInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Altrix DB Inspector'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _future = AltrixSqlHelpers.listAltrixThreads();
                _dbInfoFuture = _loadDbInfo();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data!;
          if (rows.isEmpty) {
            return const Center(child: Text('No threads found'));
          }
          return Column(
            children: [
              FutureBuilder<_DbInfo>(
                future: _dbInfoFuture,
                builder: (context, infoSnap) {
                  if (!infoSnap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: LinearProgressIndicator(),
                    );
                  }
                  final info = infoSnap.data!;
                  return Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DB version: ${info.version}'),
                        const SizedBox(height: 6),
                        Text(
                          'altrix_messages columns: ${info.messagesColumns.join(', ')}',
                        ),
                        Text(
                          'altrix_threads columns: ${info.threadsColumns.join(', ')}',
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Rows: messages=${info.messagesCount}, threads=${info.threadsCount}, sum(message_count)=${info.sumThreadMessageCount}',
                        ),
                        if (info.queryMs != null)
                          Text(
                            'Query time: ${info.queryMs!.toStringAsFixed(1)} ms',
                          ),
                        const Divider(height: 20),
                      ],
                    ),
                  );
                },
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    final id = r['id']?.toString() ?? '';
                    final title = r['title']?.toString() ?? '';
                    final count =
                        (r['message_count'] as int?)?.toString() ?? '0';
                    final updatedRaw = r['updated_at'];
                    String updated;
                    if (updatedRaw is int) {
                      updated = DateTime.fromMillisecondsSinceEpoch(
                        updatedRaw,
                      ).toIso8601String();
                    } else {
                      updated = updatedRaw?.toString() ?? '';
                    }
                    final model = r['model']?.toString() ?? '';
                    final prompts = (r['prompt_count'] as int?) ?? 0;
                    final avg = (r['avg_latency_ms'] as num?)?.toDouble() ?? 0;
                    final subtitle = [
                      'Messages: $count',
                      if (model.isNotEmpty) 'model: $model',
                      'prompts: $prompts',
                      if (avg > 0) 'avg: ${_formatMs(avg)}',
                      'updated: $updated',
                    ].join(' • ');
                    return ListTile(
                      title: Text(title.isEmpty ? id : title),
                      subtitle: Text(subtitle),
                      dense: true,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AltrixThreadMessagesPage(
                              threadId: id,
                              title: title.isEmpty ? id : title,
                            ),
                          ),
                        );
                      },
                      trailing: IconButton(
                        tooltip: 'Export to JSON',
                        icon: const Icon(Icons.download),
                        onPressed: () async {
                          await _exportThreadToJson(context, id, title);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<_DbInfo> _loadDbInfo() async {
    final started = DateTime.now();
    final db = await AppDatabase.instance();
    final userVersionRows = await db.rawQuery('PRAGMA user_version');
    int v = 0;
    if (userVersionRows.isNotEmpty) {
      final row = userVersionRows.first;
      final val = row.values.isNotEmpty ? row.values.first : 0;
      v = (val as num?)?.toInt() ?? 0;
    }
    final msgColsRows = await db.rawQuery('PRAGMA table_info(altrix_messages)');
    final thrColsRows = await db.rawQuery('PRAGMA table_info(altrix_threads)');
    final msgCols = msgColsRows
        .map((e) => e['name']?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
    final thrCols = thrColsRows
        .map((e) => e['name']?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
    // Counts for validation (ensure no data loss after migration)
    final msgCountRows = await db.rawQuery(
      'SELECT COUNT(*) as c FROM ${AppDatabase.tableAltrixMessages}',
    );
    final thrCountRows = await db.rawQuery(
      'SELECT COUNT(*) as c FROM ${AppDatabase.tableAltrixThreads}',
    );
    final sumCountRows = await db.rawQuery(
      'SELECT SUM(message_count) as s FROM ${AppDatabase.tableAltrixThreads}',
    );
    final totalMsgs = (msgCountRows.first['c'] as num?)?.toInt() ?? 0;
    final totalThreads = (thrCountRows.first['c'] as num?)?.toInt() ?? 0;
    final sumThreadMsgs = (sumCountRows.first['s'] as num?)?.toInt() ?? 0;
    final elapsed = DateTime.now().difference(started).inMicroseconds / 1000.0;
    return _DbInfo(
      version: v,
      messagesColumns: msgCols,
      threadsColumns: thrCols,
      messagesCount: totalMsgs,
      threadsCount: totalThreads,
      sumThreadMessageCount: sumThreadMsgs,
      queryMs: elapsed,
    );
  }

  String _formatMs(double ms) {
    if (ms < 1000) return '${ms.toStringAsFixed(0)}ms';
    final s = ms / 1000.0;
    return s >= 10 ? '${s.toStringAsFixed(0)}s' : '${s.toStringAsFixed(1)}s';
  }
}

class _DbInfo {
  final int version;
  final List<String> messagesColumns;
  final List<String> threadsColumns;
  final int messagesCount;
  final int threadsCount;
  final int sumThreadMessageCount;
  final double? queryMs;
  _DbInfo({
    required this.version,
    required this.messagesColumns,
    required this.threadsColumns,
    required this.messagesCount,
    required this.threadsCount,
    required this.sumThreadMessageCount,
    this.queryMs,
  });
}

class AltrixThreadMessagesPage extends StatelessWidget {
  final String threadId;
  final String title;
  const AltrixThreadMessagesPage({
    super.key,
    required this.threadId,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _loadMessages(),
        builder: (context, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final rows = snap.data!;
          if (rows.isEmpty)
            return const Center(child: Text('No messages in this thread'));
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = rows[i];
              final role = (r['role'] ?? '').toString();
              final status = (r['status'] ?? '').toString();
              final tok = (r['tokens_used'] as int?) ?? 0;
              final lat = (r['latency_ms'] as int?) ?? 0;
              final gem = (r['is_gemini_response'] as int?) == 1;
              final preview = (r['content'] ?? '').toString();
              return ListTile(
                title: Row(
                  children: [
                    if (gem)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Gemini',
                          style: TextStyle(color: Colors.red, fontSize: 11),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        '$role: ${preview.length > 60 ? preview.substring(0, 60) + '…' : preview}',
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  [
                    'status: ${status.isEmpty ? 'n/a' : status}',
                    if (tok > 0) 'tokens: $tok',
                    if (lat > 0) 'latency: ${_formatMs(lat.toDouble())}',
                  ].join(' • '),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<Map<String, Object?>>> _loadMessages() async {
    final db = await AppDatabase.instance();
    return db.query(
      AppDatabase.tableAltrixMessages,
      where: 'thread_id = ?',
      whereArgs: [threadId],
      orderBy: 'created_at ASC',
    );
  }

  String _formatMs(double ms) {
    if (ms < 1000) return '${ms.toStringAsFixed(0)}ms';
    final s = ms / 1000.0;
    return s >= 10 ? '${s.toStringAsFixed(0)}s' : '${s.toStringAsFixed(1)}s';
  }
}

Future<void> _exportThreadToJson(
  BuildContext context,
  String threadId,
  String title,
) async {
  try {
    final db = await AppDatabase.instance();
    final thr = await AltrixSqlHelpers.getAltrixThreadById(threadId);
    final msgs = await db.query(
      AppDatabase.tableAltrixMessages,
      where: 'thread_id = ?',
      whereArgs: [threadId],
      orderBy: 'created_at ASC',
    );
    final payload = {'thread': thr, 'messages': msgs};
    // Show a simple dialog with JSON preview; in a real app, write to file/share.
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Export ${title.isEmpty ? threadId : title}'),
        content: SingleChildScrollView(child: Text(payload.toString())),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
  }
}
