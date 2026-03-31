import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/category.dart';
import '../../models/question.dart';
import '../../models/score_record.dart';

class DatabaseHelper {
  static const String _dbName = 'recall_quiz.db';
  static const int _dbVersion = 1;

  static const String _tableCategories = 'categories';
  static const String _tableQuestions = 'questions';
  static const String _tableScoreRecords = 'score_records';

  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
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
        created_at TEXT    NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $_tableQuestions (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        question    TEXT    NOT NULL,
        answer      TEXT    NOT NULL,
        category_id INTEGER NOT NULL,
        created_at  TEXT    NOT NULL,
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
        FOREIGN KEY (question_id)
          REFERENCES $_tableQuestions (id) ON DELETE CASCADE,
        FOREIGN KEY (category_id)
          REFERENCES $_tableCategories (id) ON DELETE CASCADE
      )
    ''');

    await _seedDefaultCategories(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations go here
    // if (oldVersion < 2) { await db.execute('ALTER TABLE ...'); }
  }

  Future<void> _seedDefaultCategories(Database db) async {
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final entry in [
      {'name': 'Work',    'icon': '💼'},
      {'name': 'Cook',    'icon': '🍳'},
      {'name': 'Coffee',  'icon': '☕'},
      {'name': 'General', 'icon': '📌'},
    ]) {
      batch.insert(_tableCategories, {...entry, 'created_at': now});
    }
    await batch.commit(noResult: true);
  }

  // ── Categories ──────────────────────────────────────────────────────────────

  Future<int> insertCategory(Category c) async =>
      (await database).insert(_tableCategories, c.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<Category>> getAllCategories() async {
    final rows = await (await database).query(_tableCategories, orderBy: 'name ASC');
    return rows.map(Category.fromMap).toList();
  }

  Future<Category?> getCategoryById(int id) async {
    final rows = await (await database).query(_tableCategories,
        where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Category.fromMap(rows.first);
  }

  Future<int> updateCategory(Category c) async =>
      (await database).update(_tableCategories, c.toMap(),
          where: 'id = ?', whereArgs: [c.id]);

  Future<int> deleteCategory(int id) async =>
      (await database).delete(_tableCategories, where: 'id = ?', whereArgs: [id]);

  // ── Questions ───────────────────────────────────────────────────────────────

  Future<int> insertQuestion(Question q) async =>
      (await database).insert(_tableQuestions, q.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<Question>> getAllQuestions({int? categoryId}) async {
    final db = await database;
    final rows = await db.query(_tableQuestions,
        where: categoryId != null ? 'category_id = ?' : null,
        whereArgs: categoryId != null ? [categoryId] : null,
        orderBy: 'created_at DESC');
    return rows.map(Question.fromMap).toList();
  }

  Future<Question?> getRandomQuestion({int? categoryId}) async {
    final db = await database;
    final rows = await db.query(_tableQuestions,
        where: categoryId != null ? 'category_id = ?' : null,
        whereArgs: categoryId != null ? [categoryId] : null,
        orderBy: 'RANDOM()',
        limit: 1);
    return rows.isEmpty ? null : Question.fromMap(rows.first);
  }

  Future<int> updateQuestion(Question q) async =>
      (await database).update(_tableQuestions, q.toMap(),
          where: 'id = ?', whereArgs: [q.id]);

  Future<int> deleteQuestion(int id) async =>
      (await database).delete(_tableQuestions, where: 'id = ?', whereArgs: [id]);

  // ── Score Records ────────────────────────────────────────────────────────────

  Future<int> insertScoreRecord(ScoreRecord r) async =>
      (await database).insert(_tableScoreRecords, r.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<ScoreRecord>> getAllScoreRecords({int? categoryId}) async {
    final db = await database;
    final rows = await db.query(_tableScoreRecords,
        where: categoryId != null ? 'category_id = ?' : null,
        whereArgs: categoryId != null ? [categoryId] : null,
        orderBy: 'answered_at DESC');
    return rows.map(ScoreRecord.fromMap).toList();
  }

  Future<int> deleteScoreRecord(int id) async =>
      (await database).delete(_tableScoreRecords,
          where: 'id = ?', whereArgs: [id]);

  // ── Stats ────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCategoryScoreStats() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        c.id          AS cat_id,
        c.name        AS cat_name,
        c.icon        AS cat_icon,
        c.created_at  AS cat_created_at,
        COUNT(sr.id)  AS total,
        SUM(CASE WHEN sr.is_correct = 1 THEN 1 ELSE 0 END) AS correct
      FROM $_tableCategories c
      INNER JOIN $_tableScoreRecords sr ON sr.category_id = c.id
      GROUP BY c.id
      ORDER BY c.name ASC
    ''');

    return rows.map((row) {
      final total   = row['total'] as int;
      final correct = (row['correct'] as num).toInt();
      return {
        'category': Category(
          id: row['cat_id'] as int,
          name: row['cat_name'] as String,
          icon: row['cat_icon'] as String,
          createdAt: DateTime.parse(row['cat_created_at'] as String),
        ),
        'total':      total,
        'correct':    correct,
        'percentage': total > 0 ? (correct / total) * 100.0 : 0.0,
      };
    }).toList();
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
