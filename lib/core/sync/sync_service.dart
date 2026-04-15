import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import '../../models/category.dart';
import '../../models/question.dart';
import '../../models/score_record.dart';
import '../auth/auth_service.dart';
import '../database/database_helper.dart';
import '../notifications/notification_service.dart';

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

  final List<StreamSubscription> _subscriptions = [];

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

  /// Starts listening to Firestore collections for real-time changes.
  /// Only activates for premium users.
  void startRealtimeSync() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    
    stopRealtimeSync(); // Clear existing listeners first
    debugPrint('SyncService: Starting real-time listeners for ${user.uid}...');

    final userDoc = _db.collection('users').doc(user.uid);

    // 1. Listen to Categories
    _subscriptions.add(userDoc.collection('categories').snapshots().listen((snap) {
      _applyRemoteChanges(snap, 'categories', (map) => Category.fromMap(map));
    }));

    // 2. Listen to Questions
    _subscriptions.add(userDoc.collection('questions').snapshots().listen((snap) {
      _applyRemoteChanges(snap, 'questions', (map) => Question.fromMap(map));
    }));

    // 3. Listen to Score Records
    _subscriptions.add(userDoc.collection('score_records').snapshots().listen((snap) {
      _applyRemoteChanges(snap, 'score_records', (map) => ScoreRecord.fromMap(map));
    }));

    // 4. Listen to user doc (Settings & Streak)
    _subscriptions.add(userDoc.snapshots().listen((doc) async {
      if (!doc.exists || _isSyncing) return;
      final data = doc.data();
      if (data == null) return;

      final prefs = await SharedPreferences.getInstance();
      
      // Update Premium status in real-time
      if (data.containsKey('is_premium')) {
        await prefs.setBool('is_premium', data['is_premium'] as bool);
      }

      if (data.containsKey('settings')) {
        final s = data['settings'] as Map<String, dynamic>;
        if (s.containsKey('notif_frequency')) await prefs.setInt('notif_frequency', s['notif_frequency']);
        if (s.containsKey('notif_timer_seconds')) await prefs.setInt('notif_timer_seconds', s['notif_timer_seconds']);
        if (s.containsKey('notif_random_anytime')) await prefs.setBool('notif_random_anytime', s['notif_random_anytime']);
        if (s.containsKey('notif_start_hour')) await prefs.setInt('notif_start_hour', s['notif_start_hour']);
        if (s.containsKey('notif_end_hour')) await prefs.setInt('notif_end_hour', s['notif_end_hour']);
        if (s.containsKey('notif_active_days')) await prefs.setString('notif_active_days', s['notif_active_days']);
        await NotificationService.instance.scheduleNotifications();
      }
      if (data.containsKey('streak')) {
        final str = data['streak'] as Map<String, dynamic>;
        if (str.containsKey('timer_streak_days')) await prefs.setInt('timer_streak_days', str['timer_streak_days']);
      }
    }));
  }

  /// Stops all active Firestore listeners.
  void stopRealtimeSync() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    debugPrint('SyncService: Real-time listeners stopped.');
  }

  /// Helper to process Firestore snapshots and merge them into SQLite
  Future<void> _applyRemoteChanges<T>(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    String tableName,
    T Function(Map<String, dynamic>) fromMap,
  ) async {
    if (_isSyncing) return;
    _isSyncing = true; // Prevent backup loop during remote apply
    
    try {
      final db = await _dbHelper.database;
      bool localChanged = false;

      // Disable foreign keys for the connection during this operation
      await db.execute('PRAGMA foreign_keys = OFF;');

      await db.transaction((txn) async {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
            final remoteData = change.doc.data();
            if (remoteData == null) continue;

            // NORMALIZE: Go through model to filter extra fields and convert types (bool -> int)
            final model = fromMap(remoteData);
            Map<String, dynamic>? map;
            if (model is Category) map = model.toMap();
            else if (model is Question) map = model.toMap();
            else if (model is ScoreRecord) map = model.toMap();

            if (map != null) {
              await txn.insert(tableName, map, conflictAlgorithm: ConflictAlgorithm.replace);
              localChanged = true;
            }
          }
        }
      });

      await db.execute('PRAGMA foreign_keys = ON;');

      if (localChanged) {
        _dbHelper.notifyUpdate(); // Refresh UI screens
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Performs a full backup of local data to Firestore.
  ///
  /// This iterates through Categories, Questions, and Score Records, 
  /// pushing them to the user's private collection using a write batch.
  Future<void> performBackup({bool force = false}) async {
    final user = AuthService.instance.currentUser;
    if (user == null || !user.emailVerified || (_isSyncing && !force)) return;

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
        'notif_active_days': prefs.getString('notif_active_days') ?? '1,2,3,4,5,6,7',
        'notif_timer_seconds': prefs.getInt('notif_timer_seconds') ?? 0,
      };

      final streakData = {
        'timer_streak_days': prefs.getInt('timer_streak_days') ?? 0,
        'timer_streak_last_date': prefs.getString('timer_streak_last_date') ?? '',
        'timer_streak_bonus_questions': prefs.getInt('timer_streak_bonus_questions') ?? 0,
      };

      // 4. Commit all changes at once
      await batch.commit();

      // 5. Update user profile with metadata
      await userDoc.set({
        'last_sync_at': FieldValue.serverTimestamp(),
        'settings': settings,
        'streak': streakData,
        'onboarding_complete': prefs.getBool('onboarding_complete') ?? false,
      }, SetOptions(merge: true));

      trace.putAttribute('question_count', questions.length.toString());
      debugPrint('SyncService: Backup success. ${categories.length} categories, ${questions.length} questions, ${scores.length} scores synced.');
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
  Future<void> performRestore({bool force = false, bool isInitialLogin = false}) async {
    final user = AuthService.instance.currentUser;
    if (user == null || !user.emailVerified || _isSyncing) return;
    
    _isSyncing = true;
    debugPrint('SyncService: Starting restore for user ${user.uid}...');

    final trace = FirebasePerformance.instance.newTrace('sync_restore');
    await trace.start();
    try {
      // OPTIMIZATION: Skip automatic restore if data exists, unless forced (e.g. at login)
      final localCount = await _dbHelper.getQuestionCount();
      if (!force && localCount > 0) {
        debugPrint('SyncService: Local data exists, skipping automatic full restore.');
        return;
      }

      final db = await _dbHelper.database;
      final userDoc = _db.collection('users').doc(user.uid);
      
      // Fetch everything from cloud first to keep the transaction short
      final catSnap = await userDoc.collection('categories').get();
      final qSnap = await userDoc.collection('questions').get();
      final sSnap = await userDoc.collection('score_records').get();
      final userSnap = await userDoc.get();

      bool dataFound = qSnap.docs.isNotEmpty;

      // Execute everything in a single transaction with Foreign Keys disabled
      await db.transaction((txn) async {
        await txn.execute('PRAGMA foreign_keys = OFF');

        // If it's a forced login restore, clean up local tables first to prevent ID conflicts
        if (isInitialLogin) {
          await txn.delete('score_records');
          await txn.delete('questions');
          await txn.delete('categories', where: 'is_default = 0');
        }

        // 1. Restore Categories
        for (var doc in catSnap.docs) {
          await txn.insert('categories', doc.data(), conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // 2. Restore Questions
        for (var doc in qSnap.docs) {
          await txn.insert('questions', doc.data(), conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // 3. Restore Score Records
        for (var doc in sSnap.docs) {
          await txn.insert('score_records', doc.data(), conflictAlgorithm: ConflictAlgorithm.replace);
        }

        await txn.execute('PRAGMA foreign_keys = ON;');
      });

      // 4. Restore SharedPreferences (Settings & Streak)
      if (userSnap.exists && userSnap.data() != null) {
        final data = userSnap.data()!;
        final prefs = await SharedPreferences.getInstance();
        
        // Pull Premium status directly from Firestore document root
        if (data.containsKey('is_premium')) {
          await prefs.setBool('is_premium', data['is_premium'] as bool);
        }

        if (data.containsKey('settings')) {
          final s = data['settings'] as Map<String, dynamic>;
          if (s.containsKey('notif_random_anytime')) await prefs.setBool('notif_random_anytime', s['notif_random_anytime'] as bool);
          if (s.containsKey('notif_start_hour')) await prefs.setInt('notif_start_hour', s['notif_start_hour'] as int);
          if (s.containsKey('notif_end_hour')) await prefs.setInt('notif_end_hour', s['notif_end_hour'] as int);
          if (s.containsKey('notif_frequency')) await prefs.setInt('notif_frequency', s['notif_frequency'] as int);
          if (s.containsKey('notif_active_days')) await prefs.setString('notif_active_days', s['notif_active_days'] as String);
          if (s.containsKey('notif_timer_seconds')) await prefs.setInt('notif_timer_seconds', s['notif_timer_seconds'] as int);
        }
        if (data.containsKey('streak')) {
          final str = data['streak'] as Map<String, dynamic>;
          if (str.containsKey('timer_streak_days')) await prefs.setInt('timer_streak_days', str['timer_streak_days'] as int);
          if (str.containsKey('timer_streak_last_date')) await prefs.setString('timer_streak_last_date', str['timer_streak_last_date'] as String);
          if (str.containsKey('timer_streak_bonus_questions')) await prefs.setInt('timer_streak_bonus_questions', str['timer_streak_bonus_questions'] as int);
        }
      }

      // Restore onboarding_complete from Firestore if present,
      // otherwise infer it from whether the user has questions in the cloud.
      if (userSnap.exists && userSnap.data() != null) {
        final data = userSnap.data()!;
        if (data.containsKey('onboarding_complete')) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('onboarding_complete', data['onboarding_complete'] as bool);
        } else if (dataFound) {
          // Legacy accounts that predate this field: infer from question presence
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('onboarding_complete', true);
        }
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
    }
  }
}