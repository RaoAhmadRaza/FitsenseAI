// lib/core/db/app_database.dart
// Lightweight SQLite layer for FitSense AI.
//
// Responsibilities:
//  - Open and initialize the app database (lazy singleton)
//  - Provide schema definition + future migration path
//  - Expose simple CRUD helpers for:
//      * user_profile (single-row profile data)
//      * workouts (basic structure for future workout sessions)
//  - Sync helpers to/from global variables declared in main.dart
//
// NOTE: This is intentionally minimal; an ORM/DAO abstraction (e.g., drift)
// can be introduced later if complexity grows.

import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../main.dart' as globals;
import '../../core/utils/logger.dart';

class AppDatabase {
  static const _dbName = 'fitsense.db';
  static const _dbVersion =
      1; // Increment when altering schema (add migrations)

  // Tables
  static const tableUserProfile = 'user_profile';
  static const tableWorkouts = 'workouts';

  static Database? _instance;

  AppDatabase._();

  /// Public accessor; ensures a single opened database instance.
  static Future<Database> instance() async {
    if (_instance != null) return _instance!;

    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);

    _instance = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldV, newV) async {
        // Future migrations go here.
        // Example skeleton:
        // if (oldV < 2) { await db.execute('ALTER TABLE ...'); }
      },
    );
    return _instance!;
  }

  /// Schema (v1)
  static Future<void> _createSchema(Database db) async {
    // Single-row profile (id = 1). Additional fields can be added w/ migrations.
    await db.execute('''
      CREATE TABLE $tableUserProfile (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        name TEXT,
        age INTEGER,
        weight_kg REAL,
        height_cm REAL,
        gender TEXT,
        height_unit TEXT,
        goals TEXT,          -- comma separated list
        primary_goal TEXT,
        updated_at TEXT
      );
    ''');

    // Simple workouts table; extend with metrics later (duration, reps, etc.)
    await db.execute('''
      CREATE TABLE $tableWorkouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,          -- e.g. strength, cardio, yoga
        started_at TEXT NOT NULL,    -- ISO8601
        ended_at TEXT,               -- ISO8601 (nullable if in-progress)
        notes TEXT
      );
    ''');
  }

  // =============================
  // User Profile Helpers
  // =============================

  /// Persist in-memory globals to the SQLite user_profile table (upsert id=1).
  static Future<void> saveUserProfileFromGlobals() async {
    final db = await instance();
    final goalsJoined = globals.gUserGoals.join(',');
    try {
      await db.insert(tableUserProfile, {
        'id': 1,
        'name': globals.gUserDisplayName,
        'age': globals.gUserAge,
        'weight_kg': globals.gUserWeightKg,
        'height_cm': globals.gUserHeightCm,
        'gender': globals.gUserGender,
        'height_unit': globals.gUserHeightUnit,
        'goals': goalsJoined.isEmpty ? null : goalsJoined,
        'primary_goal': globals.gUserPrimaryGoal,
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e, st) {
      logError('DB saveUserProfileFromGlobals failed: $e', st);
      rethrow;
    }
  }

  /// Load profile row into globals (no-op if not present).
  static Future<void> loadUserProfileIntoGlobals() async {
    final db = await instance();
    List<Map<String, Object?>> rows = const [];
    try {
      rows = await db.query(tableUserProfile, where: 'id = 1', limit: 1);
    } catch (e, st) {
      logError('DB loadUserProfileIntoGlobals failed: $e', st);
      return;
    }
    if (rows.isEmpty) return;
    final r = rows.first;
    globals.gUserDisplayName =
        (r['name'] as String?) ?? globals.gUserDisplayName;
    globals.gUserAge = r['age'] as int?;
    globals.gUserWeightKg = (r['weight_kg'] as num?)?.toDouble();
    globals.gUserHeightCm = (r['height_cm'] as num?)?.toDouble();
    globals.gUserGender = r['gender'] as String?;
    globals.gUserHeightUnit =
        (r['height_unit'] as String?) ?? globals.gUserHeightUnit;
    final goalsStr = r['goals'] as String?;
    globals.gUserGoals = goalsStr == null || goalsStr.isEmpty
        ? <String>{}
        : goalsStr.split(',').toSet();
    globals.gUserPrimaryGoal = r['primary_goal'] as String?;
  }

  /// Clear profile (used on sign-out) from both SQLite and globals optionally.
  static Future<void> clearUserProfile({bool resetGlobals = false}) async {
    final db = await instance();
    try {
      await db.delete(tableUserProfile, where: 'id = 1');
    } catch (e, st) {
      logError('DB clearUserProfile failed: $e', st);
    }
    if (resetGlobals) {
      globals.gUserDisplayName = null;
      globals.gUserAge = null;
      globals.gUserWeightKg = null;
      globals.gUserHeightCm = null;
      globals.gUserGender = null;
      globals.gUserGoals = <String>{};
      globals.gUserPrimaryGoal = null;
    }
  }

  // =============================
  // Workout Helpers
  // =============================

  static Future<int> insertWorkout({
    required String type,
    required DateTime startedAt,
    DateTime? endedAt,
    String? notes,
  }) async {
    final db = await instance();
    try {
      return db.insert(tableWorkouts, {
        'type': type,
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
        'notes': notes,
      });
    } catch (e, st) {
      logError('DB insertWorkout failed: $e', st);
      rethrow;
    }
  }

  static Future<int> updateWorkout({
    required int id,
    DateTime? endedAt,
    String? notes,
  }) async {
    final db = await instance();
    try {
      return db.update(
        tableWorkouts,
        {
          if (endedAt != null) 'ended_at': endedAt.toIso8601String(),
          if (notes != null) 'notes': notes,
        },
        where: 'id = ? AND ended_at IS NULL',
        whereArgs: [id],
      );
    } catch (e, st) {
      logError('DB updateWorkout failed: $e', st);
      rethrow;
    }
  }

  static Future<List<Map<String, Object?>>> listWorkouts({int? limit}) async {
    final db = await instance();
    try {
      return db.query(tableWorkouts, orderBy: 'started_at DESC', limit: limit);
    } catch (e, st) {
      logError('DB listWorkouts failed: $e', st);
      rethrow;
    }
  }

  static Future<int> deleteWorkout(int id) async {
    final db = await instance();
    try {
      return db.delete(tableWorkouts, where: 'id = ?', whereArgs: [id]);
    } catch (e, st) {
      logError('DB deleteWorkout failed: $e', st);
      rethrow;
    }
  }

  /// For test / dev resets only.
  static Future<void> nukeAllData() async {
    final db = await instance();
    try {
      await db.delete(tableWorkouts);
      await db.delete(tableUserProfile);
    } catch (e, st) {
      logError('DB nukeAllData failed: $e', st);
    }
  }
}
