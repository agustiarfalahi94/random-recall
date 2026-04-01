import 'dart:math';

import 'package:flutter/material.dart';
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

  /// Global navigator key — set this in main.dart so we can navigate
  /// from outside the widget tree when a notification is tapped.
  GlobalKey<NavigatorState>? navigatorKey;

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
    final android = _plugin.resolvePlatformSpecificImplementation<
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
    final activeDays = activeDaysStr.split(',').map(int.parse).toList();

    await cancelAll();

    final now = tz.TZDateTime.now(tz.local);
    final random = Random();
    final effectiveStart = randomAnytime ? 0 : startHour;
    final effectiveEnd = randomAnytime ? 23 : endHour;
    final windowHours = (effectiveEnd - effectiveStart).clamp(1, 23);

    for (int i = 0; i < frequency; i++) {
      final randomHour = effectiveStart + random.nextInt(windowHours);
      final randomMinute = random.nextInt(60);

      for (final weekday in activeDays) {
        final notifId = _notifId(weekday, i);
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

        if (scheduledDate.isBefore(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 7));
        }

        await _scheduleNotification(
          id: notifId,
          scheduledDate: scheduledDate,
        );
      }
    }
  }

  // ── Schedule a single notification ────────────────────────────────────────

  Future<void> _scheduleNotification({
    required int id,
    required tz.TZDateTime scheduledDate,
  }) async {
    final question = await DatabaseHelper.instance.getRandomQuestion();
    final title = question?.question ?? 'Time for a quick recall! 🧠';
    final payload = question?.id?.toString();

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
      payload: payload,
    );
  }

  // ── Send an immediate test notification ───────────────────────────────────

  Future<void> sendTestNotification() async {
    final question = await DatabaseHelper.instance.getRandomQuestion();
    final title = question?.question ?? 'This is a test notification! 🧠';
    final payload = question?.id?.toString();

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
      payload: payload,
    );
  }

  // ── Cancel all scheduled notifications ────────────────────────────────────

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ── Notification tap handler ───────────────────────────────────────────────

  void _onNotificationTapped(NotificationResponse response) {
    final navigator = navigatorKey?.currentState;
    if (navigator == null) return;

    // Parse questionId from payload (may be null)
    final questionId = int.tryParse(response.payload ?? '');

    // Navigate to QuestionScreen — import done lazily to avoid circular deps
    navigator.pushNamed('/question', arguments: questionId);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  int _notifId(int weekday, int slotIndex) => weekday * 100 + slotIndex;

  tz.TZDateTime _nextWeekday(tz.TZDateTime from, int weekday) {
    var date = from;
    while (date.weekday != weekday) {
      date = date.add(const Duration(days: 1));
    }
    return date;
  }
}
