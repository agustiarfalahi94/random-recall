import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm, Transaction;
import '../auth/auth_service.dart';
import '../database/database_helper.dart';
import '../../models/score_record.dart';

/// Service responsible for synchronizing local SQLite data with Cloud Firestore.
class SyncService {
  SyncService._internal() {
    _setupAutoSync();
  }
  static final SyncService instance = SyncService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _dbHelper = DatabaseHelper.instance;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  /// Completer that concurrent restore callers can await instead of
  /// silently returning when a restore is already in progress.
  Completer<void>? _restoreCompleter;

  void _setupAutoSync() {
    Timer? debounceTimer;
    _dbHelper.onDatabaseUpdated.listen((_) {
      if (_isSyncing) return;

      if (debounceTimer?.isActive ?? false) debounceTimer!.cancel();
      debounceTimer = Timer(const Duration(seconds: 5), () {
        performBackup().catchError((e) {
          debugPrint('SyncService: Auto-backup skipped: $e');
          return null;
        });
      });
    });
  }

  /// Performs a full backup of local data to Firestore.
  ///
  /// This iterates through Categories, Questions, and Score Records,
  /// pushing them to the user's private collection using a write batch.
  Future<void> performBackup({bool force = false}) async {
    final user = AuthService.instance.currentUser;
    final isVerified =
        user != null && (user.emailVerified || user.phoneNumber != null);
    if (!isVerified || (_isSyncing && !force)) return;

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
        deleteOps.add(
          (b) => b.delete(userDoc.collection(collection).doc(docId.toString())),
        );
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
        pruneOps.add(
          (b) => b.delete(userDoc.collection('score_records').doc(doc.id)),
        );
      }
      await _runBatched(pruneOps);

      await _runBatched(ops);

      // 4. User-doc metadata as before.
      final prefs = await SharedPreferences.getInstance();
      final settings = {
        'notif_random_anytime': prefs.getBool('notif_random_anytime') ?? true,
        'notif_start_hour': prefs.getInt('notif_start_hour') ?? 8,
        'notif_end_hour': prefs.getInt('notif_end_hour') ?? 20,
        'notif_frequency': prefs.getInt('notif_frequency') ?? 3,
        'notif_active_days':
            prefs.getString('notif_active_days') ?? '1,2,3,4,5,6,7',
        'notif_timer_seconds': prefs.getInt('notif_timer_seconds') ?? 0,
      };

      // Record which device performed this backup
      final deviceId = prefs.getString('device_id') ?? 'unknown';

      // 4. Commit metadata (unchanged from the original single-batch flow)
      final batch = _db.batch();
      batch.set(userDoc, {
        'last_active_device_id': deviceId,
        'last_sync_at': FieldValue.serverTimestamp(),
        'settings': settings,
        'onboarding_complete': prefs.getBool('onboarding_complete') ?? false,
      }, SetOptions(merge: true));
      await batch.commit();

