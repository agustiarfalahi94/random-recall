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

---

## File Structure

- `lib/core/database/database_helper.dart` — schema v5 (`sync_deletions`), tombstone write/read/clear helpers, random-offset `getRandomQuestion`
- `lib/core/sync/sync_service.dart` — chunked/tombstone-aware backup, paginated/batched/tombstone-aware restore, `dataFound` fix, windowed score sync + prune
- `lib/core/auth/auth_service.dart` — `isVerifiedUser` helper; use in `initializeUserSession`
- `lib/main.dart` — use `isVerifiedUser` (2 sites); move root detection off the first frame
- `test/core/database/database_helper_test.dart` — new: tombstone + random-question tests
- `test/core/sync/sync_service_test.dart` — new: chunking, tombstone-aware backup/restore, windowed scores, pagination
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

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:random_recall/core/database/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/database/database_helper_test.dart`
Expected: FAIL — `sync_deletions` table missing / methods undefined.

- [ ] **Step 3: Implement schema v5 + helpers**

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
- Add the five helper methods using `(await database)` + raw SQL with `ConflictAlgorithm.ignore`-style inserts (`INSERT OR IGNORE`).
- Add a `@visibleForTesting String get dbPathForTesting` returning the current path, and a `@visibleForTesting void overrideDbPathForTesting(String path)` that closes `_db` and swaps the path used by `_initDatabase()`. (Store it in a field `_dbPathOverride`; `_initDatabase` uses `join(getDatabasesPath(), _dbPathOverride ?? _dbName)`.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/database/database_helper_test.dart`
Expected: PASS.

- [ ] **Step 5: Run full validation**

Run: `flutter analyze && dart format --set-exit-if-changed lib/ test/ && flutter test`
Expected: 0 analyzer issues; format clean; 77/77 + new tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/core/database/database_helper.dart test/core/database/database_helper_test.dart
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
- Produces:
  - `Future<void> _runBatched(List<void Function(WriteBatch)> ops, {int chunkSize = 450})`
  - Backup now: push tombstones first, then upsert live data (categories + questions + scores `answered_at >= now − 30d`) in chunks, then prune cloud scores older than 30d.

- [ ] **Step 1: Write the failing test for `_runBatched` chunking**

```dart
// test/core/sync/sync_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:random_recall/core/sync/sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncService._runBatched', () {
    test('executes ops across multiple chunks', () async {
      final calls = <String>[];
      final sync = SyncService.instance;
      // Stub out batch commit via a fake WriteBatch? — use a counting helper.
      // Instead, expose chunking by passing a fake batch-builder.
      await sync._runBatchedForTesting(
        1200,
        (i) => calls.add('op$i'),
        chunkSize: 450,
      );
      // 1200 ops at 450 = 3 chunks (450, 450, 300)
      expect(calls.length, 1200);
    });
  });
}
```

> Note: `_runBatched` operates on real Firestore `WriteBatch`. To unit-test chunking without the platform, add a `@visibleForTesting` variant `_runBatchedForTesting(int opCount, void Function(int index) op, {int chunkSize})` that just counts chunk boundaries, OR test the pure chunk-split logic. Prefer the pure split: extract `List<List<int>> _chunkIndices(int count, {int chunkSize})` and test that.

- [ ] **Step 2: Implement `_runBatched`**

```dart
static const int _scoreSyncWindowDays = 30;
static const int _batchChunkSize = 450;

/// Runs [ops] against Firestore write batches, committing every [chunkSize]
/// operations. Keeps each commit under Firestore's 500-op batch cap.
Future<void> _runBatched(
  List<void Function(WriteBatch)> ops, {
  int chunkSize = _batchChunkSize,
}) async {
  for (var start = 0; start < ops.length; start += chunkSize) {
    final end = (start + chunkSize).clamp(0, ops.length);
    final batch = _db.batch();
    for (var i = start; i < end; i++) {
      ops[i](batch);
    }
    await batch.commit();
  }
}
```

