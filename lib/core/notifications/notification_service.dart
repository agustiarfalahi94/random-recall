import 'dart:async';
import 'dart:convert';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../database/database_helper.dart';
import '../../models/question.dart';
import 'notification_scheduler.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  GlobalKey<NavigatorState>? navigatorKey;

  bool _initialized = false;
  bool _isScheduling = false;
  Completer<void>? _initCompleter;
  Timer? _scheduleDebounceTimer;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    debugPrint('NotificationService: Initializing...');

    // Listen for database changes to refresh the schedule.
    // We debounce this to avoid rapid re-scheduling during sync/practice.
    DatabaseHelper.instance.onDatabaseUpdated.listen((_) {
      if (_scheduleDebounceTimer?.isActive ?? false) _scheduleDebounceTimer!.cancel();
      _scheduleDebounceTimer = Timer(const Duration(seconds: 5), () async {
        final prefs = await SharedPreferences.getInstance();
        final lastCount = prefs.getInt('last_known_question_count') ?? 0;
        final currentCount = await DatabaseHelper.instance.getQuestionCount();
        
        if (currentCount != lastCount) {
          await prefs.setInt('last_known_question_count', currentCount);
          scheduleNotifications();
        }
      });
    });

    if (_initCompleter != null) return _initCompleter!.future;
    // If init is already in progress, return its future to avoid re-entering.
    // This is crucial to prevent multiple initializations if called concurrently.
    if (_initCompleter != null && !_initCompleter!.isCompleted) return _initCompleter!.future;

    final completer = Completer<void>();
    _initCompleter = completer;

    try {
      // Wrap in a defensive timeout. If the native side hangs (common on MIUI/HyperOS),
      // we complete the future anyway so the app can continue.
      await _actualInit().timeout(const Duration(seconds: 4));
      _initialized = true; // Mark as initialized only if _actualInit completes successfully
    } catch (e) {
      debugPrint('NotificationService: Initialization error: $e');
      // We still mark as initialized if it was a timeout to avoid infinite waiting,
      // but the plugin might not be fully ready.
      _initialized = false;
    } finally {
      if (!completer.isCompleted) {
        debugPrint('NotificationService: Init completer completed.');
        completer.complete();
      }
    }
  }

  Future<void> _actualInit() async {
    tz.initializeTimeZones();
    try {
      debugPrint('NotificationService: Setting local timezone...');
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timezoneInfo.identifier;
      debugPrint('NotificationService: Detected device timezone: $timeZoneName');
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('NotificationService: Timezone detection failed: $e');
      tz.setLocalLocation(tz.UTC);
    }
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    debugPrint('NotificationService: Initializing plugin...');
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
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
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final prefs = await SharedPreferences.getInstance();
    const migrationKey = 'notif_channel_v2_migrated';
    final alreadyMigrated = prefs.getBool(migrationKey) ?? false;

    if (!alreadyMigrated) {
      // First run on this build: delete the legacy channel (if any) and
      // recreate it with the alarm audio attributes. This wipes the tray once,
      // which is acceptable on a one-time migration.
      await androidPlugin?.deleteNotificationChannel('random_recall_channel');
      debugPrint('NotificationService: Legacy channel deleted (one-time migration).');
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
      debugPrint('NotificationService: Channel recreated with alarm audio attributes (migrated).');
    } else {
      debugPrint('NotificationService: Channel already migrated, preserving tray.');
    }
  }

  // ── Permission ────────────────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    debugPrint('NotificationService: Requesting notification permissions...');
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Request POST_NOTIFICATIONS (Android 13+).
    final notifGranted =
        await android?.requestNotificationsPermission() ?? false;
    debugPrint('NotificationService: Notifications permission granted: $notifGranted');

    // Request SCHEDULE_EXACT_ALARM if not already granted.
    // On Android 13+ this is pre-granted at install — the call is a no-op.
    // On Android 12 it opens the "Alarms & Reminders" system settings page.
    // Note: We use inexactAllowWhileIdle by default, but still check for exact
    // permission for alarmClock mode, which is more reliable.
    final canExact =
        await android?.canScheduleExactNotifications() ?? true;
    debugPrint('NotificationService: Exact alarm permission granted: $canExact');
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
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
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
      // Corrupted if: window is inverted, too narrow (<1h), or suspiciously
      // in the middle of the night (both hours before 4am).
      if (endHour - startHour < 1 || (startHour < 4 && endHour < 4)) {
        debugPrint('NotificationService: Corrupted time window ($startHour–$endHour). Resetting to 8–20.');
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
      debugPrint('NotificationService: Scheduling already in progress, skipping.');
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
    // Ensure we are initialized and have a valid non-UTC timezone if possible
    if (!_initialized) await init();
    
    if (tz.local == tz.UTC) {
      debugPrint('NotificationService: Timezone not ready. Aborting schedule to prevent UTC shift.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Force refresh to catch recent UI changes
    _sanitizeNotificationPrefs(prefs);

    final randomAnytime = prefs.getBool('notif_random_anytime') ?? true;
    final startHour = prefs.getInt('notif_start_hour') ?? 8;
    final endHour = prefs.getInt('notif_end_hour') ?? 20;
    final frequency = prefs.getInt('notif_frequency') ?? 3;
    final activeDaysStr = prefs.getString('notif_active_days') ?? '1,2,3,4,5,6,7';

    debugPrint('NotificationService: Settings used: randomAnytime=$randomAnytime, '
        'startHour=$startHour, endHour=$endHour, frequency=$frequency, '
        'activeDays=$activeDaysStr');
    final activeDays = activeDaysStr.split(',').map(int.parse).toSet();

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
    debugPrint('NotificationService: Calculated ${slots.length} notification slots for the next 7 days.');

    if (slots.isEmpty) return;

    // 1. Generate stable IDs and mirror log for the debug menu & tray matching
    // Stable ID = days-since-epoch * 20 + slotIndex. Unique across the entire
    // 8-day schedule window AND deterministic across reschedules (no week-collision).
    int idForSlot(tz.TZDateTime when, int slotIndex) {
      final daysSinceEpoch = when.toUtc().millisecondsSinceEpoch ~/ 86400000;
      return (daysSinceEpoch * 20) + slotIndex;
    }

    final futureList = slots.map((s) {
      return {
        'time': s.scheduledAt.toIso8601String(),
        'id': s.questionId, // Renamed back to 'id' for DebugNotificationScreen compatibility
        'notif_id': idForSlot(s.scheduledAt, s.slotIndex),
      };
    }).toList();

    // Preserve already-delivered entries that are still in the tray. Without
    // this, the mirror log would lose past slots and the home-screen unanswered
    // lookup (getOldestUnansweredQuestionId) would fail to map active tray
    // notifications back to their question IDs after a reschedule.
    final preservedDelivered = <Map<String, dynamic>>[];
    try {
      final activeNow = await _plugin.getActiveNotifications();
      final activeIds = activeNow.map((n) => n.id).whereType<int>().toSet();
      final oldRaw = prefs.getString('notif_schedule_mirror');
      if (oldRaw != null && activeIds.isNotEmpty) {
        final oldList = List<Map<String, dynamic>>.from(jsonDecode(oldRaw));
        final newNotifIds = futureList
            .map((e) => e['notif_id'] as int?)
            .whereType<int>()
            .toSet();
        for (final entry in oldList) {
          final nid = entry['notif_id'] as int?;
          if (nid != null &&
              activeIds.contains(nid) &&
              !newNotifIds.contains(nid)) {
            preservedDelivered.add(entry);
          }
        }
      }
    } catch (e) {
      debugPrint('NotificationService: Could not preserve delivered mirror entries: $e');
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

      if (i == 0) { // log only the first one
        debugPrint('NotificationService: First upcoming notification at: $scheduledDate');
      }
    }

    debugPrint('NotificationService: Successfully batched ${slots.length} alarms to Android.');
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

  /// Calculates how many notifications have fired since the user's last answer.
  ///
  /// Counts unique question IDs by intersecting active tray notifications with
  /// the mirror log. This filters out phantom system entries (e.g. MIUI group
  /// summaries) that would otherwise inflate the count by +1.
  Future<int> getUnansweredCount() async {
    try {
      final active = await _plugin.getActiveNotifications();
      if (active.isEmpty) return 0;

      final activeIds = active
          .where((n) => n.id != null && n.id != 9999)
          .map((n) => n.id!)
          .toSet();
      if (activeIds.isEmpty) return 0;

      final log = await getMirrorLog();
      final matchedQuestionIds = <int>{};
      for (final entry in log) {
        final nid = entry['notif_id'] as int?;
        final qid = entry['id'] as int?;
        if (nid != null && qid != null && activeIds.contains(nid)) {
          matchedQuestionIds.add(qid);
        }
      }
      return matchedQuestionIds.length;
    } catch (e) {
      return 0;
    }
  }

  /// Finds the oldest question ID that was notified but not yet answered.
  Future<int?> getOldestUnansweredQuestionId() async {
    final active = await _plugin.getActiveNotifications();
    if (active.isEmpty) return null;

    // Get the IDs currently in the tray (excluding test)
    final activeIds = active.where((n) => n.id != 9999).map((n) => n.id).toSet();
    if (activeIds.isEmpty) return null;

    final log = await getMirrorLog();
    
    // Find the first log entry that matches an ID currently in the tray
    for (final entry in log) {
      final logNotifId = entry['notif_id'] as int?;
      if (activeIds.contains(logNotifId)) {
        return entry['id'] as int?;
      }
    }
    return null;
  }

  /// Clears any active notifications in the system tray for a specific question.
  Future<void> cancelNotificationsForQuestion(int questionId) async {
    try {
      final active = await _plugin.getActiveNotifications();
      if (active.isEmpty) return;

      final log = await getMirrorLog();
      final activeIds = active.map((n) => n.id).toSet();

      for (final entry in log) {
        if (entry['id'] == questionId) {
          final nId = entry['notif_id'] as int?;
          if (nId != null && activeIds.contains(nId)) {
            debugPrint('NotificationService: Cancelling active notification $nId for question $questionId');
            await _plugin.cancel(nId);
          }
        }
      }
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
    const androidDetails = AndroidNotificationDetails(
      'random_recall_channel',
      'Random Recall',
      channelDescription: 'Random quiz reminders',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      // Do NOT set category:alarm here — on Xiaomi HyperOS this routes the
      // notification through the system clock app's group, blocking it.
      // DND bypass is handled by the channel's audioAttributesUsage=alarm.
    );

    await _plugin.zonedSchedule(
      id,
      isTest ? 'Test Notification 🧪' : 'Time for a quick recall! 🧠',
      isTest ? 'Tap to reveal the test question ✨' : 'Tap to reveal the answer ✨',
      scheduledDate,
      const NotificationDetails(android: androidDetails),
      // alarmClock is intercepted by Xiaomi HyperOS power management for
      // third-party apps. exactAllowWhileIdle uses setExactAndAllowWhileIdle()
      // which bypasses that interception while still being exact and
      // Doze-exempt. SCHEDULE_EXACT_ALARM permission is already declared.
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
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
    await _plugin.show(
      9999,
      'Test Notification 🧪',
      'Tap to reveal the test question ✨',
      const NotificationDetails(android: androidDetails),
      payload: 'test:${question.id}',
    );
    debugPrint('NotificationService: Immediate test notification fired via show().');
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
    // Pop everything back to root before pushing the answer screen.
    navigator.popUntil((route) => route.isFirst);
    navigator.pushNamed(isTest ? '/question_practice' : '/question',
        arguments: questionId);
  }

  // ── Handle cold-start via notification tap ────────────────────────────────
  // When the app is completely closed and the user taps a notification,
  // onDidReceiveNotificationResponse fires before the navigator is mounted.
  // We must check getNotificationAppLaunchDetails() after the first frame.

  Future<void> handleNotificationLaunch() async {
    if (!_initialized) await init();

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
