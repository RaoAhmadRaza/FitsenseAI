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
      2; // Increment when altering schema (add migrations)

  // Tables
  static const tableUserProfile = 'user_profile';
  static const tableWorkouts = 'workouts';
  // New normalized session tracking tables (v1 additive; safe alongside legacy `workouts`).
  static const tableWorkoutSessions = 'workout_sessions';
  static const tableExerciseProgress = 'exercise_progress';
  // Fine-grained per-set storage (added after initial session implementation)
  static const tableExerciseSets = 'exercise_sets';
  // Workout plan template layer (introduced v2)
  static const tableWorkoutPlans = 'workout_plans';
  static const tableWorkoutPlanExercises = 'workout_plan_exercises';
  static const tableWorkoutPlanEquipment = 'workout_plan_equipment';

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
        // Migration path (incremental, fall-through style if future versions added)
        if (oldV < 2) {
          // v2 adds workout plan normalization tables (pure additive)
          await _createWorkoutPlanTables(db);
        }
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

    // Structured workout sessions (higher fidelity vs legacy workouts table)
    await db.execute('''
      CREATE TABLE $tableWorkoutSessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_id TEXT NOT NULL,
        date TEXT NOT NULL,              -- start datetime ISO8601
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        completed INTEGER NOT NULL DEFAULT 0
      );
    ''');

    await db.execute('''
      CREATE TABLE $tableExerciseProgress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        exercise_id TEXT NOT NULL,
        completed_sets INTEGER NOT NULL DEFAULT 0,
        completed_reps INTEGER NOT NULL DEFAULT 0,
        used_weight INTEGER NOT NULL DEFAULT 0,
        time_spent INTEGER NOT NULL DEFAULT 0, -- seconds
        FOREIGN KEY(session_id) REFERENCES $tableWorkoutSessions(id) ON DELETE CASCADE
      );
    ''');

    // Per-set granularity (optional analytics, volume trend, pacing)
    await db.execute('''
      CREATE TABLE $tableExerciseSets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        exercise_id TEXT NOT NULL,
        set_index INTEGER NOT NULL,
        reps INTEGER NOT NULL,
        weight INTEGER NOT NULL,
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        recorded_at TEXT NOT NULL,
        FOREIGN KEY(session_id) REFERENCES $tableWorkoutSessions(id) ON DELETE CASCADE,
        UNIQUE(session_id, exercise_id, set_index) ON CONFLICT REPLACE
      );
    ''');

    // v2 tables (included on fresh install)
    await _createWorkoutPlanTables(db);
  }

  /// Create workout plan related tables (idempotent when called in migration path).
  static Future<void> _createWorkoutPlanTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableWorkoutPlans (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        level TEXT NOT NULL,
        duration_display TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableWorkoutPlanExercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id TEXT NOT NULL,
        exercise_id TEXT NOT NULL,
        name TEXT NOT NULL,
        target_muscle TEXT NOT NULL,
        image_path TEXT NOT NULL,
        gif_url TEXT NOT NULL,
        sets INTEGER NOT NULL,
        reps INTEGER NOT NULL,
        weight INTEGER,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(plan_id) REFERENCES $tableWorkoutPlans(id) ON DELETE CASCADE,
        UNIQUE(plan_id, exercise_id) ON CONFLICT REPLACE
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableWorkoutPlanEquipment (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id TEXT NOT NULL,
        equipment TEXT NOT NULL,
        FOREIGN KEY(plan_id) REFERENCES $tableWorkoutPlans(id) ON DELETE CASCADE,
        UNIQUE(plan_id, equipment) ON CONFLICT IGNORE
      );
    ''');
  }

  // =============================
  // User Profile Helpers
  // =============================

  /// Persist in-memory globals to the SQLite user_profile table (upsert id=1).
  static Future<void> saveUserProfileFromGlobals() async {
    final db = await AppDatabase.instance();
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
      await db.delete(tableExerciseProgress);
      await db.delete(tableWorkoutSessions);
    } catch (e, st) {
      logError('DB nukeAllData failed: $e', st);
    }
  }
}

// =============================
// Session CRUD Helpers (kept outside class for now? We integrate inside class for cohesion)
// =============================

extension WorkoutSessionSqlHelpers on AppDatabase {
  static Future<int> insertWorkoutSession({
    required String workoutId,
    required DateTime date,
  }) async {
    final db = await AppDatabase.instance();
    return db.insert(AppDatabase.tableWorkoutSessions, {
      'workout_id': workoutId,
      'date': date.toIso8601String(),
      'duration_seconds': 0,
      'completed': 0,
    });
  }

  static Future<int> updateWorkoutSession({
    required int id,
    int? durationSeconds,
    bool? completed,
  }) async {
    final db = await AppDatabase.instance();
    return db.update(
      AppDatabase.tableWorkoutSessions,
      {
        if (durationSeconds != null) 'duration_seconds': durationSeconds,
        if (completed != null) 'completed': completed ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Insert or replace (by unique constraint) an exercise set row.
  static Future<void> upsertExerciseSet({
    required int sessionRowId,
    required String exerciseId,
    required int setIndex,
    required int reps,
    required int weight,
    required int durationSeconds,
    required DateTime recordedAt,
  }) async {
    final db = await AppDatabase.instance();
    try {
      await db.insert(
        AppDatabase.tableExerciseSets,
        {
          'session_id': sessionRowId,
          'exercise_id': exerciseId,
          'set_index': setIndex,
          'reps': reps,
          'weight': weight,
          'duration_seconds': durationSeconds,
          'recorded_at': recordedAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, st) {
      logError('DB upsertExerciseSet failed: $e', st);
    }
  }

  static Future<Map<String, Object?>?> getOngoingSessionRow() async {
    final db = await AppDatabase.instance();
    final rows = await db.query(
      AppDatabase.tableWorkoutSessions,
      where: 'completed = 0',
      orderBy: 'date DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  static Future<Map<String, Object?>?> getLastCompletedSessionRow() async {
    final db = await AppDatabase.instance();
    final rows = await db.query(
      AppDatabase.tableWorkoutSessions,
      where: 'completed = 1',
      orderBy: 'date DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  static Future<int> insertExerciseProgress({
    required int sessionId,
    required String exerciseId,
    int completedSets = 0,
    int completedReps = 0,
    int usedWeight = 0,
    int timeSpent = 0,
  }) async {
    final db = await AppDatabase.instance();
    return db.insert(AppDatabase.tableExerciseProgress, {
      'session_id': sessionId,
      'exercise_id': exerciseId,
      'completed_sets': completedSets,
      'completed_reps': completedReps,
      'used_weight': usedWeight,
      'time_spent': timeSpent,
    });
  }

  static Future<int> upsertExerciseProgress({
    required int sessionId,
    required String exerciseId,
    required int completedSets,
    required int completedReps,
    required int usedWeight,
    required int timeSpent,
  }) async {
    final db = await AppDatabase.instance();
    final existing = await db.query(
      AppDatabase.tableExerciseProgress,
      where: 'session_id = ? AND exercise_id = ?',
      whereArgs: [sessionId, exerciseId],
      limit: 1,
    );
    if (existing.isEmpty) {
      return db.insert(AppDatabase.tableExerciseProgress, {
        'session_id': sessionId,
        'exercise_id': exerciseId,
        'completed_sets': completedSets,
        'completed_reps': completedReps,
        'used_weight': usedWeight,
        'time_spent': timeSpent,
      });
    } else {
      final id = existing.first['id'] as int;
      return db.update(
        AppDatabase.tableExerciseProgress,
        {
          'completed_sets': completedSets,
          'completed_reps': completedReps,
          'used_weight': usedWeight,
          'time_spent': timeSpent,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  static Future<List<Map<String, Object?>>> listProgressForSession(
    int sessionId,
  ) async {
    final db = await AppDatabase.instance();
    return db.query(
      AppDatabase.tableExerciseProgress,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'id ASC',
    );
  }
}

// =====================================
// Workout Plan Helpers (SQLite mirror)
// =====================================

extension WorkoutPlanSqlHelpers on AppDatabase {
  static Future<void> upsertWorkoutPlan({
    required String id,
    required String name,
    required String level,
    required String durationDisplay,
    DateTime? createdAt,
  }) async {
    final db = await AppDatabase.instance();
    final nowIso = DateTime.now().toIso8601String();
    await db.insert(AppDatabase.tableWorkoutPlans, {
      'id': id,
      'name': name,
      'level': level,
      'duration_display': durationDisplay,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      'updated_at': nowIso,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> replacePlanExercises({
    required String planId,
    required List<Map<String, Object?>> exercises,
  }) async {
    final db = await AppDatabase.instance();
    final batch = db.batch();
    batch.delete(
      AppDatabase.tableWorkoutPlanExercises,
      where: 'plan_id = ?',
      whereArgs: [planId],
    );
    for (var i = 0; i < exercises.length; i++) {
      final e = exercises[i];
      batch.insert(
        AppDatabase.tableWorkoutPlanExercises,
        {'plan_id': planId, ...e, 'sort_order': i},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<void> replacePlanEquipment({
    required String planId,
    required List<String> equipment,
  }) async {
    final db = await AppDatabase.instance();
    final batch = db.batch();
    batch.delete(
      AppDatabase.tableWorkoutPlanEquipment,
      where: 'plan_id = ?',
      whereArgs: [planId],
    );
    for (final eq in equipment) {
      batch.insert(
        AppDatabase.tableWorkoutPlanEquipment,
        {'plan_id': planId, 'equipment': eq},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, Object?>>> listWorkoutPlans() async {
    final db = await AppDatabase.instance();
    return db.query(AppDatabase.tableWorkoutPlans, orderBy: 'updated_at DESC');
  }

  static Future<List<Map<String, Object?>>> listExercisesForPlan(
    String planId,
  ) async {
    final db = await AppDatabase.instance();
    return db.query(
      AppDatabase.tableWorkoutPlanExercises,
      where: 'plan_id = ?',
      whereArgs: [planId],
      orderBy: 'sort_order ASC',
    );
  }

  static Future<List<Map<String, Object?>>> listEquipmentForPlan(
    String planId,
  ) async {
    final db = await AppDatabase.instance();
    return db.query(
      AppDatabase.tableWorkoutPlanEquipment,
      where: 'plan_id = ?',
      whereArgs: [planId],
      orderBy: 'id ASC',
    );
  }
}