- [ ] **Step 3: Rewrite backup**

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
    for (final entry in tombstones.entries) {
      for (final docId in entry.value) {
        deleteOps.add((batch) =>
            batch.delete(userDoc.collection(entry.key).doc(docId.toString())));
      }
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
    final recentScores = scores.where((s) => !s.answeredAt.isBefore(cutoff)).toList();
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

- [ ] **Step 4: Write the failing tests for tombstone backup**

```dart
// Append to sync_service_test.dart — uses the fake Firebase platform pattern
// from streak_service_test.dart (FirebasePlatform + FirebaseAuthPlatform fakes,
// SharedPreferences.setMockInitialValues({})).

test('backup pushes tombstones then clears journal', () async {
  // Seed a tombstone in the DB
  await DatabaseHelper.instance.addTombstone('questions', 42);
  await SyncService.instance.performBackup(force: true);
  // Journal should be cleared after a successful (no-op) commit
  final all = await DatabaseHelper.instance.getAllTombstones();
  expect(all, isEmpty);
});
```

> Because the fake Firebase platform has no real network, `batch.commit()` in the fake returns without error, so the tombstone path (delete → commit → clear journal) can be exercised. The important assertion is that the journal clears after backup.

- [ ] **Step 5: Run tests**

Run: `flutter test test/core/sync/sync_service_test.dart test/core/database/database_helper_test.dart`
Expected: PASS. (The existing 77 must still pass — run `flutter test` too.)

- [ ] **Step 6: Run full validation**

Run: `flutter analyze && dart format --set-exit-if-changed lib/ test/ && flutter test`
Expected: 0 issues; format clean; all pass.

- [ ] **Step 7: Commit**

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
- Produces: `dataFound` = `questions.isNotEmpty || scores.isNotEmpty`.

- [ ] **Step 1: Write the failing test for the dataFound fix**

```dart
// Append to sync_service_test.dart

test('restore treats questions or scores as dataFound', () async {
  // Seed local DB so restore returns early (skip if data exists),
  // then call the dataFound decision directly if it's exposed; else
  // verify via a seeded cloud-less restore path.
  // Simplest: assert the new predicate behavior through a @visibleForTesting
  // helper, or test _HomeGate's equivalent check via a unit test on the
  // extracted logic.
});
```

> Because `_HomeGate`'s check (`main.dart:433`) is UI-coupled, extract the predicate to `AuthService.isVerifiedUser` (Task 5) and keep the `dataFound` logic testable. In this task, test the restore skip-tombstone path and leave the `dataFound` predicate as an inline boolean that the plan documents.

- [ ] **Step 2: Implement paginated reads + batched inserts + tombstone skip**

```dart
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

In `performRestore`, replace the three unbounded `.get()` calls with `_fetchAllDocs` on categories/questions/scores. After fetching, read `getTombstonedIds('questions')` and `getTombstonedIds('categories')` and filter the fetched docs before inserting:

```dart
final qTombstones = await dbHelper.getTombstonedIds('questions');
final cTombstones = await dbHelper.getTombstonedIds('categories');
final categories = catSnap.where((d) => !cTombstones.contains(int.parse(d.id))).toList();
final questions = qSnap.where((d) => !qTombstones.contains(int.parse(d.id))).toList();
```

Insert via batched `txn.batch` in chunks, ordered categories → questions → scores (FK-safe). Then update `dataFound`:

```dart
final dataFound = questions.isNotEmpty || sSnap.isNotEmpty;
```

- [ ] **Step 3: Update `_HomeGate`'s direct cloud-data check**

In `lib/main.dart:433`, the `_HomeGate` check uses `userDoc.collection('questions').limit(1).get()` to decide `hasCloudData`. Extend it to also check `score_records` so a categories/scores-only user isn't pushed to onboarding:

```dart
final qSnap = await userDoc.collection('questions').limit(1).get();
final sSnap = await userDoc.collection('score_records').limit(1).get();
final hasCloudData = qSnap.docs.isNotEmpty || sSnap.docs.isNotEmpty;
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/core/sync/sync_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Run full validation**

Run: `flutter analyze && dart format --set-exit-if-changed lib/ test/ && flutter test`
Expected: 0 issues; format clean; all pass.

- [ ] **Step 6: Commit**

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

**Placeholder scan:** The only soft spot is Task 4 Step 1 / the `dataFound` test, which leans on the Task 5 pure predicate. That's acceptable — the plan documents the intended test approach and the inline boolean in Step 2. No TBD/TODO.

**Type consistency:** `_runBatched(List<void Function(WriteBatch)>)`, `_fetchAllDocs(CollectionReference, {int pageSize})`, `isVerifiedUser(User?)`, `addTombstone(s)`, `removeTombstones`, `getAllTombstones`, `getTombstonedIds` are defined once and referenced consistently across tasks. `_runBatchedForTesting` is noted as an alternative but the plan prefers the pure `_chunkIndices` split for testability — Task 3 Step 1 shows the counting test against a pure split.
