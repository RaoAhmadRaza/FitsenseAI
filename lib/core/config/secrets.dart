import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized helper to retrieve secrets safely.
/// Priority:
/// 1) flutter_secure_storage (persisted per device)
/// 2) --dart-define=GEMINI_API_KEY (compile-time, for CI/dev only)
/// 3) .env (dev convenience; not bundled in release builds)
class Secrets {
  static const _kGeminiKeyName = 'gemini_api_key';

  static Future<String?> getGeminiApiKey() async {
    try {
      const storage = FlutterSecureStorage();
      String? key = await storage.read(key: _kGeminiKeyName);
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}

    // Compile-time define fallback (safe for CI/testing, avoid in prod releases)
    const defined = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
    if (defined.isNotEmpty) return defined;

    // Dev-only .env fallback
    try {
      final env = dotenv.maybeGet('GEMINI_API_KEY');
      if ((env ?? '').isNotEmpty) return env;
    } catch (_) {}

    if (kDebugMode) debugPrint('[Secrets] No GEMINI_API_KEY available');
    return null;
  }

  /// Best-effort persist into secure storage when sourced from env/defines.
  static Future<void> persistGeminiKeyIfMissing(String? candidate) async {
    if (candidate == null || candidate.isEmpty) return;
    try {
      const storage = FlutterSecureStorage();
      final existing = await storage.read(key: _kGeminiKeyName);
      if ((existing ?? '').isEmpty) {
        await storage.write(key: _kGeminiKeyName, value: candidate);
      }
    } catch (_) {}
  }
}
