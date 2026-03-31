import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../database/database_helper.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ── Initialise once at app startup ────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  // ── Permission request (Android 13+) ──────────────────────────────────────

  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? false;
  }

  // ── Schedule all daily notifications based on saved prefs ─────────────────

  Future<void> scheduleNotifications() async {
    final prefs = await SharedPreferences.getInstance();

    final randomAnytime = prefs.getBool('notif_random_anytime') ?? true;
    final startHour = prefs.getInt('notif_start_hour') ?? 8;
    final endHour = prefs.getInt('notif_end_hour') ?? 20;
    final frequency = prefs.getInt('notif_frequency') ?? 3;
    final activeDaysStr = prefs.getString('notif_active_days') ?? '1,2,3,4,5';
    final activeDays =
        activeDaysStr.split(',').map(int.parse).toList();

    // Cancel existing before rescheduling
    await cancelAll();

    final now = tz.TZDateTime.now(tz.local);

    // Generate 'frequency' random times within the allowed window
    final random = Random();
    final effectiveStart = randomAnytime ? 0 : startHour;
    final effectiveEnd = randomAnytime ? 23 : endHour;
    final windowHours =
        (effectiveEnd - effectiveStart).clamp(1, 23);

    for (int i = 0; i < frequency; i++) {
      // Pick a random hour within the window
      final randomHour =
          effectiveStart + random.nextInt(windowHours);
      final randomMinute = random.nextInt(60);

      // Schedule for each active day of the week
      for (final weekday in activeDays) {
        final notifId = _notifId(weekday, i);

        // Find the next occurrence of this weekday
        final base = _nextWeekday(now, weekday);
        var scheduledDate = tz.TZDateTime(
          tz.local,
          base.year,
          base.month,
          base.day,
          randomHour,
          randomMinute,
          0,
        );

        // If it's already passed today, push to next week
        if (scheduledDate.isBefore(now)) {
          scheduledDate =
              scheduledDate.add(const Duration(days: 7));
        }

        await _scheduleNotification(
          id: notifId,
          scheduledDate: scheduledDate,
          weekday: weekday,
          slotIndex: i,
        );
      }
    }
  }

  // ── Schedule a single notification ────────────────────────────────────────

  Future<void> _scheduleNotification({
    required int id,
    required tz.TZDateTime scheduledDate,
    required int weekday,
    required int slotIndex,
  }) async {
    // Pick a random question for the title
    final question =
        await DatabaseHelper.instance.getRandomQuestion();
    final title = question?.question ?? 'Time for a quick recall! 🧠';

    const androidDetails = AndroidNotificationDetails(
      'random_recall_channel',
      'Random Recall',
      channelDescription: 'Random quiz reminders',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id,
      title,
      'Tap to reveal the answer ✨',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ── Send an immediate test notification ───────────────────────────────────

  Future<void> sendTestNotification() async {
    final question = await DatabaseHelper.instance.getRandomQuestion();
    final title = question?.question ?? 'This is a test notification! 🧠';

    const androidDetails = AndroidNotificationDetails(
      'random_recall_channel',
      'Random Recall',
      channelDescription: 'Random quiz reminders',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      9999,
      title,
      'Tap to reveal the answer ✨',
      details,
    );
  }

  // ── Cancel all scheduled notifications ────────────────────────────────────

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ── Notification tap handler ───────────────────────────────────────────────

  void _onNotificationTapped(NotificationResponse response) {
    // Navigation is handled in main.dart via navigatorKey
    // The payload can be used later to pass questionId
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Generate a stable unique notification ID from weekday + slot.
  int _notifId(int weekday, int slotIndex) => weekday * 100 + slotIndex;

  /// Returns the next [tz.TZDateTime] that falls on the given ISO weekday
  /// (1 = Monday … 7 = Sunday).
  tz.TZDateTime _nextWeekday(tz.TZDateTime from, int weekday) {
    var date = from;
    while (date.weekday != weekday) {
      date = date.add(const Duration(days: 1));
    }
    return date;
  }
}
