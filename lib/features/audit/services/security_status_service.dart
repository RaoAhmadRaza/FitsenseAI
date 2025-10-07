import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;
import '../../../core/db/app_database.dart';

class SecurityStatusService {
  const SecurityStatusService();

  // Best-effort check: SQLCipher exposes a cipher_version pragma.
  Future<bool> isSqlCipherEnabled() async {
    try {
      final db = await AppDatabase.instance();
      final rows = await db.rawQuery('PRAGMA cipher_version;');
      // Rows may look like: [{'cipher_version(0)': '4.5.6'}] depending on platform
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // We bundle these files as assets; presence indicates CI security scaffolding exists.
  Future<bool> hasCiWorkflow() async =>
      _assetExists('.github/workflows/security-audit.yml');
  Future<bool> hasSemgrepRules() async => _assetExists('.semgrep/semgrep.yml');
  Future<bool> hasLocalAuditScript() async =>
      _assetExists('scripts/run-audit.sh');

  // Attempt to load an asset; return true if found.
  Future<bool> _assetExists(String path) async {
    try {
      await rootBundle.loadString(path);
      return true;
    } catch (_) {
      return false;
    }
  }
}
