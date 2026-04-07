import 'dart:async';
import 'dart:convert';
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
  Completer<void>? _initCompleter;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    debugPrint('NotificationService: Initializing...');

    // Listen for database changes to immediately refresh the 7-day alarm window
    DatabaseHelper.instance.onDatabaseUpdated.listen((_) {
      scheduleNotifications();
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
      debugPrint('NotificationService: Initialization warning: $e');
      // We still mark as initialized if it was a timeout to avoid infinite waiting,
      // but the plugin might not be fully ready.
      _initialized = (e is TimeoutException);
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
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
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
      await android?.requestExactAlarmsPermission();
    }

    return notifGranted;
  }

  /// Returns true if the app currently has notification permission granted.
  Future<bool> hasPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.areNotificationsEnabled() ?? true;
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
    debugPrint('NotificationService: Scheduling notifications...');
    if (!_initialized) {
      await init();
    }

    final prefs = await SharedPreferences.getInstance();

    final randomAnytime = prefs.getBool('notif_random_anytime') ?? true;
    final startHour = prefs.getInt('notif_start_hour') ?? 8;
    final endHour = prefs.getInt('notif_end_hour') ?? 20;
    final frequency = prefs.getInt('notif_frequency') ?? 3;
    final activeDaysStr = prefs.getString('notif_active_days') ?? '1,2,3,4,5,6,7';
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

    // If no slots are calculated (e.g., no active days, or all in past), cancel existing.
    if (slots.isEmpty) return;

    await cancelAll();
    
    // DEBUG: Mirror the schedule to SharedPreferences so we can inspect 
    // the exact scheduled times in a Debug Menu later.
    final debugList = slots.map((s) => {
      'time': s.scheduledAt.toIso8601String(),
      'id': s.questionId,
    }).toList();
    await prefs.setString('notif_schedule_mirror', jsonEncode(debugList));

    // Build a lookup so we don't do N linear scans
    final questionMap = {for (final q in questions) q.id!: q};

    int notifId = 0;
    for (final slot in slots) {
      final question = questionMap[slot.questionId];
      if (question == null) continue;
      if (question.id == null) continue;

      final scheduledDate = tz.TZDateTime.from(slot.scheduledAt, tz.local);

      // Add a tiny delay every 10 items to let the UI thread breathe
      // and avoid saturating the platform channel.
      if (notifId % 5 == 0) {
        await Future.delayed(const Duration(milliseconds: 16));
      }

      // Use a unique notifId for scheduling. Using question.id here would
      // overwrite future alarms for the same question in the 7-day window.
      await _scheduleOneTimeNotification(
        id: notifId,
        scheduledDate: scheduledDate,
        question: question,
      );

      notifId++;
      if (notifId == 1) { // log only the first one
        debugPrint('NotificationService: First upcoming notification at: $scheduledDate');
      }
    }

    debugPrint('NotificationService: Successfully batched $notifId alarms to Android.');
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

  // ── Fire a single one-time notification (no matchDateTimeComponents) ──────

  Future<void> _scheduleOneTimeNotification({
    required int id,
    required tz.TZDateTime scheduledDate,
    required Question question,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'random_recall_channel',
      'Random Recall',
      channelDescription: 'Random quiz reminders',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      // Removed groupKey to prevent Android auto-dismissing multiple notifications.
    );

    await _plugin.zonedSchedule(
      id,
      'Time for a quick recall! 🧠',
      'Tap to reveal the answer ✨',
      scheduledDate,
      const NotificationDetails(android: androidDetails),
      // alarmClock maps to AlarmManager.setAlarmClock() — the same API used
      // by Android's built-in clock app. It is the highest-priority alarm type:
      // it cannot be deferred by Doze, cannot be killed by MIUI/HyperOS battery
      // management, and fires even when the device is in deep sleep.
      // Requires SCHEDULE_EXACT_ALARM (declared in manifest, pre-granted on
      // Android 13+). Shows a small clock icon in the status bar — expected
      // behaviour for alarm-clock level scheduling.
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      // No matchDateTimeComponents → fires once, never repeats
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: question.id?.toString(),
    );
  }

  // ── Immediate test notification ───────────────────────────────────────────

  Future<void> sendTestNotification() async {
    final question = await DatabaseHelper.instance.getRandomQuestion();
    const androidDetails = AndroidNotificationDetails(
      'random_recall_channel',
      'Random Recall',
      channelDescription: 'Random quiz reminders',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );
    // Prefix payload with "test:" so the tap handler can route it to the
    // practice (no-score) flow instead of the normal scored flow.
    await _plugin.show(
      9999,
      'Test Notification 🧪',
      'Tap to reveal the test question ✨',
      const NotificationDetails(android: androidDetails),
      payload: 'test:${question?.id}',
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
