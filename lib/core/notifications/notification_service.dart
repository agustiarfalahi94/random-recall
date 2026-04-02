import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../database/database_helper.dart';
import '../../models/question.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  GlobalKey<NavigatorState>? navigatorKey;

  bool _initialized = false;

  static const _groupKey = 'com.randomrecall.questions';

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    // Set the local timezone so notifications fire at the correct local time.
    // Without this, tz.local defaults to UTC and all scheduled times are wrong.
    try {
      final tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {
      // Fallback: keep UTC if timezone detection fails (shouldn't happen in practice)
    }
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    _initialized = true;
  }

  // ── Permission ────────────────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
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

  Future<void> scheduleNotifications() async {
    final prefs = await SharedPreferences.getInstance();

    final randomAnytime = prefs.getBool('notif_random_anytime') ?? true;
    final startHour = prefs.getInt('notif_start_hour') ?? 8;
    final endHour = prefs.getInt('notif_end_hour') ?? 20;
    final frequency = prefs.getInt('notif_frequency') ?? 3;
    final activeDaysStr = prefs.getString('notif_active_days') ?? '1,2,3,4,5';
    final activeDays = activeDaysStr.split(',').map(int.parse).toSet();

    await cancelAll();

    final now = tz.TZDateTime.now(tz.local);
    final db = DatabaseHelper.instance;
    final random = Random();

    final effectiveStart = randomAnytime ? 0 : startHour;
    final effectiveEnd = randomAnytime ? 23 : endHour;

    // Track IDs used across the full 7-day window to minimise week repeats
    final weekUsedIds = <int>{};

    int notifId = 1; // ID 0 reserved for group summary

    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final targetDate = now.add(Duration(days: dayOffset));
      final weekday = targetDate.weekday; // 1=Mon … 7=Sun

      if (!activeDays.contains(weekday)) continue;

      // ── Pick distinct questions for every slot in this day ───────────────
      final dayUsedIds = <int>{};
      final dayQuestions = <Question>[];

      for (int slot = 0; slot < frequency; slot++) {
        // Prefer questions unused this whole week
        Question? q = await db.getRandomQuestion(
          excludeIds: {...weekUsedIds, ...dayUsedIds},
        );
        // Fallback: allow week repeats, but never same day
        q ??= await db.getRandomQuestion(excludeIds: dayUsedIds);
        // Last resort: only 1 question in DB
        q ??= await db.getRandomQuestion();

        if (q != null && q.id != null) {
          dayQuestions.add(q);
          dayUsedIds.add(q.id!);
        }
      }

      weekUsedIds.addAll(dayUsedIds);

      // ── Calculate evenly-spaced slot times with jitter ───────────────────
      final slotHours = _generateSlotHours(
        effectiveStart, effectiveEnd, dayQuestions.length, random,
      );

      // ── Schedule each as a one-time notification ─────────────────────────
      for (int slot = 0; slot < dayQuestions.length; slot++) {
        final hour = slotHours[slot];
        final minute = random.nextInt(60);

        final scheduledDate = tz.TZDateTime(
          tz.local,
          targetDate.year,
          targetDate.month,
          targetDate.day,
          hour,
          minute,
          0,
        );

        // Skip times that have already passed today
        if (scheduledDate.isBefore(now)) continue;

        await _scheduleOneTimeNotification(
          id: notifId++,
          scheduledDate: scheduledDate,
          question: dayQuestions[slot],
        );
      }
    }
  }

  // ── Evenly space `count` slots across [start, end) with small jitter ─────

  List<int> _generateSlotHours(
      int start, int end, int count, Random random) {
    if (count <= 0) return [];
    final window = (end - start).clamp(1, 23);
    final spacing = window / count;
    final hours = <int>[];

    for (int i = 0; i < count; i++) {
      final base = start + (spacing * i).round();
      final maxJitter = (spacing / 2).floor().clamp(0, 2);
      final jitter = maxJitter > 0 ? random.nextInt(maxJitter + 1) : 0;
      hours.add((base + jitter).clamp(start, end - 1));
    }

    return hours;
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
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      groupKey: _groupKey,
    );

    await _plugin.zonedSchedule(
      id,
      question.question,
      'Tap to reveal the answer ✨',
      scheduledDate,
      const NotificationDetails(android: androidDetails),
      // inexact: no special "Alarms & Reminders" permission needed on Android 12+.
      // Can be delayed by up to a few minutes by the OS — perfectly fine for reminders.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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
      groupKey: _groupKey,
    );
    await _plugin.show(
      9999,
      question?.question ?? 'Time for a quick recall! 🧠',
      'Tap to reveal the answer ✨',
      const NotificationDetails(android: androidDetails),
      payload: question?.id?.toString(),
    );
  }

  // ── Cancel all ────────────────────────────────────────────────────────────

  Future<void> cancelAll() async => _plugin.cancelAll();

  // ── Notification tap → navigate to NotificationQuestionScreen ────────────

  void _onNotificationTapped(NotificationResponse response) {
    final navigator = navigatorKey?.currentState;
    if (navigator == null) return;
    final questionId = int.tryParse(response.payload ?? '');
    // Pop everything (sheets, dialogs, sub-screens) back to root first.
    // This prevents the answer screen from revealing an open settings sheet
    // or any other modal when the user closes it.
    navigator.popUntil((route) => route.isFirst);
    navigator.pushNamed('/question', arguments: questionId);
  }

  // ── Handle cold-start via notification tap ────────────────────────────────
  // When the app is completely closed and the user taps a notification,
  // onDidReceiveNotificationResponse fires before the navigator is mounted.
  // We must check getNotificationAppLaunchDetails() after the first frame.

  Future<void> handleNotificationLaunch() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return;
    final payload = details?.notificationResponse?.payload;
    final questionId = int.tryParse(payload ?? '');
    navigatorKey?.currentState?.pushNamed('/question', arguments: questionId);
  }
}
