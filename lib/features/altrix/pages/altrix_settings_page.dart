import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/services/local_storage_service.dart';
import '../../altrix/utils/altrix_constants.dart';
import '../../presentation/widgets/colors.dart';
import 'altrix_analytics_log_page.dart';

class AltrixSettingsPage extends StatelessWidget {
  const AltrixSettingsPage({super.key});

  Future<Box> _ensureSettingsBox() async {
    if (Hive.isBoxOpen(AltrixConstants.settingsBox)) {
      return Hive.box(AltrixConstants.settingsBox);
    }
    try {
      // Encrypted open using shared key via LocalStorageService
      final storage = LocalStorageService();
      return await storage.openEncryptedDynamicBox(AltrixConstants.settingsBox);
    } catch (_) {
      // Last-resort: unencrypted open to avoid UI crash
      return await Hive.openBox(AltrixConstants.settingsBox);
    }
  }

  Future<Box?> _ensureAnalyticsBox() async {
    try {
      if (Hive.isBoxOpen(AltrixConstants.analyticsBox)) {
        return Hive.box(AltrixConstants.analyticsBox);
      }
      final storage = LocalStorageService();
      return await storage.openEncryptedDynamicBox(
        AltrixConstants.analyticsBox,
      );
    } catch (_) {
      // It's okay to fail silently; developer info will be hidden
      try {
        return await Hive.openBox(AltrixConstants.analyticsBox);
      } catch (_) {
        return null;
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
          'ALTRIX SETTINGS',
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
        child: FutureBuilder<Box>(
          future: _ensureSettingsBox(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CupertinoActivityIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Unable to open settings. Please try again.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              );
            }
            final settingsBox = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                const SizedBox(height: 6),
                ValueListenableBuilder(
                  valueListenable: settingsBox.listenable(
                    keys: ['altrixVoiceMode'],
                  ),
                  builder: (_, Box box, __) {
                    final voice =
                        box.get('altrixVoiceMode', defaultValue: false) as bool;
                    return _IosSwitchTile(
                      leading: const Icon(
                        CupertinoIcons.mic_fill,
                        color: Colors.black,
                        size: 18,
                      ),
                      title: 'Voice Mode',
                      subtitle: 'Speak responses aloud',
                      value: voice,
                      onChanged: (v) => box.put('altrixVoiceMode', v),
                    );
                  },
                ),
                ValueListenableBuilder(
                  valueListenable: settingsBox.listenable(
                    keys: ['altrixPersonalityFriendly'],
                  ),
                  builder: (_, Box box, __) {
                    final friendly =
                        box.get('altrixPersonalityFriendly', defaultValue: true)
                            as bool;
                    return _IosSwitchTile(
                      leading: const Icon(
                        CupertinoIcons.person_crop_circle,
                        color: Colors.black,
                        size: 18,
                      ),
                      title: 'Altrix Personality',
                      subtitle: friendly
                          ? 'Friendly — encouraging and warm'
                          : 'Coach — direct and focused',
                      value: friendly,
                      onChanged: (v) => box.put('altrixPersonalityFriendly', v),
                    );
                  },
                ),
                ValueListenableBuilder(
                  valueListenable: settingsBox.listenable(
                    keys: ['altrixTextFast'],
                  ),
                  builder: (_, Box box, __) {
                    final fast =
                        box.get('altrixTextFast', defaultValue: false) as bool;
                    return _IosSwitchTile(
                      leading: const Icon(
                        CupertinoIcons.speedometer,
                        color: Colors.black,
                        size: 18,
                      ),
                      title: 'Text Speed',
                      subtitle: fast ? 'Fast reveal' : 'Normal reveal speed',
                      value: fast,
                      onChanged: (v) => box.put('altrixTextFast', v),
                    );
                  },
                ),
                const SizedBox(height: 12),
                // Developer Info (internal diagnostics)
                FutureBuilder<Box?>(
                  future: _ensureAnalyticsBox(),
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const SizedBox.shrink();
                    }
                    final analyticsBox = snap.data;
                    if (analyticsBox == null) return const SizedBox.shrink();
                    return ValueListenableBuilder(
                      valueListenable: analyticsBox.listenable(),
                      builder: (_, Box box, __) {
                        final raw = box.get('gemini_metrics_global');
                        if (raw is! Map) {
                          return _DeveloperInfoCard(
                            model: '—',
                            avgLatencyMs: 0,
                            totalTokens: 0,
                            errorRatePct: 0,
                            recentWindow: 0,
                          );
                        }
                        final m = Map<String, Object?>.from(raw);
                        final model =
                            (m['model'] as String?) ?? 'gemini-2.0-flash';
                        final totalTokens = (m['totalTokens'] as int?) ?? 0;
                        final avgLatency = (m['avgLatencyMs'] is num)
                            ? (m['avgLatencyMs'] as num).toDouble()
                            : 0.0;
                        final recent =
                            (m['recent'] as List?)?.cast<String>() ??
                            <String>[];
                        final window = recent.length;
                        final errCount = recent
                            .where((e) => e == 'error')
                            .length;
                        final errorRatePct = window == 0
                            ? 0
                            : ((errCount / window) * 100).round();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            const Text(
                              'Developer Info',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _DeveloperInfoCard(
                              model: model,
                              avgLatencyMs: avgLatency.round(),
                              totalTokens: totalTokens,
                              errorRatePct: errorRatePct,
                              recentWindow: window,
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.vibrantRed,
                                ),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const AltrixAnalyticsLogPage(),
                                    ),
                                  );
                                },
                                icon: const Icon(CupertinoIcons.list_bullet),
                                label: const Text('View analytics log'),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _IosSwitchTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _IosSwitchTile({
    this.leading,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            const SizedBox(width: 6),
            leading!,
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    fontFamily: 'Sora',
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Transform.scale(
            scale: 0.9,
            alignment: Alignment.centerRight,
            child: CupertinoSwitch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.vibrantRed,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _DeveloperInfoCard extends StatelessWidget {
  final String model;
  final int avgLatencyMs;
  final int totalTokens;
  final int errorRatePct; // computed over recent window
  final int recentWindow;
  const _DeveloperInfoCard({
    required this.model,
    required this.avgLatencyMs,
    required this.totalTokens,
    required this.errorRatePct,
    required this.recentWindow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.sparkles,
                size: 16,
                color: Colors.black,
              ),
              const SizedBox(width: 6),
              Text(
                model,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _kv('Avg latency', '${avgLatencyMs} ms'),
          const SizedBox(height: 4),
          _kv('Total tokens', _formatInt(totalTokens)),
          const SizedBox(height: 4),
          _kv(
            'Error rate',
            recentWindow == 0 ? '—' : '$errorRatePct% (last $recentWindow)',
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
        Text(
          v,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  static String _formatInt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i != 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
