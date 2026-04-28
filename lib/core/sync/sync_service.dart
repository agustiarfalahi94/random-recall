import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import '../auth/auth_service.dart';
import '../database/database_helper.dart';

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
    final isVerified = user != null &&
        (user.emailVerified || user.phoneNumber != null);
    if (!isVerified || (_isSyncing && !force)) return;

    _isSyncing = true;
    debugPrint('SyncService: Starting backup for user ${user.uid}...');

    final trace = FirebasePerformance.instance.newTrace('sync_backup');
    await trace.start();
    try {
      final userDoc = _db.collection('users').doc(user.uid);
      final batch = _db.batch();

      // 1. Backup Categories
      final categories = await _dbHelper.getAllCategories();
      for (final cat in categories) {
        if (cat.id == null) continue;
        final docRef = userDoc.collection('categories').doc(cat.id.toString());
        batch.set(docRef, cat.toMap(), SetOptions(merge: true));
      }

      // 2. Backup Questions
      final questions = await _dbHelper.getAllQuestions();
      for (final q in questions) {
        if (q.id == null) continue;
        final docRef = userDoc.collection('questions').doc(q.id.toString());
        batch.set(docRef, q.toMap(), SetOptions(merge: true));
      }

      // 3. Backup Score Records
      final scores = await _dbHelper.getAllScoreRecords();
      for (final s in scores) {
        if (s.id == null) continue;
        final docRef = userDoc.collection('score_records').doc(s.id.toString());
        batch.set(docRef, s.toMap(), SetOptions(merge: true));
      }

      // 4. Backup User Settings (SharedPreferences)
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

      final streakData = {
        'timer_streak_days': prefs.getInt('timer_streak_days') ?? 0,
        'timer_streak_last_date':
            prefs.getString('timer_streak_last_date') ?? '',
        'timer_streak_bonus_questions':
            prefs.getInt('timer_streak_bonus_questions') ?? 0,
      };

      // Record which device performed this backup
      final deviceId = prefs.getString('device_id') ?? 'unknown';

      // 4. Commit all changes at once
      batch.set(userDoc, {
        'last_active_device_id': deviceId,
      }, SetOptions(merge: true));
      await batch.commit();

      // 5. Update user profile with metadata
      await userDoc.set({
        'last_sync_at': FieldValue.serverTimestamp(),
        'settings': settings,
        'streak': streakData,
        'onboarding_complete': prefs.getBool('onboarding_complete') ?? false,
      }, SetOptions(merge: true));

      trace.putAttribute('question_count', questions.length.toString());
      debugPrint(
        'SyncService: Backup success. ${categories.length} categories, ${questions.length} questions, ${scores.length} scores synced.',
      );
    } catch (e) {
      debugPrint('SyncService: Backup failed: $e');
      // Don't rethrow here so the UI calling it doesn't crash
    } finally {
      await trace.stop();
      _isSyncing = false;
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
    final isVerifiedRestore = user != null &&
        (user.emailVerified || user.phoneNumber != null);
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

      // Fetch everything from cloud first to keep the transaction short
      debugPrint('SyncService: Fetching categories from cloud...');
      final catSnap = await userDoc.collection('categories').get();
      debugPrint('SyncService: Got ${catSnap.docs.length} categories');
      for (var i = 0; i < catSnap.docs.length; i++) {
        final data = catSnap.docs[i].data();
        debugPrint('SyncService: Category[$i]: id=${data['id']}, name=${data['name']}');
      }

      debugPrint('SyncService: Fetching questions from cloud...');
      final qSnap = await userDoc.collection('questions').get();
      debugPrint('SyncService: Got ${qSnap.docs.length} questions');
      for (var i = 0; i < qSnap.docs.length; i++) {
        final data = qSnap.docs[i].data();
        debugPrint('SyncService: Question[$i]: id=${data['id']}, category_id=${data['category_id']}');
      }

      debugPrint('SyncService: Fetching score_records from cloud...');
      final sSnap = await userDoc.collection('score_records').get();
      debugPrint('SyncService: Got ${sSnap.docs.length} score_records');

      // Read user doc separately so a permission error here doesn't
      // block the question/category restore.
      Map<String, dynamic>? userData;
      try {
        final userSnap = await userDoc.get();
        if (userSnap.exists) userData = userSnap.data();
      } catch (e) {
        debugPrint('SyncService: User doc read failed (non-fatal): $e');
      }

      bool dataFound = qSnap.docs.isNotEmpty;

      // Execute everything in a single transaction with Foreign Keys disabled
      try {
        await db.transaction((txn) async {
          await txn.execute('PRAGMA foreign_keys = OFF');

          // If it's a forced login restore, clean up local tables first to prevent ID conflicts
          if (isInitialLogin) {
            debugPrint('SyncService: Clearing local tables for isInitialLogin...');
            await txn.delete('score_records');
            debugPrint('SyncService: Cleared score_records');
            await txn.delete('questions');
            debugPrint('SyncService: Cleared questions');
            await txn.delete('categories', where: 'is_default = 0');
            debugPrint('SyncService: Cleared non-default categories');
          }

          // 1. Restore Categories
          debugPrint('SyncService: Inserting ${catSnap.docs.length} categories...');
          for (var doc in catSnap.docs) {
            final data = doc.data();
            debugPrint('SyncService: Inserting category: id=${data['id']}, name=${data['name']}, is_default=${data['is_default']}');
            await txn.insert(
              'categories',
              data,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          debugPrint('SyncService: Categories inserted successfully');

          // 2. Restore Questions
          debugPrint('SyncService: Inserting ${qSnap.docs.length} questions...');
          for (var doc in qSnap.docs) {
            final data = doc.data();
            debugPrint('SyncService: Inserting question: id=${data['id']}, category_id=${data['category_id']}');
            await txn.insert(
              'questions',
              data,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          debugPrint('SyncService: Questions inserted successfully');

          // 3. Restore Score Records
          debugPrint('SyncService: Inserting ${sSnap.docs.length} score records...');
          for (var doc in sSnap.docs) {
            await txn.insert(
              'score_records',
              doc.data(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          debugPrint('SyncService: Score records inserted successfully');

          await txn.execute('PRAGMA foreign_keys = ON;');
        });
        debugPrint('SyncService: Transaction completed successfully');
      } catch (e) {
        debugPrint('SyncService: Transaction failed: $e');
        rethrow;
      }

      debugPrint(
        'SyncService: SQLite insert done — '
        '${catSnap.docs.length} cats, ${qSnap.docs.length} qs, ${sSnap.docs.length} scores',
      );

      // 4. Restore SharedPreferences (Settings & Streak)
      if (userData != null) {
        final data = userData;
        final prefs = await SharedPreferences.getInstance();

        // Pull Premium status directly from Firestore document root
        if (data.containsKey('is_premium')) {
          await prefs.setBool('is_premium', data['is_premium'] as bool);
        }

        if (data.containsKey('settings')) {
          final s = data['settings'] as Map<String, dynamic>;
          if (s.containsKey('notif_random_anytime'))
            await prefs.setBool(
              'notif_random_anytime',
              s['notif_random_anytime'] as bool,
            );
          if (s.containsKey('notif_start_hour'))
            await prefs.setInt(
              'notif_start_hour',
              s['notif_start_hour'] as int,
            );
          if (s.containsKey('notif_end_hour'))
            await prefs.setInt('notif_end_hour', s['notif_end_hour'] as int);
          if (s.containsKey('notif_frequency'))
            await prefs.setInt('notif_frequency', s['notif_frequency'] as int);
          if (s.containsKey('notif_active_days'))
            await prefs.setString(
              'notif_active_days',
              s['notif_active_days'] as String,
            );
          if (s.containsKey('notif_timer_seconds'))
            await prefs.setInt(
              'notif_timer_seconds',
              s['notif_timer_seconds'] as int,
            );
        }
        if (data.containsKey('streak')) {
          final str = data['streak'] as Map<String, dynamic>;
          if (str.containsKey('timer_streak_days'))
            await prefs.setInt(
              'timer_streak_days',
              str['timer_streak_days'] as int,
            );
          if (str.containsKey('timer_streak_last_date'))
            await prefs.setString(
              'timer_streak_last_date',
              str['timer_streak_last_date'] as String,
            );
          if (str.containsKey('timer_streak_bonus_questions'))
            await prefs.setInt(
              'timer_streak_bonus_questions',
              str['timer_streak_bonus_questions'] as int,
            );
        }
      }

      // Restore onboarding_complete from Firestore if present,
      // otherwise infer it from whether the user has questions in the cloud.
      if (userData != null) {
        final data = userData;
        if (data.containsKey('onboarding_complete')) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(
            'onboarding_complete',
            data['onboarding_complete'] as bool,
          );
          debugPrint(
            'SyncService: Set onboarding_complete=${data['onboarding_complete']}',
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

      trace.putAttribute('question_count', qSnap.docs.length.toString());
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