      trace.putAttribute('question_count', questions.length.toString());
      debugPrint(
        'SyncService: Backup success. ${categories.length} categories, ${questions.length} questions, ${recentScores.length} recent scores synced.',
      );
    } catch (e, st) {
      debugPrint('SyncService: Backup failed: $e');
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'sync_backup_failed',
      );
    } finally {
      await trace.stop();
      _isSyncing = false;
    }
  }

  static const int _scoreSyncWindowDays = 30;
  static const int _batchChunkSize = 450;

  /// Splits [total] items into (start, end) index ranges, each at most
  /// [chunkSize] wide. Used to keep every Firestore batch under the 500-op cap.
  static List<(int, int)> chunkRanges(
    int total, {
    int chunkSize = _batchChunkSize,
  }) {
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
  static List<ScoreRecord> scoresForSync(
    List<ScoreRecord> all,
    DateTime cutoff,
  ) => all.where((s) => !s.answeredAt.isBefore(cutoff)).toList();

  /// True when the cloud has real user data worth restoring. Categories are
  /// excluded because the default General/Work categories are always backed up
  /// and would be a false signal.
  static bool hasCloudData({
    required bool hasQuestions,
    required bool hasScores,
  }) => hasQuestions || hasScores;

  /// Drops cloud document ids that are in the local tombstone journal, so an
  /// offline delete does not resurrect on restore.
  static List<String> dropTombstoned(
    Iterable<String> cloudDocIds,
    Set<int> tombstonedIds,
  ) => cloudDocIds
      .where((id) => !tombstonedIds.contains(int.tryParse(id)))
      .toList();

  /// Reads every document in [collection] in pages (ordered by document id)
  /// so a large collection never loads unbounded into memory. Firestore
  /// shells this in; not unit-tested.
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

  /// Inserts [docs] into [table] using a transaction-scoped sqflite Batch,
  /// chunked so each commit stays small. Runs inside the open [txn]; a
  /// `txn.batch().commit(noResult: true)` executes within the transaction
  /// rather than committing it.
  Future<void> _batchInsertDocs(
    Transaction txn,
    String table,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    for (final (start, end) in chunkRanges(docs.length)) {
      final batch = txn.batch();
      for (final doc in docs.sublist(start, end)) {
        batch.insert(
          table,
          doc.data(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    }
  }

  /// Downloads all user data from Firestore and merges it into the local database.
  /// Used when logging into a new device or performing a manual refresh.
  ///
  /// If a restore is already running, concurrent callers will **await**
  /// its completion instead of silently returning.
  Future<void> performRestore({
    bool force = false,
    bool isInitialLogin = false,
  }) async {
    final user = AuthService.instance.currentUser;
    final isVerifiedRestore =
        user != null && (user.emailVerified || user.phoneNumber != null);
    if (!isVerifiedRestore) return;

    // If a restore is already running, wait for it rather than silently
    // dropping this call. This prevents the race condition where _HomeGate
    // tries to restore but the login flow's restore is still in progress.
    if (_isSyncing) {
      if (_restoreCompleter != null) {
        debugPrint('SyncService: Restore already running, awaiting it...');
        await _restoreCompleter!.future;
      }
      return;
    }

    _restoreCompleter = Completer<void>();
    _isSyncing = true;
    debugPrint('SyncService: Starting restore for user ${user.uid}...');

    final trace = FirebasePerformance.instance.newTrace('sync_restore');
    await trace.start();
    try {
      // OPTIMIZATION: Skip automatic restore if data exists, unless forced (e.g. at login)
      final localCount = await _dbHelper.getQuestionCount();
      if (!force && localCount > 0) {
        debugPrint(
          'SyncService: Local data exists, skipping automatic full restore.',
        );
        return;
      }

      final db = await _dbHelper.database;
      final userDoc = _db.collection('users').doc(user.uid);

      // Fetch everything from cloud first to keep the transaction short,
      // reading in pages so a large collection never loads unbounded.
      final catDocs = await _fetchAllDocs(userDoc.collection('categories'));
      debugPrint('SyncService: Got ${catDocs.length} categories');

      final qDocs = await _fetchAllDocs(userDoc.collection('questions'));
      debugPrint('SyncService: Got ${qDocs.length} questions');

      final sDocs = await _fetchAllDocs(userDoc.collection('score_records'));
      debugPrint('SyncService: Got ${sDocs.length} score_records');

      // Read user doc separately so a permission error here doesn't
      // block the question/category restore.
      Map<String, dynamic>? userData;
      try {
        final userSnap = await userDoc.get();
        if (userSnap.exists) userData = userSnap.data();
      } catch (e) {
        debugPrint('SyncService: User doc read failed (non-fatal): $e');
      }

      // Drop documents the user deleted while offline — the tombstone journal
      // records them so a restore does not resurrect a deleted question or
      // category. Score records are append-only and never tombstoned.
      final qTombstones = await _dbHelper.getTombstonedIds('questions');
      final cTombstones = await _dbHelper.getTombstonedIds('categories');
      final keptCIds = dropTombstoned(
        catDocs.map((d) => d.id),
        cTombstones,
      ).toSet();
      final keptQIds = dropTombstoned(
        qDocs.map((d) => d.id),
        qTombstones,
      ).toSet();
      final keptCatDocs = catDocs
          .where((d) => keptCIds.contains(d.id))
          .toList();
      final keptQDocs = qDocs.where((d) => keptQIds.contains(d.id)).toList();

      // A restore counts as "data found" when the cloud has real user data.
      // Categories are excluded — the default General/Work categories are
      // always backed up and would be a false signal.
      final bool dataFound = hasCloudData(
        hasQuestions: qDocs.isNotEmpty,
        hasScores: sDocs.isNotEmpty,
      );

      // Execute everything in a single transaction with Foreign Keys enabled.
      // Inserts stay FK-ordered (categories → questions → scores) and the
      // isInitialLogin wipe runs children-first, so constraints are always met.
      try {
        await db.transaction((txn) async {
          // If it's a forced login restore, clean up local tables first to prevent ID conflicts
          if (isInitialLogin) {
            debugPrint(
              'SyncService: Clearing local tables for isInitialLogin...',
            );
            await txn.delete('score_records');
            debugPrint('SyncService: Cleared score_records');
            await txn.delete('questions');
            debugPrint('SyncService: Cleared questions');
            await txn.delete('categories', where: 'is_default = 0');
            debugPrint('SyncService: Cleared non-default categories');
          }

          // 1. Restore Categories
          await _batchInsertDocs(txn, 'categories', keptCatDocs);

          // 2. Restore Questions
          await _batchInsertDocs(txn, 'questions', keptQDocs);

          // 3. Restore Score Records
          await _batchInsertDocs(txn, 'score_records', sDocs);
        });
        debugPrint('SyncService: Transaction completed successfully');
      } catch (e) {
        debugPrint('SyncService: Transaction failed: $e');
        rethrow;
      }

      debugPrint(
        'SyncService: SQLite insert done — '
        '${keptCatDocs.length} cats, ${keptQDocs.length} qs, ${sDocs.length} scores',
      );

      // 4. Restore SharedPreferences (Settings & Streak)
      if (userData != null) {
        final prefs = await SharedPreferences.getInstance();

        // Pull Premium status directly from Firestore document root
        if (userData.containsKey('is_premium')) {
          await prefs.setBool('is_premium', userData['is_premium'] as bool);
        }

        if (userData.containsKey('settings')) {
          final s = userData['settings'] as Map<String, dynamic>;
          if (s.containsKey('notif_random_anytime')) {
            await prefs.setBool(
              'notif_random_anytime',
              s['notif_random_anytime'] as bool,
            );
          }
          if (s.containsKey('notif_start_hour')) {
            await prefs.setInt(
              'notif_start_hour',
              s['notif_start_hour'] as int,
            );
          }
          if (s.containsKey('notif_end_hour')) {
            await prefs.setInt('notif_end_hour', s['notif_end_hour'] as int);
          }
          if (s.containsKey('notif_frequency')) {
            await prefs.setInt('notif_frequency', s['notif_frequency'] as int);
          }
          if (s.containsKey('notif_active_days')) {
            await prefs.setString(
              'notif_active_days',
              s['notif_active_days'] as String,
            );
          }
          if (s.containsKey('notif_timer_seconds')) {
            await prefs.setInt(
              'notif_timer_seconds',
              s['notif_timer_seconds'] as int,
            );
          }
        }
        // Streak data is NOT restored here — StreakService.loadFromCloud()
        // reads from the private/streakData subcollection which is the single
        // source of truth and is always up-to-date after challenge events.
      }

      // Restore onboarding_complete from Firestore if present,
      // otherwise infer it from whether the user has questions in the cloud.
      if (userData != null) {
        if (userData.containsKey('onboarding_complete')) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(
            'onboarding_complete',
            userData['onboarding_complete'] as bool,
          );
          debugPrint(
            'SyncService: Set onboarding_complete=${userData['onboarding_complete']}',
          );
        } else if (dataFound) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('onboarding_complete', true);
          debugPrint(
            'SyncService: Set onboarding_complete=true (inferred from data)',
          );
        }
      } else if (dataFound) {
        // User doc read failed but questions exist — still mark as complete
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_complete', true);
        debugPrint(
          'SyncService: Set onboarding_complete=true (user doc unreadable but questions exist)',
        );
      }

      // Claim this device as the active one after a login restore.
      // This MUST happen before _checkActiveDevice() runs, otherwise
      // a stale last_active_device_id from a previous installation
      // will cause an immediate sign-out.
      if (isInitialLogin) {
        final devicePrefs = await SharedPreferences.getInstance();
        final deviceId = devicePrefs.getString('device_id') ?? 'unknown';
        await userDoc.set({
          'last_active_device_id': deviceId,
        }, SetOptions(merge: true));
        debugPrint(
          'SyncService: Claimed device $deviceId as active after restore',
        );
      }

      // Refresh the UI so the user sees their restored data immediately
      _dbHelper.notifyUpdate();

      trace.putAttribute('question_count', qDocs.length.toString());
      debugPrint('SyncService: Restore completed successfully.');
    } catch (e) {
      debugPrint('SyncService: Restore failed with error: $e');
    } finally {
      await trace.stop();
      _isSyncing = false;
      _restoreCompleter?.complete();
      _restoreCompleter = null;
    }
  }
}
