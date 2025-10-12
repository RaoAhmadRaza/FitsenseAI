import 'package:sqflite_sqlcipher/sqflite.dart';

/// Migration to DB v4: add Gemini metadata columns to altrix tables.
Future<void> migrateToV4(Database db) async {
  // Extend altrix_messages
  try {
    await db.execute(
      'ALTER TABLE altrix_messages ADD COLUMN status TEXT DEFAULT "success"',
    );
  } catch (_) {}
  try {
    await db.execute(
      'ALTER TABLE altrix_messages ADD COLUMN tokens_used INTEGER DEFAULT 0',
    );
  } catch (_) {}
  try {
    await db.execute(
      'ALTER TABLE altrix_messages ADD COLUMN latency_ms INTEGER DEFAULT 0',
    );
  } catch (_) {}
  try {
    await db.execute(
      'ALTER TABLE altrix_messages ADD COLUMN is_gemini_response INTEGER DEFAULT 0',
    );
  } catch (_) {}

  // Extend altrix_threads
  try {
    await db.execute(
      'ALTER TABLE altrix_threads ADD COLUMN model TEXT DEFAULT "gemini-2.0-flash"',
    );
  } catch (_) {}
  try {
    await db.execute(
      'ALTER TABLE altrix_threads ADD COLUMN prompt_count INTEGER DEFAULT 0',
    );
  } catch (_) {}
  try {
    await db.execute(
      'ALTER TABLE altrix_threads ADD COLUMN avg_latency_ms REAL DEFAULT 0',
    );
  } catch (_) {}
}

/// Placeholder for future database migrations (v4) related to Altrix memory.
/// If/when we add SQLite tables for threads/messages, wire migrations here.
class MigrationsV4 {
  static Future<void> run() async {
    // No-op for now. Reserved for future expansion.
  }
}
