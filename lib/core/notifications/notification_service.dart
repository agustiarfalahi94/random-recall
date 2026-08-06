import 'dart:async';
import 'dart:convert';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:firebase_performance/firebase_performance.dart';

import '../config/remote_config_service.dart';
import '../database/database_helper.dart';
import '../../models/question.dart';
import '../streak/streak_service.dart';
import 'notification_scheduler.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  GlobalKey<NavigatorState>? navigatorKey;

  bool _initialized = false;
  bool _listenerRegistered = false;
  bool _isScheduling = false;
  Completer<void>? _initCompleter;
  Timer? _scheduleDebounceTimer;
  // Set to true when _onNotificationTapped successfully handles a tap so that
  // handleNotificationLaunch() doesn't push a second question screen for the
  // same notification (double-navigation bug on MIUI/HyperOS background starts).
  bool _notificationNavigationHandled = false;
  int? _lastTappedQuestionId;
  DateTime? _lastTapTime;

  // Fires whenever a notification is answered (tray cleared).
  // Home screen subscribes to this to refresh the badge immediately.
  final StreamController<void> _answeredController =
      StreamController<void>.broadcast();
  Stream<void> get onNotificationAnswered => _answeredController.stream;

  Future<void> dispose() async {
    await _answeredController.close();
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;

    // Deduplicate concurrent init() calls — latecomers await the in-flight init.
    if (_initCompleter != null) return _initCompleter!.future;

    debugPrint('NotificationService: Initializing...');
    final completer = Completer<void>();
    _initCompleter = completer;

    try {
      // Wrap in a defensive timeout. If the native side hangs (common on MIUI/HyperOS),
      // we complete the future anyway so the app can continue.
      await _actualInit().timeout(const Duration(seconds: 4));
      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService: Initialization error: $e');
      // Mark initialized on timeout so we don't spin forever — the plugin
      // state is indeterminate but repeated init loops are worse.
      _initialized = true;
    } finally {
      if (!completer.isCompleted) {
        debugPrint('NotificationService: Init completer completed.');
        completer.complete();
      }
      // Null the completer so a subsequent init() call can re-enter if needed.
      _initCompleter = null;
    }

    // Register the database-change listener exactly once, AFTER init completes
    // so that _listenerRegistered is only set when we know _initialized is true.
    if (!_listenerRegistered) {
      _listenerRegistered = true;
      DatabaseHelper.instance.onDatabaseUpdated.listen((_) {
        if (_scheduleDebounceTimer?.isActive ?? false) {
          _scheduleDebounceTimer!.cancel();
        }
        _scheduleDebounceTimer = Timer(const Duration(seconds: 5), () async {
          final prefs = await SharedPreferences.getInstance();
          final lastCount = prefs.getInt('last_known_question_count') ?? 0;
          final currentCount = await DatabaseHelper.instance.getQuestionCount();

          if (currentCount != lastCount) {
            await prefs.setInt('last_known_question_count', currentCount);
            await scheduleNotifications();
          }
        });
      });
    }
  }

  Future<void> _actualInit() async {
    tz.initializeTimeZones();
    try {
      debugPrint('NotificationService: Setting local timezone...');
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timezoneInfo.identifier;
      debugPrint(
        'NotificationService: Detected device timezone: $timeZoneName',
      );
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('NotificationService: Timezone detection failed: $e');
      tz.setLocalLocation(tz.UTC);
    }
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    debugPrint('NotificationService: Initializing plugin...');
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Ensure the notification channel exists with the correct alarm audio
    // attributes (DND bypass). Android ignores updates to channel settings on
    // existing channels, so for users upgrading from an older build with the
    // wrong settings we need a ONE-TIME delete-and-recreate migration.
    //
    // CRITICAL: Do NOT delete the channel on every launch. Deleting a channel
    // wipes ALL its active tray notifications, which on MIUI/HyperOS (where
    // the app is aggressively killed in the background) means every cold
    // start from the launcher would erase pending notifications from the tray.
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final prefs = await SharedPreferences.getInstance();
    const migrationKey = 'notif_channel_v2_migrated';
    final alreadyMigrated = prefs.getBool(migrationKey) ?? false;

    if (!alreadyMigrated) {
      // First run on this build: delete the legacy channel (if any) and
      // recreate it with the alarm audio attributes. This wipes the tray once,
      // which is acceptable on a one-time migration.
      await androidPlugin?.deleteNotificationChannel(
        channelId: 'random_recall_channel',
      );
      debugPrint(
        'NotificationService: Legacy channel deleted (one-time migration).',
      );
    }

    // createNotificationChannel is a no-op if a channel with this ID already
    // exists, so it's safe to call on every launch.
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'random_recall_channel',
        'Random Recall',
        description: 'Random quiz reminders',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        // alarm usage lets this channel bypass DND/silent mode
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );

    if (!alreadyMigrated) {
      await prefs.setBool(migrationKey, true);
      debugPrint(
        'NotificationService: Channel recreated with alarm audio attributes (migrated).',
      );
    } else {
      debugPrint(
        'NotificationService: Channel already migrated, preserving tray.',
      );
    }
  }

  // ── Mirror log cleanup ────────────────────────────────────────────────────

  /// Removes mirror-log entries whose question IDs no longer exist in the DB.
  /// Called at startup so a stale badge from previously-deleted questions is
  /// cleared immediately without waiting for the next full reschedule.
  Future<void> cleanStaleMirrorEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('notif_schedule_mirror');
      if (raw == null) return;

      final questions = await DatabaseHelper.instance.getAllQuestions();
      final validQids = questions
          .where((q) => q.id != null)
          .map((q) => q.id!)
          .toSet();

      final list = List<Map<String, dynamic>>.from(jsonDecode(raw));
      final cleaned = list.where((entry) {
        final qid = entry['id'] as int?;
        return qid == null || validQids.contains(qid);
      }).toList();

      if (cleaned.length != list.length) {
        await prefs.setString('notif_schedule_mirror', jsonEncode(cleaned));
        _answeredController.add(null); // refresh badge
        debugPrint(
          'NotificationService: Removed ${list.length - cleaned.length} stale mirror entries for deleted questions.',
        );
      }
    } catch (e) {
      debugPrint('NotificationService: cleanStaleMirrorEntries error: $e');
    }
  }

  // ── Permission ────────────────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    debugPrint('NotificationService: Requesting notification permissions...');
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    // Request POST_NOTIFICATIONS (Android 13+).
    final notifGranted =
        await android?.requestNotificationsPermission() ?? false;
    debugPrint(
      'NotificationService: Notifications permission granted: $notifGranted',
    );

    // Request SCHEDULE_EXACT_ALARM if not already granted.
    // On Android 13+ this is pre-granted at install — the call is a no-op.
    // On Android 12 it opens the "Alarms & Reminders" system settings page.
    // Note: We use inexactAllowWhileIdle by default, but still check for exact
    // permission for alarmClock mode, which is more reliable.
    final canExact = await android?.canScheduleExactNotifications() ?? true;
    debugPrint(
      'NotificationService: Exact alarm permission granted: $canExact',
    );
    if (!canExact) {
      try {
        await AppSettings.openAppSettings(type: AppSettingsType.alarm);
      } catch (_) {
        await android?.requestExactAlarmsPermission();
      }
    }

    return notifGranted;
  }

  /// Returns true if the app currently has notification permission granted.
  Future<bool> hasPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.areNotificationsEnabled() ?? true;
  }

  // ── Settings sanitization ─────────────────────────────────────────────────

  /// Detects and resets corrupted notification time-window settings.
  /// Gemini's timezone bug could save hours in UTC (e.g. 0am–1am for a
  /// GMT+8 user who configured 8am–9am). Reset to safe defaults when detected.
  void _sanitizeNotificationPrefs(SharedPreferences prefs) {
    final randomAnytime = prefs.getBool('notif_random_anytime') ?? true;
    if (!randomAnytime) {
      final startHour = prefs.getInt('notif_start_hour') ?? 8;
      final endHour = prefs.getInt('notif_end_hour') ?? 20;
      // Corrupted if window span is 0 hours (start == end).
      // Overnight windows (e.g. 23→2) are valid — span wraps around midnight.
      final span = (endHour - startHour) % 24;
      if (span < 1) {
        debugPrint(
          'NotificationService: Corrupted time window ($startHour–$endHour). Resetting to 8–20.',
        );
        prefs.setInt('notif_start_hour', 8);
        prefs.setInt('notif_end_hour', 20);
      }
    }
  }

  // ── Schedule 7 days of one-time notifications ─────────────────────────────
  //
  // Rules enforced:
  //   1. No same question in the same day's slots (distinct per day).
  //   2. Across 7 days, prefer questions not yet used this week (reduces
  //      week-over-week repeats for small question pools).
  //   3. Slots within a day are evenly spaced across the active window
  //      with a small random jitter so they don't feel mechanical.
  ///   4. Uses tz-aware 'now' to prevent scheduling in the past.

  Future<void> scheduleNotifications() async {
    // Guard against concurrent calls — two simultaneous scheduling runs
    // will interleave their zonedSchedule() calls and can corrupt the
    // AlarmManager state. Drop any call that arrives while one is running.
    if (_isScheduling) {
      debugPrint(
        'NotificationService: Scheduling already in progress, skipping.',
      );
      return;
    }
    _isScheduling = true;
    try {
      await _scheduleNotificationsInternal();
    } finally {
      _isScheduling = false;
    }
  }

  Future<void> _scheduleNotificationsInternal() async {
    debugPrint('NotificationService: Scheduling notifications...');
    final trace = FirebasePerformance.instance.newTrace(
      'notification_schedule',
    );
    await trace.start();
    // Ensure we are initialized and have a valid non-UTC timezone if possible
    if (!_initialized) await init();

    if (tz.local == tz.UTC) {
      debugPrint(
        'NotificationService: Timezone not ready. Aborting schedule to prevent UTC shift.',
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Force refresh to catch recent UI changes
    _sanitizeNotificationPrefs(prefs);

    final randomAnytime = prefs.getBool('notif_random_anytime') ?? true;
    final rc = RemoteConfigService.instance;
    final startHour = prefs.getInt('notif_start_hour') ?? rc.notifStartHour;
    final endHour = prefs.getInt('notif_end_hour') ?? rc.notifEndHour;
    final frequency = prefs.getInt('notif_frequency') ?? rc.notifFrequencyFree;
    final challengeActive = StreakService.instance.isChallengeActive;
    final lockedDays = StreakService.instance.lockedActiveDaysCsv;
    final activeDaysStr = challengeActive && lockedDays != null
        ? lockedDays
        : (prefs.getString('notif_active_days') ?? '1,2,3,4,5,6,7');

    debugPrint(
      'NotificationService: Settings used: randomAnytime=$randomAnytime, '
      'startHour=$startHour, endHour=$endHour, frequency=$frequency, '
      'activeDays=$activeDaysStr',
    );
    final activeDays = activeDaysStr
        .split(',')
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
    if (activeDays.isEmpty) activeDays.addAll({1, 2, 3, 4, 5, 6, 7});

    // Fetch all questions once; the scheduler picks from them.
    final questions = await DatabaseHelper.instance.getAllQuestions();
    debugPrint('NotificationService: Found ${questions.length} questions.');
    if (questions.isEmpty) {
      debugPrint('NotificationService: No questions in DB. Aborting schedule.');
      return;
    }

    final questionIds = questions
        .where((q) => q.id != null)
        .map((q) => q.id!)
        .toList();

    final slots = NotificationScheduler.computeSlots(
      randomAnytime: randomAnytime,
      startHour: startHour,
      endHour: endHour,
      frequency: frequency,
      activeDays: activeDays,
      now: tz.TZDateTime.now(tz.local),
      questionIds: questionIds,
    );
    debugPrint(
      'NotificationService: Calculated ${slots.length} notification slots for the next 7 days.',
    );

    if (slots.isEmpty) return;

    // 1. Cancel all pending alarms before scheduling new ones.
    // This is necessary when the user reduces their frequency: without cancelAll(),
    // the old higher-frequency alarms remain active in the OS alongside the new ones.
    // cancelAll() only affects pending (not yet fired) alarms — active tray
    // notifications are NOT touched by this call.
    await _plugin.cancelAll();

    // 2. Generate stable IDs and mirror log for the debug menu & tray matching.
    // Multiplier = 100 so that up to 100 slots/day can be safely accommodated
    // (slider max is 50, so this gives 2x headroom with no cross-day collision).
    // Stable ID = days-since-epoch * 100 + slotIndex. Unique across the entire
    // 8-day schedule window AND deterministic across reschedules (no week-collision).
    int idForSlot(tz.TZDateTime when, int slotIndex) {
      final daysSinceEpoch = when.toUtc().millisecondsSinceEpoch ~/ 86400000;
      return (daysSinceEpoch * 100) + slotIndex;
    }

    final futureList = slots.map((s) {
      return {
        'time': s.scheduledAt.toIso8601String(),
        'id': s
            .questionId, // Renamed back to 'id' for DebugNotificationScreen compatibility
        'notif_id': idForSlot(s.scheduledAt, s.slotIndex),
      };
    }).toList();

    // Build the set of valid question IDs so we can drop mirror entries for
    // deleted questions. Without this, badge counts get stuck when a question
    // is deleted while it still has unanswered fired notifications in the log.
    final validQids = questionIds.toSet();

    // Preserve already-delivered entries so the home-screen unanswered lookup
    // can still resolve them after a reschedule. Two cases keep an entry:
    //   1. It's still in the active tray (stock Android).
    //   2. It's a past unanswered fire within the 24 h window (MIUI/HyperOS,
    //      where the active tray is always empty due to notification grouping).
    final preservedDelivered = <Map<String, dynamic>>[];
    try {
      final activeNow = await _plugin.getActiveNotifications();
      final activeIds = activeNow.map((n) => n.id).whereType<int>().toSet();
      final oldRaw = prefs.getString('notif_schedule_mirror');
      if (oldRaw != null) {
        final oldList = List<Map<String, dynamic>>.from(jsonDecode(oldRaw));
        final newNotifIds = futureList
            .map((e) => e['notif_id'] as int?)
            .whereType<int>()
            .toSet();
        final now = DateTime.now();
        final cutoff = now.subtract(const Duration(hours: 24));
        for (final entry in oldList) {
          final nid = entry['notif_id'] as int?;
          if (nid == null) continue;

          // Drop entries for questions that no longer exist in the database.
          // This clears the badge when a question is deleted while it still
          // has unanswered fired notifications in the mirror log.
          final entryQid = entry['id'] as int?;
          if (entryQid != null && !validQids.contains(entryQid)) continue;

          final inActiveTray = activeIds.contains(nid);

          bool isRecentUnansweredFire = false;
          if (entry['answered_at'] == null) {
            final scheduled = DateTime.tryParse(entry['time'] as String? ?? '');
            if (scheduled != null &&
                scheduled.isBefore(now) &&
                scheduled.isAfter(cutoff)) {
              isRecentUnansweredFire = true;
            }
          }

          // Preserve delivered entries BEFORE checking for ID collision with
          // the new schedule. idForSlot() is day-based (daysSinceEpoch * 20 +
          // slotIndex), so a new future slot and a past-fired slot on the same
          // day can share the same notif_id when the time window changes.
          // Without this guard, the fired entry is silently dropped and the
          // badge count falls incorrectly. Having both entries in the log is
          // harmless: the future entry's time > now, so _firedAndUnansweredQids
          // won't double-count it.
          if (inActiveTray || isRecentUnansweredFire) {
            preservedDelivered.add(entry);
            continue; // don't fall through to the ID-collision skip below
          }

          // Not yet delivered — skip if the new schedule will overwrite this ID.
          if (newNotifIds.contains(nid)) continue;
        }
      }
    } catch (e) {
      debugPrint(
        'NotificationService: Could not preserve delivered mirror entries: $e',
      );
    }

    final debugList = [...preservedDelivered, ...futureList];
    await prefs.setString('notif_schedule_mirror', jsonEncode(debugList));

    final questionMap = {for (final q in questions) q.id!: q};
    for (int i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final question = questionMap[slot.questionId];
      if (question == null) continue;

      final scheduledDate = slot.scheduledAt;
      final notifId = idForSlot(scheduledDate, slot.slotIndex);

      // Add a tiny delay every 10 items to let the UI thread breathe
      // and avoid saturating the platform channel.
      if (i % 5 == 0) {
        await Future.delayed(const Duration(milliseconds: 16));
      }

      await _scheduleOneTimeNotification(
        id: notifId,
        scheduledDate: scheduledDate,
        question: question,
      );

      if (i == 0) {
        // log only the first one
        debugPrint(
          'NotificationService: First upcoming notification at: $scheduledDate',
        );
      }
    }

    trace.putAttribute('slot_count', slots.length.toString());
    await trace.stop();
    debugPrint(
      'NotificationService: Successfully batched ${slots.length} alarms to Android.',
    );
  }

  /// Returns the number of currently pending (not-yet-fired) notifications.
  Future<int> pendingCount() async {
    final list = await _plugin.pendingNotificationRequests();
    return list.length;
  }

  /// Returns the actual list of pending notification requests from the OS.
  Future<List<PendingNotificationRequest>> getPendingRequests() async {
    return await _plugin.pendingNotificationRequests();
  }

  /// Returns our locally mirrored schedule log.
  Future<List<Map<String, dynamic>>> getMirrorLog() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('notif_schedule_mirror');
    if (data == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(data));
  }

  /// Calculates how many distinct questions have fired notifications that
  /// the user hasn't answered yet.
  ///
  /// Returns the union of two sources:
  ///   1. Questions whose notifications are still in the system tray.
  ///   2. Questions that fired but aren't in the tray (delayed by MIUI/HyperOS,
  ///      swiped by the user, or grouped by the OS) — read from the mirror log
  ///      where `answered_at` is still null.
  ///
  /// Combining (rather than short-circuiting on the tray) is what keeps the
  /// badge stable when the tray is partially populated: e.g. 1 fresh tray
  /// notification + 2 delayed past fires must read as 3, not 1.
  Future<int> getUnansweredCount() async {
    final qids = <int>{};

    // Source 1: questions whose notifications are still in the system tray.
    // Isolated in its own try-catch so a plugin failure (e.g. not yet
    // initialized on cold start) doesn't prevent Source 2 from running.
    try {
      final active = await _plugin.getActiveNotifications();
      final activeIds = active
          .where((n) => n.id != null && n.id != 9999)
          .map((n) => n.id!)
          .toSet();

      if (activeIds.isNotEmpty) {
        final log = await getMirrorLog();
        for (final entry in log) {
          final nid = entry['notif_id'] as int?;
          final qid = entry['id'] as int?;
          if (nid != null && qid != null && activeIds.contains(nid)) {
            qids.add(qid);
          }
        }
      }
    } catch (_) {
      // Source 1 failed (plugin not initialized, etc.). Continue with Source 2.
    }

    // Source 2: past-fired-but-not-answered entries from the mirror log
    // (the only source that survives MIUI/HyperOS notification grouping).
    try {
      qids.addAll(await _firedAndUnansweredQids());
    } catch (_) {}

    return qids.length;
  }

  /// Returns the set of unique question IDs that fired in the past 24 h and
  /// have NOT been marked answered in the mirror log. Used by both the badge
  /// count and the badge-tap routing.
  Future<Set<int>> _firedAndUnansweredQids() async {
    try {
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(hours: 24));

      final log = await getMirrorLog();
      final qids = <int>{};
      for (final entry in log) {
        if (entry['answered_at'] != null) continue;
        final timeStr = entry['time'] as String?;
        final qid = entry['id'] as int?;
        if (timeStr == null || qid == null) continue;
        final scheduled = DateTime.tryParse(timeStr);
        if (scheduled == null) continue;
        if (scheduled.isBefore(now) && scheduled.isAfter(cutoff)) {
          qids.add(qid);
        }
      }
      return qids;
    } catch (_) {
      return <int>{};
    }
  }

  /// Finds the oldest unanswered question ID across both sources:
  /// the active system tray AND past-fired entries in the mirror log
  /// that haven't been answered yet (within the 24 h window).
  ///
  /// Picking from the union — rather than short-circuiting on the tray —
  /// ensures badge taps can reach delayed/grouped questions even while a
  /// fresh notification is still sitting in the tray.
  Future<int?> getOldestUnansweredQuestionId() async {
    try {
      final active = await _plugin.getActiveNotifications();
      final activeIds = active
          .where((n) => n.id != null && n.id != 9999)
          .map((n) => n.id!)
          .toSet();

      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(hours: 24));
      final log = await getMirrorLog();

      // Build per-qid candidates with their scheduled time, deduping across
      // multiple fires of the same question.
      final candidates = <MapEntry<int, DateTime>>[];
      final seenQids = <int>{};

      for (final entry in log) {
        if (entry['answered_at'] != null) continue;
        final qid = entry['id'] as int?;
        final nid = entry['notif_id'] as int?;
        final timeStr = entry['time'] as String?;
        if (qid == null || timeStr == null) continue;
        final scheduled = DateTime.tryParse(timeStr);
        if (scheduled == null) continue;

        final inTray = nid != null && activeIds.contains(nid);
        final isRecentPastFire =
            scheduled.isBefore(now) && scheduled.isAfter(cutoff);

        if (!inTray && !isRecentPastFire) continue;
        if (!seenQids.add(qid)) continue;

        candidates.add(MapEntry(qid, scheduled));
      }

      if (candidates.isEmpty) return null;
      candidates.sort((a, b) => a.value.compareTo(b.value));
      return candidates.first.key;
    } catch (e) {
      return null;
    }
  }

  /// Marks all past, still-unanswered mirror-log entries for [questionId]
  /// as answered. Lets the badge fallback (used on MIUI/HyperOS where the
  /// system tray is empty) stop counting them as "unanswered fires".
  Future<void> _markQuestionAnsweredInMirror(int questionId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('notif_schedule_mirror');
    if (raw == null) return;

    final list = List<Map<String, dynamic>>.from(jsonDecode(raw));
    final now = DateTime.now();
    bool changed = false;

    for (final entry in list) {
      if (entry['id'] != questionId) continue;
      if (entry['answered_at'] != null) continue;
      final timeStr = entry['time'] as String?;
      final scheduled = timeStr != null ? DateTime.tryParse(timeStr) : null;
      if (scheduled == null || !scheduled.isBefore(now)) continue;
      entry['answered_at'] = now.millisecondsSinceEpoch;
      changed = true;
    }

    if (changed) {
      await prefs.setString('notif_schedule_mirror', jsonEncode(list));
    }
  }

  /// Clears any active notifications in the system tray for a specific question.
  Future<void> cancelNotificationsForQuestion(int questionId) async {
    try {
      // Mark this question's past unanswered fires as answered in the mirror
      // log so the MIUI badge fallback decrements correctly.
      await _markQuestionAnsweredInMirror(questionId);

      final active = await _plugin.getActiveNotifications();
      // Do NOT return early when active is empty — on MIUI/HyperOS,
      // getActiveNotifications() always returns [] due to notification grouping,
      // so we must always fire the badge-refresh event regardless.
      if (active.isNotEmpty) {
        final log = await getMirrorLog();
        final activeIds = active.map((n) => n.id).toSet();

        for (final entry in log) {
          if (entry['id'] == questionId) {
            final nId = entry['notif_id'] as int?;
            if (nId != null && activeIds.contains(nId)) {
              debugPrint(
                'NotificationService: Cancelling active notification $nId for question $questionId',
              );
              await _plugin.cancel(id: nId);
            }
          }
        }
      }
      // Always notify listeners — badge must refresh even on MIUI where
      // getActiveNotifications() returns empty and we rely on the time-based fallback.
      _answeredController.add(null);
    } catch (e) {
      debugPrint('NotificationService: Error cancelling notification: $e');
    }
  }

  // ── Fire a single one-time notification (no matchDateTimeComponents) ──────

  Future<void> _scheduleOneTimeNotification({
    required int id,
    required tz.TZDateTime scheduledDate,
    required Question question,
    bool isTest = false,
  }) async {
    final isChallenge = StreakService.instance.isChallengeActive && !isTest;
    final androidDetails = AndroidNotificationDetails(
      'random_recall_channel',
      'Random Recall',
      channelDescription: 'Random quiz reminders',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: isChallenge ? const Color(0xFFFFB300) : null, // amber accent
      // Do NOT set category:alarm here — on Xiaomi HyperOS this routes the
      // notification through the system clock app's group, blocking it.
      // DND bypass is handled by the channel's audioAttributesUsage=alarm.
    );

    // Read localized notification strings from SharedPreferences
    // (set by AppProvider when locale changes)
    final prefs = await SharedPreferences.getInstance();
    final title =
        prefs.getString(isTest ? 'test_notif_title' : 'notif_title') ??
        (isTest ? 'Test Notification 🧪' : 'Time for a quick recall! 🧠');
    final body =
        prefs.getString(isTest ? 'test_notif_body' : 'notif_body') ??
        'Tap to answer the question';

    await _plugin.zonedSchedule(
      id: id,
      title: isChallenge ? '🔥 $title' : title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: NotificationDetails(android: androidDetails),
      // alarmClock is intercepted by Xiaomi HyperOS power management for
      // third-party apps. exactAllowWhileIdle uses setExactAndAllowWhileIdle()
      // which bypasses that interception while still being exact and
      // Doze-exempt. SCHEDULE_EXACT_ALARM permission is already declared.
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: isTest ? 'test:${question.id}' : question.id?.toString(),
    );
  }

  // ── Immediate test notification ───────────────────────────────────────────

  Future<void> sendTestNotification() async {
    // Ensure we have permission before trying to show the notification
    final permission = await hasPermission();
    if (!permission) {
      final granted = await requestPermission();
      if (!granted) throw Exception('Notification permission is required.');
    }

    final question = await DatabaseHelper.instance.getRandomQuestion();
    if (question == null) throw Exception('No questions in DB to test with.');

    const androidDetails = AndroidNotificationDetails(
      'random_recall_channel',
      'Random Recall',
      channelDescription: 'Random quiz reminders',
      importance: Importance.max,
      priority: Priority.max,
      ticker: 'test_ticker',
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    // Use show() for absolute immediate delivery.
    // Read localized notification strings from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final title = prefs.getString('test_notif_title') ?? 'Test Notification 🧪';
    final body =
        prefs.getString('test_notif_body') ?? 'Tap to answer the question';

    await _plugin.show(
      id: 9999,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: androidDetails),
      payload: 'test:${question.id}',
    );
    debugPrint(
      'NotificationService: Immediate test notification fired via show().',
    );
  }

  // ── Cancel all ────────────────────────────────────────────────────────────

  Future<void> cancelAll() async => _plugin.cancelAll();

  // ── Notification tap → navigate to NotificationQuestionScreen ────────────

  void _onNotificationTapped(NotificationResponse response) {
    final navigator = navigatorKey?.currentState;
    if (navigator == null) return;
    final payload = response.payload ?? '';
    // Test notifications have a "test:" prefix — route them to the practice
    // (no-score) screen so they don't pollute the user's score history.
    final isTest = payload.startsWith('test:');
    final questionId = int.tryParse(isTest ? payload.substring(5) : payload);
    // On MIUI/HyperOS this callback can fire twice for a single tap, which
    // would push two question screens. Absorb duplicates for the same question
    // within a 3-second window. Different question IDs always pass through so
    // the user can tap a second tray notification right after the first.
    final now = DateTime.now();
    if (_lastTappedQuestionId == questionId &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!) < const Duration(seconds: 3)) {
      return;
    }
    _lastTappedQuestionId = questionId;
    _lastTapTime = now;
    // Mark as handled so handleNotificationLaunch() doesn't push a second
    // screen for the same tap (double-navigation on MIUI/HyperOS background starts).
    _notificationNavigationHandled = true;
    // Pop everything back to root before pushing the answer screen.
    navigator.popUntil((route) => route.isFirst);
    navigator.pushNamed(
      isTest ? '/question_practice' : '/question',
      arguments: questionId,
    );
  }

  // ── Handle cold-start via notification tap ────────────────────────────────
  // When the app is completely closed and the user taps a notification,
  // onDidReceiveNotificationResponse fires before the navigator is mounted.
  // We must check getNotificationAppLaunchDetails() after the first frame.

  Future<void> handleNotificationLaunch() async {
    if (!_initialized) await init();

    // If _onNotificationTapped already handled this tap (app was in background),
    // skip — otherwise we'd push a duplicate question screen on top.
    if (_notificationNavigationHandled) return;

    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return;

    final payload = details?.notificationResponse?.payload;
    if (payload == null) return;

    // Match the logic in _onNotificationTapped to handle test vs real notifications
    final isTest = payload.startsWith('test:');
    final questionId = int.tryParse(isTest ? payload.substring(5) : payload);

    navigatorKey?.currentState?.pushNamed(
      isTest ? '/question_practice' : '/question',
      arguments: questionId,
    );
  }
}
