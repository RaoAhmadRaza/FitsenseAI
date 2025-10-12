import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/services/local_storage_service.dart';
import '../../altrix/utils/altrix_constants.dart';

class AltrixAnalyticsLogPage extends StatefulWidget {
  const AltrixAnalyticsLogPage({super.key});

  @override
  State<AltrixAnalyticsLogPage> createState() => _AltrixAnalyticsLogPageState();
}

class _AltrixAnalyticsLogPageState extends State<AltrixAnalyticsLogPage> {
  Box? _box;
  String? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      if (Hive.isBoxOpen(AltrixConstants.analyticsBox)) {
        setState(() => _box = Hive.box(AltrixConstants.analyticsBox));
        return;
      }
      final storage = LocalStorageService();
      final box = await storage.openEncryptedDynamicBox(
        AltrixConstants.analyticsBox,
      );
      setState(() => _box = box);
    } catch (e) {
      try {
        final box = await Hive.openBox(AltrixConstants.analyticsBox);
        setState(() => _box = box);
      } catch (e2) {
        setState(() => _error = 'Unable to open analytics log');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
        title: const Text(
          'Analytics Log',
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 1.2,
            color: Color(0xFF111827),
          ),
        ),
      ),
      body: SafeArea(
        child: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              )
            : (_box == null
                  ? const Center(child: CupertinoActivityIndicator())
                  : ValueListenableBuilder(
                      valueListenable: _box!.listenable(),
                      builder: (_, Box box, __) {
                        // Collect last 20 entries (by key order). Box values are append-only numbers.
                        final keys = box.keys.toList();
                        keys.sort();
                        final lastKeys = keys.reversed.take(20).toList();
                        final entries = lastKeys
                            .map((k) => box.get(k))
                            .whereType<Map>()
                            .toList();

                        if (entries.isEmpty) {
                          return const Center(
                            child: Text('No analytics events yet'),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: entries.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final item = entries[i];
                            final name = (item['name'] as String?) ?? 'event';
                            final ts = (item['ts'] as String?) ?? '';
                            final data = item['data'];
                            String subtitle;
                            if (data is Map) {
                              final thread = data['threadId'];
                              final tokens = data['tokens'];
                              final code = data['code'];
                              final latency = data['latencyMs'];
                              final model = data['model'];
                              subtitle = [
                                if (thread != null) 'thread: $thread',
                                if (tokens != null) 'tokens: $tokens',
                                if (latency != null) 'latency: ${latency}ms',
                                if (code != null) 'code: $code',
                                if (model != null) 'model: $model',
                              ].join(' • ');
                            } else {
                              subtitle = '';
                            }
                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              title: Text(
                                name,
                                style: const TextStyle(color: Colors.black),
                              ),
                              subtitle: Text(
                                subtitle.isEmpty ? ts : '$ts\n$subtitle',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            );
                          },
                        );
                      },
                    )),
      ),
    );
  }
}
