import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/category.dart';
import '../../models/question.dart';
import '../../models/score_record.dart';

class DatabaseHelper {
  static const String _dbName = 'recall_quiz.db';
  static const int _dbVersion = 5;

  static const String _tableCategories = 'categories';
  static const String _tableQuestions = 'questions';
  static const String _tableScoreRecords = 'score_records';
  static const String _tableSyncDeletions = 'sync_deletions';

  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  // Stream to notify listeners (like SyncService) when data changes locally
  final _updateController = StreamController<void>.broadcast();
  Stream<void> get onDatabaseUpdated => _updateController.stream;

  /// Manually triggers a database update event to refresh the UI.
  void notifyUpdate() {
    _updateController.add(null);
  }

  Future<void> dispose() async {
    await _updateController.close();
    await _db?.close();
    _db = null;
  }

  Database? _db;
  String? _dbPathOverride;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbPathOverride ?? _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableCategories (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT    NOT NULL,
        icon       TEXT    NOT NULL,
        created_at TEXT    NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT    NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $_tableQuestions (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        question    TEXT    NOT NULL,
        answer      TEXT    NOT NULL,
        category_id INTEGER NOT NULL,
        created_at  TEXT    NOT NULL,
        updated_at  TEXT    NOT NULL,
        FOREIGN KEY (category_id)
          REFERENCES $_tableCategories (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE $_tableScoreRecords (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        question_id INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        is_correct  INTEGER NOT NULL CHECK (is_correct IN (0, 1)),
        answered_at TEXT    NOT NULL,
        updated_at  TEXT    NOT NULL,
        FOREIGN KEY (question_id)
          REFERENCES $_tableQuestions (id) ON DELETE CASCADE,
        FOREIGN KEY (category_id)
          REFERENCES $_tableCategories (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE $_tableSyncDeletions (
        collection TEXT NOT NULL,
        doc_id     INTEGER NOT NULL,
        deleted_at TEXT NOT NULL,
        PRIMARY KEY (collection, doc_id)
      )
    ''');

    await _seedDefaultCategories(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v1 → v2: trim seeded categories from 4 down to 2.
      await db.execute('''
        DELETE FROM $_tableCategories
        WHERE name IN ('Coffee', 'Cook')
          AND id NOT IN (SELECT DISTINCT category_id FROM $_tableQuestions)
      ''');
    }
    if (oldVersion < 3) {
      // v2 → v3: add is_default column; mark General and Work as default.
      await db.execute(
        'ALTER TABLE $_tableCategories ADD COLUMN is_default INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        "UPDATE $_tableCategories SET is_default = 1 WHERE name IN ('General', 'Work')",
      );
    }
    if (oldVersion < 4) {
      // v3 → v4: add updated_at for cloud sync conflict resolution
      final now = DateTime.now().toIso8601String();
      await db.execute(
        'ALTER TABLE $_tableCategories ADD COLUMN updated_at TEXT NOT NULL DEFAULT "$now"',
      );
      await db.execute(
        'ALTER TABLE $_tableQuestions ADD COLUMN updated_at TEXT NOT NULL DEFAULT "$now"',
      );
      await db.execute(
        'ALTER TABLE $_tableScoreRecords ADD COLUMN updated_at TEXT NOT NULL DEFAULT "$now"',
      );
    }
    if (oldVersion < 5) {
      // v4 → v5: add sync_deletions for tombstone-based delete propagation.
      await db.execute('''
        CREATE TABLE $_tableSyncDeletions (
          collection TEXT NOT NULL,
          doc_id     INTEGER NOT NULL,
          deleted_at TEXT NOT NULL,
          PRIMARY KEY (collection, doc_id)
        )
      ''');
    }
  }

  Future<void> _seedDefaultCategories(Database db) async {
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final entry in [
      {'name': 'General', 'icon': '📌'},
      {'name': 'Work', 'icon': '💼'},
    ]) {
      batch.insert(_tableCategories, {
        ...entry,
        'created_at': now,
        'updated_at': now,
        'is_default': 1,
      });
    }
    await batch.commit(noResult: true);
  }

  // ── Categories ──────────────────────────────────────────────────────────────

  Future<int> insertCategory(Category c) async {
    final map = c.toMap();
    map['updated_at'] = DateTime.now().toIso8601String();
    final id = await (await database).insert(
      _tableCategories,
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _updateController.add(null);
    return id;
  }

  Future<List<Category>> getAllCategories() async {
    final rows = await (await database).query(
      _tableCategories,
      orderBy: 'name ASC',
    );
    return rows.map(Category.fromMap).toList();
  }

  Future<Category?> getCategoryById(int id) async {
    final rows = await (await database).query(
      _tableCategories,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Category.fromMap(rows.first);
  }

  Future<int> updateCategory(Category c) async {
    final map = c.toMap();
    map['updated_at'] = DateTime.now().toIso8601String();
    final count = await (await database).update(
      _tableCategories,
      map,
      where: 'id = ?',
      whereArgs: [c.id],
    );
    _updateController.add(null);
    return count;
  }

  Future<int> deleteCategory(int id) async {
    final count = await (await database).delete(
      _tableCategories,
      where: 'id = ?',
      whereArgs: [id],
    );
    _updateController.add(null);
    return count;
  }

  // ── Questions ───────────────────────────────────────────────────────────────

  Future<int> insertQuestion(Question q) async {
    final map = q.toMap();
    map['updated_at'] = DateTime.now().toIso8601String();
    final id = await (await database).insert(
      _tableQuestions,
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _updateController.add(null);
    return id;
  }

  Future<List<Question>> getAllQuestions({int? categoryId}) async {
    final db = await database;
    final rows = await db.query(
      _tableQuestions,
      where: categoryId != null ? 'category_id = ?' : null,
      whereArgs: categoryId != null ? [categoryId] : null,
      orderBy: 'created_at DESC',
    );
    return rows.map(Question.fromMap).toList();
  }

  Future<Question?> getQuestionById(int id) async {
    final rows = await (await database).query(
      _tableQuestions,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Question.fromMap(rows.first);
  }

  Future<Question?> getRandomQuestion({
    int? categoryId,
    int? excludeId,
    Set<int>? excludeIds,
  }) async {
    final db = await database;

    // Merge all exclusions into one set
    final allExcluded = <int>{?excludeId, ...?excludeIds};

    final conditions = <String>[];
    final args = <dynamic>[];

    if (categoryId != null) {
      conditions.add('category_id = ?');
      args.add(categoryId);
    }
    if (allExcluded.isNotEmpty) {
      final placeholders = allExcluded.map((_) => '?').join(',');
      conditions.add('id NOT IN ($placeholders)');
      args.addAll(allExcluded);
    }

    final rows = await db.query(
      _tableQuestions,
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'RANDOM()',
      limit: 1,
    );

    // Fallback: if nothing left after exclusions, allow any question
    if (rows.isEmpty && allExcluded.isNotEmpty) {
      return getRandomQuestion(categoryId: categoryId);
    }

    return rows.isEmpty ? null : Question.fromMap(rows.first);
  }

  Future<int> getQuestionCount() async {
    final result = await (await database).rawQuery(
      'SELECT COUNT(*) FROM $_tableQuestions',
    );
    return result.first.values.first as int? ?? 0;
  }

  /// Returns the set of category IDs that have at least one question.
  Future<Set<int>> getUsedCategoryIds() async {
    final rows = await (await database).rawQuery(
      'SELECT DISTINCT category_id FROM $_tableQuestions',
    );
    return rows.map((r) => r['category_id'] as int).toSet();
  }

  Future<int> updateQuestion(Question q) async {
    final map = q.toMap();
    map['updated_at'] = DateTime.now().toIso8601String();
    final count = await (await database).update(
      _tableQuestions,
      map,
      where: 'id = ?',
      whereArgs: [q.id],
    );
    _updateController.add(null);
    return count;
  }

  Future<int> deleteQuestion(int id) async {
    final count = await (await database).delete(
      _tableQuestions,
      where: 'id = ?',
      whereArgs: [id],
    );
    _updateController.add(null);
    return count;
  }

  // ── Score Records ────────────────────────────────────────────────────────────

  Future<int> insertScoreRecord(ScoreRecord r) async {
    final map = r.toMap();
    map['updated_at'] = DateTime.now().toIso8601String();
    final id = await (await database).insert(
      _tableScoreRecords,
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _updateController.add(null);
    return id;
  }

  Future<List<ScoreRecord>> getAllScoreRecords({int? categoryId}) async {
    final db = await database;
    final rows = await db.query(
      _tableScoreRecords,
      where: categoryId != null ? 'category_id = ?' : null,
      whereArgs: categoryId != null ? [categoryId] : null,
      orderBy: 'answered_at DESC',
    );
    return rows.map(ScoreRecord.fromMap).toList();
  }

  Future<int> deleteScoreRecord(int id) async {
    final count = await (await database).delete(
      _tableScoreRecords,
      where: 'id = ?',
      whereArgs: [id],
    );
    _updateController.add(null);
    return count;
  }

  // ── Sync Deletions (tombstone journal) ───────────────────────────────────────

  Future<void> addTombstone(String collection, int docId) async {
    final db = await database;
    await db.rawInsert(
      'INSERT OR IGNORE INTO $_tableSyncDeletions (collection, doc_id, deleted_at) '
      'VALUES (?, ?, ?)',
      [collection, docId, DateTime.now().toIso8601String()],
    );
  }

  Future<void> addTombstones(String collection, Iterable<int> docIds) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final docId in docIds) {
        await txn.rawInsert(
          'INSERT OR IGNORE INTO $_tableSyncDeletions (collection, doc_id, deleted_at) '
          'VALUES (?, ?, ?)',
          [collection, docId, DateTime.now().toIso8601String()],
        );
      }
    });
  }

  Future<Map<String, Set<int>>> getAllTombstones() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT collection, doc_id FROM $_tableSyncDeletions',
    );
    final tombstones = <String, Set<int>>{};
    for (final row in rows) {
      final collection = row['collection'] as String;
      final docId = row['doc_id'] as int;
      tombstones.putIfAbsent(collection, () => <int>{}).add(docId);
    }
    return tombstones;
  }

  Future<void> removeTombstones(String collection, Iterable<int> docIds) async {
    final ids = docIds.toList();
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(', ');
    await db.rawDelete(
      'DELETE FROM $_tableSyncDeletions WHERE collection = ? AND doc_id IN ($placeholders)',
      [collection, ...ids],
    );
  }

  Future<Set<int>> getTombstonedIds(String collection) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT doc_id FROM $_tableSyncDeletions WHERE collection = ?',
      [collection],
    );
    return rows.map((row) => row['doc_id'] as int).toSet();
  }

  // ── Stats ────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCategoryScoreStats() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        c.id          AS cat_id,
        c.name        AS cat_name,
        c.icon        AS cat_icon,
        c.created_at  AS cat_created_at,
        c.updated_at  AS cat_updated_at,
        COUNT(sr.id)  AS total,
        SUM(CASE WHEN sr.is_correct = 1 THEN 1 ELSE 0 END) AS correct
      FROM $_tableCategories c
      INNER JOIN $_tableScoreRecords sr ON sr.category_id = c.id
      GROUP BY c.id
      ORDER BY c.name ASC
    ''');

    return rows.map((row) {
      final total = row['total'] as int;
      final correct = (row['correct'] as num).toInt();
      return {
        'category': Category(
          id: row['cat_id'] as int,
          name: row['cat_name'] as String,
          icon: row['cat_icon'] as String,
          createdAt: DateTime.parse(row['cat_created_at'] as String),
          updatedAt: DateTime.parse(row['cat_updated_at'] as String),
        ),
        'total': total,
        'correct': correct,
        'percentage': total > 0 ? (correct / total) * 100.0 : 0.0,
      };
    }).toList();
  }

  /// Completely clears all user data from the local database.
  /// Used during sign-out to ensure privacy between different accounts.
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(_tableScoreRecords);
      await txn.delete(_tableQuestions);
      await txn.delete(_tableCategories, where: 'is_default = 0');
    });
  }

  /// The database file name (or overridden test path) currently in use.
  /// Mirrors the path used by `_initDatabase()` minus the databases directory.
  @visibleForTesting
  String get dbPathForTesting => _dbPathOverride ?? _dbName;

  /// Closes the open database and swaps the path used by the next `database`
  /// access. Intended for tests that need an isolated database file.
  @visibleForTesting
  Future<void> overrideDbPathForTesting(String path) async {
    await close();
    _dbPathOverride = path;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
