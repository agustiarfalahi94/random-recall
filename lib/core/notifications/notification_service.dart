import 'package:flutter/material.dart';
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

  static const _groupKey = 'com.randomrecall.questions';

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    // Set the local timezone so notifications fire at the correct local time.
    // Without this, tz.local defaults to UTC and all scheduled times are wrong.
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
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
    final activeDaysStr = prefs.getString('notif_active_days') ?? '1,2,3,4,5,6,7';
    final activeDays = activeDaysStr.split(',').map(int.parse).toSet();

    // Fetch all questions once; the scheduler picks from them.
    final questions = await DatabaseHelper.instance.getAllQuestions();
    if (questions.isEmpty) return;

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
      now: DateTime.now(),
      questionIds: questionIds,
    );

    await cancelAll();

    // Build a lookup so we don't do N linear scans
    final questionMap = {for (final q in questions) q.id!: q};

    int notifId = 1; // ID 0 reserved for group summary
    for (final slot in slots) {
      final question = questionMap[slot.questionId];
      if (question == null) continue;

      final scheduledDate = tz.TZDateTime(
        tz.local,
        slot.scheduledAt.year,
        slot.scheduledAt.month,
        slot.scheduledAt.day,
        slot.scheduledAt.hour,
        slot.scheduledAt.minute,
        0,
      );

      await _scheduleOneTimeNotification(
        id: notifId++,
        scheduledDate: scheduledDate,
        question: question,
      );
    }
  }

  /// Returns the number of currently pending (not-yet-fired) notifications.
  Future<int> pendingCount() async {
    final list = await _plugin.pendingNotificationRequests();
    return list.length;
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
    // Prefix payload with "test:" so the tap handler can route it to the
    // practice (no-score) flow instead of the normal scored flow.
    await _plugin.show(
      9999,
      question?.question ?? 'Time for a quick recall! 🧠',
      'Tap to reveal the answer ✨',
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
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return;
    final payload = details?.notificationResponse?.payload;
    final questionId = int.tryParse(payload ?? '');
    navigatorKey?.currentState?.pushNamed('/question', arguments: questionId);
  }
}
