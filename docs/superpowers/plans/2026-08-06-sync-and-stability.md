# Sync & Stability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix cloud-sync correctness (500-op batch cap, resurrected deletes, unbounded restore), make deletes propagate across devices via a local tombstone journal, bound cloud score history, consolidate the duplicated `isVerified` check, and land two cheap perf wins.

**Architecture:** A new SQLite table `sync_deletions` journals locally-deleted category/question ids. Backup pushes tombstones then upserts live data in ≤450-op batches; restore reads paginated, skips tombstoned ids, and inserts in batches. Score records sync only within a 30-day window. A single `AuthService.isVerifiedUser` helper replaces five duplicated copies. `getRandomQuestion` uses a random OFFSET; root detection moves off the first frame.

**Tech Stack:** Flutter/Dart, sqflite, cloud_firestore, shared_preferences. Tests use the existing fake Firebase platform pattern from `test/core/streak/streak_service_test.dart`.

## Global Constraints

- Branch: work on **`develop`**.
- CI is strict: `flutter analyze` must be **0 issues** (infos/warnings fatal), `dart format --set-exit-if-changed lib/ test/` clean, `flutter test` **77/77** existing + new, `flutter build apk --debug` when native/deps changed.
- Score sync window: **30 days**, hardcoded `_scoreSyncWindowDays = 30` (not a Remote Config key).
- Batch chunk size: **450 ops** (headroom under Firestore's 500-op cap).
- Tombstone collections: **only `categories` and `questions`** — scores are never deleted in the UI, so no score tombstones.
- `sync_deletions` is **never wiped** by `clearAllData()` or the restore's initial-login wipe.
- `isVerified` = `user != null && (user.emailVerified || user.phoneNumber != null)`. The `_HomeGate` login-gate at `main.dart:292-302` stays unchanged (intentionally more permissive).
- No RevenueCat / AdMob / Google Developer accounts involved — pure code.
- **Test infra — sqflite:** `flutter test` has no sqflite platform, so DB tests (Tasks 1, 2, 6) MUST use `sqflite_common_ffi`. Add dev dep `sqflite_common_ffi: ^2.3.0`; every DB test file calls `sqfliteFfiInit(); databaseFactory = databaseFactoryFfi;` in `main()`.
- **Test infra — Firestore:** `flutter test` has no cloud_firestore platform — `batch.commit()` / `.get()` throw `MissingPluginException` (swallowed by sync's catch). Sync tests (Tasks 3, 4) MUST test pure extracted logic only (chunking, tombstone plan, score-window filter, `dataFound` predicate, tombstone-drop). The thin Firestore shell is verified by `flutter analyze` + integration, not unit tests.

---

## File Structure

- `lib/core/database/database_helper.dart` — schema v5 (`sync_deletions`), tombstone write/read/clear helpers, random-offset `getRandomQuestion`
- `lib/core/sync/sync_service.dart` — chunked/tombstone-aware backup, paginated/batched/tombstone-aware restore, `dataFound` fix, windowed score sync + prune
- `lib/core/auth/auth_service.dart` — `isVerifiedUser` helper; use in `initializeUserSession`
- `lib/main.dart` — use `isVerifiedUser` (2 sites); move root detection off the first frame
- `test/core/database/database_helper_test.dart` — new: tombstone + random-question tests (uses `sqflite_common_ffi`)
- `test/core/sync/sync_service_test.dart` — new: pure-helper tests (chunk ranges, tombstone plan, score window, dataFound predicate, tombstone drop)
- `test/core/auth/is_verified_user_test.dart` — new: helper unit tests

---

### Task 1: Schema v5 — `sync_deletions` table + DatabaseHelper tombstone helpers

**Files:**
- Modify: `lib/core/database/database_helper.dart`
- Test: `test/core/database/database_helper_test.dart`

**Interfaces:**
- Produces:
  - `Future<void> addTombstone(String collection, int docId)` — insert-or-ignore a journal row
  - `Future<void> addTombstones(String collection, Iterable<int> docIds)` — batch insert
  - `Future<Map<String, Set<int>>> getAllTombstones()` — all rows keyed by collection
  - `Future<void> removeTombstones(String collection, Iterable<int> docIds)` — delete rows (called after cloud commit)
  - `Future<Set<int>> getTombstonedIds(String collection)` — for restore skip

- [ ] **Step 1: Add the sqflite FFI dev dependency**

```bash
flutter pub add dev:sqflite_common_ffi:^2.3.0
```

Run: `flutter pub get` — resolves cleanly (sqflite_common 2.5.8 is already transitive).

- [ ] **Step 2: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:random_recall/core/database/database_helper.dart';
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
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/core/database/database_helper_test.dart`
Expected: FAIL — `sync_deletions` table missing / methods undefined. (If it instead fails with a sqflite error, the FFI factory setup in Step 1 is wrong — fix the setup before proceeding.)

- [ ] **Step 4: Implement schema v5 + helpers**

In `database_helper.dart`:
- Bump `_dbVersion` from `4` to `5`.
- Add `static const String _tableSyncDeletions = 'sync_deletions';`.
- In `_onCreate`, after the three tables, add:
  ```sql
  CREATE TABLE sync_deletions (
    collection TEXT NOT NULL,
    doc_id     INTEGER NOT NULL,
    deleted_at TEXT NOT NULL,
    PRIMARY KEY (collection, doc_id)
  )
  ```
- In `_onUpgrade`, add a `if (oldVersion < 5)` branch that creates the same table.
- Add the five helper methods using `(await database)` + raw SQL with `INSERT OR IGNORE`.
- Add a `@visibleForTesting String get dbPathForTesting` returning the current path, and a `@visibleForTesting void overrideDbPathForTesting(String path)` that closes `_db` and swaps the path used by `_initDatabase()`. (Store it in a field `_dbPathOverride`; `_initDatabase` uses `join(getDatabasesPath(), _dbPathOverride ?? _dbName)`.)

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/core/database/database_helper_test.dart`
Expected: PASS.

- [ ] **Step 6: Run full validation**

Run: `flutter analyze && dart format --set-exit-if-changed lib/ test/ && flutter test`
Expected: 0 analyzer issues; format clean; 77/77 + new tests pass.

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/database/database_helper.dart test/core/database/database_helper_test.dart
git commit -m "feat(db): schema v5 sync_deletions tombstone journal
```

---

### Task 2: Tombstone-aware deletes in DatabaseHelper

**Files:**
- Modify: `lib/core/database/database_helper.dart`
- Test: `test/core/database/database_helper_test.dart`

**Interfaces:**
- Consumes: `addTombstone`, `addTombstones`, `removeTombstones`, `getAllTombstones` from Task 1.
- Produces:
  - `Future<int> deleteCategory(int id)` — now also tombstones the category **and** its questions
  - `Future<int> deleteQuestion(int id)` — now also tombstones the question
  - `Future<List<int>> getQuestionIdsByCategory(int id)` — helper for cascade tombstone

- [ ] **Step 1: Write the failing tests**

```dart
// Append to the tombstone group in database_helper_test.dart

test('deleteQuestion writes a tombstone', () async {
  final catId = await db.insertCategory(Category(
    name: 'T', icon: '📌', createdAt: DateTime.now(), updatedAt: DateTime.now(),
  ));
  final qId = await db.insertQuestion(Question(
    question: 'q', answer: 'a', categoryId: catId,
    createdAt: DateTime.now(), updatedAt: DateTime.now(),
  ));
  await db.deleteQuestion(qId);
  final all = await db.getAllTombstones();
  expect(all['questions'], contains(qId));
});

test('deleteCategory tombstones the category and its questions', () async {
  final catId = await db.insertCategory(Category(
    name: 'T', icon: '📌', createdAt: DateTime.now(), updatedAt: DateTime.now(),
  ));
  final q1 = await db.insertQuestion(Question(
    question: 'q1', answer: 'a', categoryId: catId,
    createdAt: DateTime.now(), updatedAt: DateTime.now(),
  ));
  final q2 = await db.insertQuestion(Question(
    question: 'q2', answer: 'a', categoryId: catId,
    createdAt: DateTime.now(), updatedAt: DateTime.now(),
  ));
  await db.deleteCategory(catId);
  final all = await db.getAllTombstones();
  expect(all['categories'], contains(catId));
  expect(all['questions'], containsAll([q1, q2]));
});

test('deleteCategory does not tombstone questions of other categories', () async {
  final catA = await db.insertCategory(Category(
    name: 'A', icon: '📌', createdAt: DateTime.now(), updatedAt: DateTime.now(),
  ));
  final catB = await db.insertCategory(Category(
    name: 'B', icon: '📌', createdAt: DateTime.now(), updatedAt: DateTime.now(),
  ));
  final qA = await db.insertQuestion(Question(
    question: 'a', answer: 'a', categoryId: catA,
    createdAt: DateTime.now(), updatedAt: DateTime.now(),
  ));
  final qB = await db.insertQuestion(Question(
    question: 'b', answer: 'a', categoryId: catB,
    createdAt: DateTime.now(), updatedAt: DateTime.now(),
  ));
  await db.deleteCategory(catA);
  final all = await db.getAllTombstones();
  expect(all['questions'], {qA});
  expect(all['questions'], isNot(contains(qB)));
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/database/database_helper_test.dart`
Expected: FAIL — `deleteQuestion`/`deleteCategory` don't write tombstones yet.

- [ ] **Step 3: Implement**

In `database_helper.dart`:

```dart
Future<List<int>> getQuestionIdsByCategory(int id) async {
  final rows = await (await database).query(
    _tableQuestions,
    where: 'category_id = ?',
    whereArgs: [id],
    columns: ['id'],
  );
  return rows.map((r) => r['id'] as int).toList();
}

Future<int> deleteCategory(int id) async {
  final db = await database;
  final questionIds = await getQuestionIdsByCategory(id);
  await db.transaction((txn) async {
    await txn.insert(
      _tableSyncDeletions,
      {'collection': 'categories', 'doc_id': id, 'deleted_at': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    for (final qId in questionIds) {
      await txn.insert(
        _tableSyncDeletions,
        {'collection': 'questions', 'doc_id': qId, 'deleted_at': DateTime.now().toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await txn.delete(_tableCategories, where: 'id = ?', whereArgs: [id]);
  });
  _updateController.add(null);
  return 1;
}

Future<int> deleteQuestion(int id) async {
  final db = await database;
  await db.transaction((txn) async {
    await txn.insert(
      _tableSyncDeletions,
      {'collection': 'questions', 'doc_id': id, 'deleted_at': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await txn.delete(_tableQuestions, where: 'id = ?', whereArgs: [id]);
  });
  _updateController.add(null);
  return 1;
}
```

The `_updateController.add(null)` triggers the 5s-debounced auto-backup, which is what actually pushes the tombstone to Firestore.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/database/database_helper_test.dart`
Expected: PASS.

- [ ] **Step 5: Run full validation**

Run: `flutter analyze && dart format --set-exit-if-changed lib/ test/ && flutter test`
Expected: 0 issues; format clean; all tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/core/database/database_helper.dart test/core/database/database_helper_test.dart
git commit -m "feat(db): tombstone categories and questions on delete"
```

---

### Task 3: Chunked, tombstone-aware backup

**Files:**
- Modify: `lib/core/sync/sync_service.dart`
- Test: `test/core/sync/sync_service_test.dart`

**Interfaces:**
- Consumes: `DatabaseHelper.getAllTombstones()`, `removeTombstones()`, and existing `getAllCategories/getAllQuestions/getAllScoreRecords`.
- Produces (pure statics — unit-testable without Firestore):
  - `static List<(int, int)> chunkRanges(int total, {int chunkSize})` — (start, end) index ranges
  - `static List<(String, int)> tombstonePlan(Map<String, Set<int>> tombstones)` — deterministic ordered cloud-delete list
  - `static List<ScoreRecord> scoresForSync(List<ScoreRecord> all, DateTime cutoff)` — window filter
  - `Future<void> _runBatched(List<void Function(WriteBatch)> ops, {int chunkSize = 450})` — commits each chunk
- Backup now: push tombstones first, then upsert live data (categories + questions + scores `answered_at >= now − 30d`) in chunks, then prune cloud scores older than 30d.

- [ ] **Step 1: Write the failing test for `chunkRanges`**

```dart
// test/core/sync/sync_service_test.dart
// NOTE: these tests only touch static pure helpers — they do NOT construct
// SyncService.instance (its field initializer touches FirebaseFirestore, which
// throws in `flutter test`). Static access is safe.
import 'package:flutter_test/flutter_test.dart';
import 'package:random_recall/core/sync/sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncService.chunkRanges', () {
    test('splits into ≤ chunkSize ranges', () {
      expect(
        SyncService.chunkRanges(1200, chunkSize: 450),
        [(0, 450), (450, 900), (900, 1200)],
      );
    });

    test('single range when total < chunkSize', () {
      expect(SyncService.chunkRanges(100, chunkSize: 450), [(0, 100)]);
    });

    test('empty total yields no ranges', () {
      expect(SyncService.chunkRanges(0), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/sync/sync_service_test.dart`
Expected: FAIL — `chunkRanges` not defined.

- [ ] **Step 3: Implement `chunkRanges` + `_runBatched`**

```dart
static const int _scoreSyncWindowDays = 30;
static const int _batchChunkSize = 450;

/// Splits [total] items into (start, end) index ranges, each at most
/// [chunkSize] wide. Used to keep every Firestore batch under the 500-op cap.
static List<(int, int)> chunkRanges(int total, {int chunkSize = _batchChunkSize}) {
  if (total <= 0) return const [];
  final ranges = <(int, int)>[];
  for (var start = 0; start < total; start += chunkSize) {
    final end = (start + chunkSize) < total ? start + chunkSize : total;
    ranges.add((start, end));
  }
  return ranges;
}

/// Runs [ops] against Firestore write batches, committing every [chunkSize]
/// operations. Keeps each commit under Firestore's 500-op batch cap.
Future<void> _runBatched(
  List<void Function(WriteBatch)> ops, {
  int chunkSize = _batchChunkSize,
}) async {
  for (final (start, end) in chunkRanges(ops.length, chunkSize: chunkSize)) {
    final batch = _db.batch();
    for (var i = start; i < end; i++) {
      ops[i](batch);
    }
    await batch.commit();
  }
}
```

- [ ] **Step 4: Write the failing tests for `tombstonePlan` + `scoresForSync`**

```dart
// Append to sync_service_test.dart — add `import 'package:random_recall/models/score_record.dart';`
// at the top.

group('SyncService.tombstonePlan', () {
  test('flattens deterministically by collection then id', () {
    final plan = SyncService.tombstonePlan({
      'questions': {5, 1},
      'categories': {2},
    });
    expect(plan, [('categories', 2), ('questions', 1), ('questions', 5)]);
  });

  test('empty journal yields empty plan', () {
    expect(SyncService.tombstonePlan({}), isEmpty);
  });
});

group('SyncService.scoresForSync', () {
  test('keeps records at or after cutoff', () {
    final now = DateTime(2026, 8, 6);
    final cutoff = now.subtract(const Duration(days: 30));
    final tooOld = ScoreRecord(
      questionId: 1, categoryId: 1, isCorrect: true,
      answeredAt: cutoff.subtract(const Duration(days: 1)), updatedAt: now,
    );
    final boundary = ScoreRecord(
      questionId: 2, categoryId: 1, isCorrect: true,
      answeredAt: cutoff, updatedAt: now,
    );
    final recent = ScoreRecord(
      questionId: 3, categoryId: 1, isCorrect: true,
      answeredAt: now, updatedAt: now,
    );
    final result = SyncService.scoresForSync([tooOld, boundary, recent], cutoff);
    expect(result, [boundary, recent]);
  });
});
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/core/sync/sync_service_test.dart`
Expected: PASS.

- [ ] **Step 6: Implement the pure helpers used by backup**

```dart
/// Flattens the tombstone journal into an ordered list of (collection, docId)
/// cloud deletes. Ordered by collection name then docId for determinism.
static List<(String, int)> tombstonePlan(Map<String, Set<int>> tombstones) {
  final plan = <(String, int)>[];
  final keys = tombstones.keys.toList()..sort();
  for (final collection in keys) {
    final ids = tombstones[collection]!.toList()..sort();
    for (final id in ids) {
      plan.add((collection, id));
    }
  }
  return plan;
}

/// Returns score records within the sync window (not older than [cutoff]).
static List<ScoreRecord> scoresForSync(List<ScoreRecord> all, DateTime cutoff) =>
    all.where((s) => !s.answeredAt.isBefore(cutoff)).toList();
```

- [ ] **Step 7: Rewrite backup using the pure helpers**

```dart
Future<void> performBackup({bool force = false}) async {
  final user = AuthService.instance.currentUser;
  if (!AuthService.isVerifiedUser(user) || (_isSyncing && !force)) return;
  _isSyncing = true;
  debugPrint('SyncService: Starting backup for user ${user.uid}...');

  final trace = FirebasePerformance.instance.newTrace('sync_backup');
  await trace.start();
  try {
    final userDoc = _db.collection('users').doc(user.uid);
    final dbHelper = DatabaseHelper.instance;

    // 1. Push tombstones first — deletes propagate, journal cleared on success.
    final tombstones = await dbHelper.getAllTombstones();
    final deleteOps = <void Function(WriteBatch)>[];
    for (final (collection, docId) in tombstonePlan(tombstones)) {
      deleteOps.add((b) =>
          b.delete(userDoc.collection(collection).doc(docId.toString())));
    }
    await _runBatched(deleteOps);
    for (final entry in tombstones.entries) {
      await dbHelper.removeTombstones(entry.key, entry.value);
    }

    // 2. Upsert live data in chunks.
    final ops = <void Function(WriteBatch)>[];
    final categories = await dbHelper.getAllCategories();
    for (final cat in categories) {
      if (cat.id == null) continue;
      final ref = userDoc.collection('categories').doc(cat.id.toString());
      ops.add((b) => b.set(ref, cat.toMap(), SetOptions(merge: true)));
    }
    final questions = await dbHelper.getAllQuestions();
    for (final q in questions) {
      if (q.id == null) continue;
      final ref = userDoc.collection('questions').doc(q.id.toString());
      ops.add((b) => b.set(ref, q.toMap(), SetOptions(merge: true)));
    }
    // Scores: only within the sync window.
    final cutoff = DateTime.now().subtract(
      const Duration(days: _scoreSyncWindowDays),
    );
    final scores = await dbHelper.getAllScoreRecords();
    final recentScores = scoresForSync(scores, cutoff);
    for (final s in recentScores) {
      if (s.id == null) continue;
      final ref = userDoc.collection('score_records').doc(s.id.toString());
      ops.add((b) => b.set(ref, s.toMap(), SetOptions(merge: true)));
    }

    // 3. Prune cloud scores older than the window.
    final oldQuery = await userDoc
        .collection('score_records')
        .where('answered_at', isLessThan: cutoff.toIso8601String())
        .get();
    final pruneOps = <void Function(WriteBatch)>[];
    for (final doc in oldQuery.docs) {
      pruneOps.add((b) => b.delete(userDoc.collection('score_records').doc(doc.id)));
    }
    await _runBatched(pruneOps);

    await _runBatched(ops);

    // 4. User-doc metadata as before.
    final prefs = await SharedPreferences.getInstance();
    final settings = { ...existing settings map... };
    final deviceId = prefs.getString('device_id') ?? 'unknown';
    final batch = _db.batch();
    batch.set(userDoc, {
      'last_active_device_id': deviceId,
      'last_sync_at': FieldValue.serverTimestamp(),
      'settings': settings,
      'onboarding_complete': prefs.getBool('onboarding_complete') ?? false,
    }, SetOptions(merge: true));
    await batch.commit();

    trace.putAttribute('question_count', questions.length.toString());
    debugPrint('SyncService: Backup success. ${categories.length} categories, ${questions.length} questions, ${recentScores.length} recent scores synced.');
  } catch (e, st) {
    debugPrint('SyncService: Backup failed: $e');
    FirebaseCrashlytics.instance.recordError(e, st, reason: 'sync_backup_failed');
  } finally {
    await trace.stop();
    _isSyncing = false;
  }
}
```

> The `settings` map is copied verbatim from the current implementation (`sync_service.dart:89-97`). Keep it identical.
>
> **Note on testing:** the Firestore-touching shell (the `_runBatched` commits, the prune query, journal-clearing after commit) is NOT unit-tested — `batch.commit()` throws `MissingPluginException` in `flutter test`. It is verified by `flutter analyze` + integration on device. The unit-testable decisions (chunk boundaries, tombstone ordering, score window) are the pure helpers above.

- [ ] **Step 8: Run tests**

Run: `flutter test test/core/sync/sync_service_test.dart test/core/database/database_helper_test.dart`
Expected: PASS. (The existing 77 must still pass — run `flutter test` too.)

- [ ] **Step 9: Run full validation**

Run: `flutter analyze && dart format --set-exit-if-changed lib/ test/ && flutter test`
Expected: 0 issues; format clean; all pass.

- [ ] **Step 10: Commit**

```bash
git add lib/core/sync/sync_service.dart test/core/sync/sync_service_test.dart
git commit -m "feat(sync): chunked tombstone-aware backup with windowed scores"
```

---

### Task 4: Paginated, batched, tombstone-aware restore + dataFound fix

**Files:**
- Modify: `lib/core/sync/sync_service.dart`, `lib/main.dart`
- Test: `test/core/sync/sync_service_test.dart`

**Interfaces:**
- Consumes: `DatabaseHelper.getTombstonedIds()`, `DatabaseHelper.clearAllData()`.
- Produces (pure statics — unit-testable without Firestore):
  - `static bool hasCloudData({required bool hasQuestions, required bool hasScores})` — `hasQuestions || hasScores` (categories excluded — default General/Work are always backed up)
  - `static List<String> dropTombstoned(Iterable<String> cloudDocIds, Set<int> tombstonedIds)` — filters cloud doc ids against the journal
  - `Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchAllDocs(CollectionReference<Map<String, dynamic>> collection, {int pageSize = 500})` — paginated read (Firestore shell, not unit-tested)

- [ ] **Step 1: Write the failing tests for the pure helpers**

```dart
// Append to sync_service_test.dart (static access only — do not construct
// SyncService.instance in this file).

group('SyncService.hasCloudData', () {
  test('true if questions or scores exist', () {
    expect(SyncService.hasCloudData(hasQuestions: true, hasScores: false), true);
    expect(SyncService.hasCloudData(hasQuestions: false, hasScores: true), true);
    expect(SyncService.hasCloudData(hasQuestions: true, hasScores: true), true);
    expect(SyncService.hasCloudData(hasQuestions: false, hasScores: false), false);
  });
});

group('SyncService.dropTombstoned', () {
  test('drops cloud doc ids present in the tombstone set', () {
    expect(SyncService.dropTombstoned(['1', '2', '3'], {2}), ['1', '3']);
  });

  test('keeps all when tombstone set is empty', () {
    expect(SyncService.dropTombstoned(['1', '2'], {}), ['1', '2']);
  });

  test('ignores non-numeric cloud ids safely', () {
    expect(SyncService.dropTombstoned(['abc', '4'], {4}), ['abc']);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/sync/sync_service_test.dart`
Expected: FAIL — `hasCloudData` / `dropTombstoned` not defined.

- [ ] **Step 3: Implement the pure helpers + paginated restore**

```dart
/// True when the cloud has real user data worth restoring. Categories are
/// excluded because the default General/Work categories are always backed up
/// and would be a false signal.
static bool hasCloudData({required bool hasQuestions, required bool hasScores}) =>
    hasQuestions || hasScores;

/// Drops cloud document ids that are in the local tombstone journal, so an
/// offline delete does not resurrect on restore.
static List<String> dropTombstoned(
  Iterable<String> cloudDocIds,
  Set<int> tombstonedIds,
) =>
    cloudDocIds
        .where((id) => !tombstonedIds.contains(int.tryParse(id)))
        .toList();

Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchAllDocs(
  CollectionReference<Map<String, dynamic>> collection, {
  int pageSize = 500,
}) async {
  final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  QueryDocumentSnapshot<Map<String, dynamic>>? last;
  while (true) {
    var q = collection.orderBy(FieldPath.documentId).limit(pageSize);
    if (last != null) {
      q = q.startAfterDocument(last);
    }
    final snap = await q.get();
    if (snap.docs.isEmpty) break;
    docs.addAll(snap.docs);
    last = snap.docs.last;
    if (snap.docs.length < pageSize) break;
  }
  return docs;
}
```

In `performRestore`, replace the three unbounded `.get()` calls with `_fetchAllDocs` on categories/questions/scores. After fetching, read `getTombstonedIds('questions')` and `getTombstonedIds('categories')`, filter the fetched docs, and use `hasCloudData` for the decision:

```dart
final qTombstones = await dbHelper.getTombstonedIds('questions');
final cTombstones = await dbHelper.getTombstonedIds('categories');
final keptQIds = dropTombstoned(qSnap.docs.map((d) => d.id), qTombstones).toSet();
final keptCIds = dropTombstoned(catSnap.docs.map((d) => d.id), cTombstones).toSet();
final categories = catSnap.docs.where((d) => keptCIds.contains(d.id)).toList();
final questions = qSnap.docs.where((d) => keptQIds.contains(d.id)).toList();
```

Insert via batched `txn.batch` in chunks, ordered categories → questions → scores (FK-safe). Then update `dataFound`:

```dart
final dataFound = hasCloudData(
  hasQuestions: qSnap.docs.isNotEmpty,
  hasScores: sSnap.docs.isNotEmpty,
);
```

- [ ] **Step 4: Update `_HomeGate`'s direct cloud-data check**

In `lib/main.dart:433`, the `_HomeGate` check uses `userDoc.collection('questions').limit(1).get()` to decide `hasCloudData`. Extend it to also check `score_records` so a categories/scores-only user isn't pushed to onboarding:

```dart
final qSnap = await userDoc.collection('questions').limit(1).get();
final sSnap = await userDoc.collection('score_records').limit(1).get();
final hasCloudData = qSnap.docs.isNotEmpty || sSnap.docs.isNotEmpty;
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/core/sync/sync_service_test.dart`
Expected: PASS.

- [ ] **Step 6: Run full validation**

Run: `flutter analyze && dart format --set-exit-if-changed lib/ test/ && flutter test`
Expected: 0 issues; format clean; all pass.

- [ ] **Step 7: Commit**

```bash
git add lib/core/sync/sync_service.dart lib/main.dart test/core/sync/sync_service_test.dart
git commit -m "feat(sync): paginated tombstone-aware restore + dataFound fix"
```

---

### Task 5: `isVerifiedUser` helper consolidation

**Files:**
- Modify: `lib/core/auth/auth_service.dart`, `lib/core/sync/sync_service.dart`, `lib/main.dart`
- Test: `test/core/auth/is_verified_user_test.dart`

**Interfaces:**
- Produces: `static bool isVerifiedUser(User? user)` on `AuthService`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/auth/is_verified_user_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:random_recall/core/auth/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('isVerifiedUser: null user is false', () {
    expect(AuthService.isVerifiedUser(null), false);
  });

  test('isVerifiedUser: emailVerified true is true', () {
    // Build a fake User — use a minimal stub via the platform interface,
    // or a mock. The User class is final; construct via the platform fake.
  });

  test('isVerifiedUser: phoneNumber present is true', () {
    // same stub approach
  });

  test('isVerifiedUser: unverified email, no phone is false', () {
    // same stub approach
  });
}
```

> `User` is final in `firebase_auth` and hard to construct directly. Prefer extracting the *pure* predicate so it's testable without a `User`:

```dart
static bool isVerified({
  required bool hasEmailVerified,
  required bool hasPhone,
}) => hasEmailVerified || hasPhone;

static bool isVerifiedUser(User? user) =>
    user != null && isVerified(hasEmailVerified: user.emailVerified, hasPhone: user.phoneNumber != null);
```

Test the pure `isVerified` against the four truth-table rows — that covers the logic without mocking `User`. Add the two-liner `isVerifiedUser` for call sites that have a `User`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/auth/is_verified_user_test.dart`
Expected: FAIL — `isVerified`/`isVerifiedUser` not defined.

- [ ] **Step 3: Implement**

Add to `AuthService`:

```dart
/// A user is "verified" if they proved ownership of an email or phone.
/// Phone users are verified by OTP; email users by verification email.
static bool isVerified({
  required bool hasEmailVerified,
  required bool hasPhone,
}) => hasEmailVerified || hasPhone;

static bool isVerifiedUser(User? user) => user != null &&
    isVerified(hasEmailVerified: user.emailVerified, hasPhone: user.phoneNumber != null);
```

Replace the five duplicated expressions:
- `auth_service.dart:271` → `if (!isVerifiedUser(user)) return;`
- `main.dart:182` → `final isVerified = AuthService.isVerifiedUser(user);`
- `main.dart:425` → `final isVerified = AuthService.isVerifiedUser(user);`
- `sync_service.dart:50` (backup) → `if (!AuthService.isVerifiedUser(user) || (_isSyncing && !force)) return;`
- `sync_service.dart:138` (restore) → `if (!AuthService.isVerifiedUser(user)) return;`

Leave `main.dart:292-302` (the `_HomeGate` login gate) unchanged.

- [ ] **Step 4: Run tests**

Run: `flutter test test/core/auth/is_verified_user_test.dart && flutter test`
Expected: PASS.

- [ ] **Step 5: Run full validation**

Run: `flutter analyze && dart format --set-exit-if-changed lib/ test/ && flutter test`
Expected: 0 issues; format clean; all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/core/auth/auth_service.dart lib/core/sync/sync_service.dart lib/main.dart test/core/auth/is_verified_user_test.dart
git commit -m "refactor(auth): consolidate isVerified checks"
```

---

### Task 6: Random-offset `getRandomQuestion`

**Files:**
- Modify: `lib/core/database/database_helper.dart`
- Test: `test/core/database/database_helper_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `getRandomQuestion` now uses `LIMIT 1 OFFSET ?` with a fallback.

- [ ] **Step 1: Write the failing tests**

```dart
// Append to database_helper_test.dart

test('getRandomQuestion returns a seeded question', () async {
  final catId = await db.insertCategory(Category(
    name: 'R', icon: '📌', createdAt: DateTime.now(), updatedAt: DateTime.now(),
  ));
  for (var i = 0; i < 5; i++) {
    await db.insertQuestion(Question(
      question: 'q$i', answer: 'a', categoryId: catId,
      createdAt: DateTime.now(), updatedAt: DateTime.now(),
    ));
  }
  final q = await db.getRandomQuestion(categoryId: catId);
  expect(q, isNotNull);
  expect(q!.categoryId, catId);
});

test('getRandomQuestion respects excludeIds', () async {
  final catId = await db.insertCategory(Category(
    name: 'R', icon: '📌', createdAt: DateTime.now(), updatedAt: DateTime.now(),
  ));
  final ids = <int>[];
  for (var i = 0; i < 5; i++) {
    final id = await db.insertQuestion(Question(
      question: 'q$i', answer: 'a', categoryId: catId,
      createdAt: DateTime.now(), updatedAt: DateTime.now(),
    ));
    ids.add(id);
  }
  final q = await db.getRandomQuestion(categoryId: catId, excludeIds: ids.toSet());
  // Excluded all — should fall back to any question
  expect(q, isNotNull);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/database/database_helper_test.dart`
Expected: PASS initially (existing behavior) — so instead, add a test that *asserts the new behavior* (returns a valid row within the set) and verify it still passes after the change. The point is regression coverage, not a red-green cycle.

- [ ] **Step 3: Implement random-offset query**

```dart
Future<Question?> getRandomQuestion({
  int? categoryId,
  int? excludeId,
  Set<int>? excludeIds,
}) async {
  final db = await database;
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

  final where = conditions.isEmpty ? null : conditions.join(' AND');
  final countRows = await db.rawQuery(
    'SELECT COUNT(*) AS c FROM $_tableQuestions'
    '${where == null ? '' : ' WHERE $where'}',
    args.isEmpty ? null : args,
  );
  final count = countRows.first['c'] as int;
  if (count == 0) {
    // No rows after exclusions — fall back to any question.
    return getRandomQuestion(categoryId: categoryId);
  }
  final offset = Random().nextInt(count);
  final rows = await db.query(
    _tableQuestions,
    where: where,
    whereArgs: args.isEmpty ? null : args,
    orderBy: 'id',
    limit: 1,
    offset: offset,
  );
  if (rows.isEmpty) {
    // Fallback: offset past end (shouldn't happen, but be safe).
    return getRandomQuestion(categoryId: categoryId);
  }
  return Question.fromMap(rows.first);
}
```

> `Random()` from `dart:math` — add the import if not present.

- [ ] **Step 4: Run tests**

Run: `flutter test test/core/database/database_helper_test.dart`
Expected: PASS.

- [ ] **Step 5: Run full validation**

Run: `flutter analyze && dart format --set-exit-if-changed lib/ test/ && flutter test`
Expected: 0 issues; format clean; all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/core/database/database_helper.dart test/core/database/database_helper_test.dart
git commit -m "perf(db): random-offset question query"
```

---

### Task 7: Root detection off the first frame

**Files:**
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `RootDetectionService.instance.detect()`, `.trackStatus()`.
- Produces: root detection runs post-frame, not before `runApp`.

- [ ] **Step 1: Move the calls into the post-frame block**

Current (`main.dart:80-84`):

```dart
await RootDetectionService.instance.detect();
RootDetectionService.instance.trackStatus().ignore();
```

Remove those two lines from the pre-`runApp` section. Inside the existing `addPostFrameCallback` block, add near the top:

```dart
// Root/jailbreak detection — informational only. Runs post-frame so it
// never delays the first frame. The one-time warning dialog renders in
// HomeScreen after auth.
await RootDetectionService.instance.detect();
RootDetectionService.instance.trackStatus().ignore();
```

- [ ] **Step 2: Verify**

Run: `flutter analyze && dart format --set-exit-if-changed lib/ && flutter test`
Expected: 0 issues; format clean; 77/77 pass. (No behavioral change to tests; the move is pure timing.)

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "perf(startup): run root detection post-frame, off the first frame"
```

---

### Task 8: Final validation + doc sync

**Files:**
- Modify: `CHANGELOG.md`, `docs/SESSION_NOTES.md`

- [ ] **Step 1: Full validation suite**

Run: `flutter analyze && dart format --set-exit-if-changed lib/ test/ && flutter test && flutter build apk --debug`
Expected: 0 analyzer issues; format clean; all tests pass (77 + new); debug APK builds.

- [ ] **Step 2: Update CHANGELOG.md**

Add an entry under the current version block (matching existing style) describing:
- Sync: chunked backup (fixes 500-op cap), tombstone deletes propagate, paginated restore, 30-day cloud score window + prune, `dataFound` fix.
- `isVerifiedUser` consolidation.
- Random-offset question query; root detection off the first frame.

- [ ] **Step 3: Update docs/SESSION_NOTES.md**

- Add to the release table (or a "current work" note) the sync/stability batch.
- Add a note under §9 Files map for the new `sync_deletions` table and the `_fetchAllDocs` pagination helper.

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md docs/SESSION_NOTES.md
git commit -m "docs: changelog + session notes for sync & stability batch"
```

---

## Self-Review Notes

**Spec coverage:**
- Tombstone journal (schema v5) → Task 1
- Tombstone-aware deletes (category + cascade) → Task 2
- Chunked backup + tombstone push + windowed scores + prune → Task 3
- Paginated restore + tombstone skip + `dataFound` fix → Task 4 (+ `_HomeGate` in Task 4 Step 3)
- `isVerifiedUser` consolidation → Task 5
- Random-offset question query → Task 6
- Root detection off the first frame → Task 7
- Doc sync (CHANGELOG + SESSION_NOTES) → Task 8

**Placeholder scan:** No TBD/TODO. Task 4's original placeholder test was replaced with real tests for the extracted pure helpers (`hasCloudData`, `dropTombstoned`). The Firestore shells (`_runBatched` commit path, `_fetchAllDocs`, prune query, journal-clear-after-commit) are documented as integration-verified, not unit-tested — a deliberate, stated exception consistent with the existing streak tests (which also leave Firestore calls untested).

**Type consistency:** The pure helpers are defined once and used consistently: `chunkRanges(int, {int chunkSize})`, `tombstonePlan(Map<String, Set<int>>)`, `scoresForSync(List<ScoreRecord>, DateTime)`, `hasCloudData({hasQuestions, hasScores})`, `dropTombstoned(Iterable<String>, Set<int>)`, `_runBatched(List<void Function(WriteBatch)>, {int chunkSize})`, `_fetchAllDocs(CollectionReference, {int pageSize})`, `isVerifiedUser(User?)`, `addTombstone(s)`, `removeTombstones`, `getAllTombstones`, `getTombstonedIds`. Task 3 tests use `SyncService.chunkRanges(1200, chunkSize: 450)` → `[(0, 450), (450, 900), (900, 1200)]`, which matches the 450-op batch constraint.

**Pre-flight revisions (recorded):** Two test-infra issues found before dispatch and fixed in this plan:
1. `sqflite` has no platform in `flutter test` → added `sqflite_common_ffi: ^2.3.0` dev dep; DB test files call `sqfliteFfiInit()` + `databaseFactory = databaseFactoryFfi`.
2. `cloud_firestore` has no platform in `flutter test` → sync tests target pure extracted logic only; the thin Firestore shells are integration-verified.
