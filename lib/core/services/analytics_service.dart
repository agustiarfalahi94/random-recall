import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Thin singleton wrapper around PostHog + Crashlytics identity.
/// All methods are fire-and-forget — callers use `.ignore()` so they never
/// block the UI. Swallows all errors internally so a analytics failure can
/// never surface to the user.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  // ── Identity ──────────────────────────────────────────────────────────────

  /// Call after every successful login (Google or email).
  /// Links all subsequent events to the authenticated user in PostHog, and
  /// sets the Crashlytics user identifier for crash reports.
  Future<void> identify(String userId, {String? email}) async {
    try {
      await Posthog().identify(
        userId: userId,
        userProperties: {
          if (email != null) 'email': email,
        },
      );
    } catch (e) {
      debugPrint('AnalyticsService.identify PostHog error: $e');
    }
    try {
      if (!kDebugMode) {
        await FirebaseCrashlytics.instance.setUserIdentifier(userId);
      }
    } catch (e) {
      debugPrint('AnalyticsService.identify Crashlytics error: $e');
    }
  }

  /// Call on sign-out. Detaches the user from future PostHog events so the
  /// next session starts as a fresh anonymous identity.
  Future<void> reset() async {
    try {
      await Posthog().reset();
    } catch (e) {
      debugPrint('AnalyticsService.reset PostHog error: $e');
    }
    try {
      if (!kDebugMode) {
        await FirebaseCrashlytics.instance.setUserIdentifier('');
      }
    } catch (e) {
      debugPrint('AnalyticsService.reset Crashlytics error: $e');
    }
  }

  // ── Events ────────────────────────────────────────────────────────────────

  Future<void> trackAppOpen() => _capture('app_open');

  Future<void> trackLogin({required String method}) =>
      _capture('login', {'method': method});

  Future<void> trackLogout() => _capture('logout');

  Future<void> trackQuestionAnswered({
    required bool isCorrect,
    required bool fromNotification,
  }) =>
      _capture('question_answered', {
        'correct': isCorrect,
        'source': fromNotification ? 'notification' : 'manual',
      });

  Future<void> trackOnboardingCompleted() => _capture('onboarding_completed');

  Future<void> trackNotificationTapped() => _capture('notification_tapped');

  Future<void> trackQuestionCreated() => _capture('question_created');

  Future<void> trackCategoryCreated() => _capture('category_created');

  Future<void> trackScheduleChanged({
    required int frequency,
    required bool randomAnytime,
    required int timerSeconds,
  }) =>
      _capture('schedule_changed', {
        'frequency': frequency,
        'random_anytime': randomAnytime,
        'timer_seconds': timerSeconds,
      });

  Future<void> _capture(String event,
      [Map<String, Object>? properties]) async {
    try {
      await Posthog().capture(
        eventName: event,
        properties: properties,
      );
    } catch (_) {
      // Never let analytics errors surface to the user.
    }
  }
}
