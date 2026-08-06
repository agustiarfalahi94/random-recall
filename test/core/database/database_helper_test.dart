import 'package:flutter_test/flutter_test.dart';
import 'package:random_recall/core/database/database_helper.dart';
import 'package:random_recall/models/category.dart';
import 'package:random_recall/models/question.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // `flutter test` has no sqflite platform — use the FFI factory (native SQLite).
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('sync_deletions tombstone journal', () {
    late DatabaseHelper db;
    late String originalPath;

    setUp(() async {
      originalPath = DatabaseHelper.instance.dbPathForTesting;
      DatabaseHelper.instance.overrideDbPathForTesting(
        '${originalPath}_tombstone_test_${DateTime.now().millisecondsSinceEpoch}.db',
      );
      db = DatabaseHelper.instance;
      await db.database; // trigger create + migrate
    });

    tearDown(() async {
      await db.close();
      DatabaseHelper.instance.overrideDbPathForTesting(originalPath);
    });

    test('v5 adds sync_deletions table', () async {
      final db2 = await db.database;
      final rows = await db2.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='sync_deletions'",
      );
      expect(rows, isNotEmpty);
    });

    test('addTombstone then getAllTombstones round-trips', () async {
      await db.addTombstone('questions', 42);
      await db.addTombstone('categories', 7);
      final all = await db.getAllTombstones();
      expect(all['questions'], {42});
      expect(all['categories'], {7});
    });

    test('addTombstone is idempotent (primary key)', () async {
      await db.addTombstone('questions', 1);
      await db.addTombstone('questions', 1);
      final all = await db.getAllTombstones();
      expect(all['questions'], {1});
    });

    test('removeTombstones clears only the given ids', () async {
      await db.addTombstones('questions', [1, 2, 3]);
      await db.removeTombstones('questions', [2]);
      final all = await db.getAllTombstones();
      expect(all['questions'], {1, 3});
    });

    test('getTombstonedIds returns only that collection', () async {
      await db.addTombstones('categories', [10]);
      await db.addTombstones('questions', [20, 21]);
      expect(await db.getTombstonedIds('questions'), {20, 21});
    });

    test('deleteQuestion writes a tombstone', () async {
      final catId = await db.insertCategory(
        Category(
          name: 'T',
          icon: '📌',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final qId = await db.insertQuestion(
        Question(
          question: 'q',
          answer: 'a',
          categoryId: catId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await db.deleteQuestion(qId);
      final all = await db.getAllTombstones();
      expect(all['questions'], contains(qId));
    });

    test('deleteCategory tombstones the category and its questions', () async {
      final catId = await db.insertCategory(
        Category(
          name: 'T',
          icon: '📌',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final q1 = await db.insertQuestion(
        Question(
          question: 'q1',
          answer: 'a',
          categoryId: catId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final q2 = await db.insertQuestion(
        Question(
          question: 'q2',
          answer: 'a',
          categoryId: catId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await db.deleteCategory(catId);
      final all = await db.getAllTombstones();
      expect(all['categories'], contains(catId));
      expect(all['questions'], containsAll([q1, q2]));
    });

    test(
      'deleteCategory does not tombstone questions of other categories',
      () async {
        final catA = await db.insertCategory(
          Category(
            name: 'A',
            icon: '📌',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        final catB = await db.insertCategory(
          Category(
            name: 'B',
            icon: '📌',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        final qA = await db.insertQuestion(
          Question(
            question: 'a',
            answer: 'a',
            categoryId: catA,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        final qB = await db.insertQuestion(
          Question(
            question: 'b',
            answer: 'a',
            categoryId: catB,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        await db.deleteCategory(catA);
        final all = await db.getAllTombstones();
        expect(all['questions'], {qA});
        expect(all['questions'], isNot(contains(qB)));
      },
    );
  });
}
