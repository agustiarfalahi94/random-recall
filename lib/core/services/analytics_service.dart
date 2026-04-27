import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Thin singleton for Crashlytics identity.
/// Event-tracking methods are retained as no-ops so call sites don't need
/// to change — they simply stop sending to PostHog.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  // ── Identity ──────────────────────────────────────────────────────────────

  Future<void> identify(String userId, {String? email}) async {
    try {
      if (!kDebugMode) {
        await FirebaseCrashlytics.instance.setUserIdentifier(userId);
      }
    } catch (e) {
      debugPrint('AnalyticsService.identify Crashlytics error: $e');
    }
  }

  Future<void> reset() async {
    try {
      if (!kDebugMode) {
        await FirebaseCrashlytics.instance.setUserIdentifier('');
      }
    } catch (e) {
      debugPrint('AnalyticsService.reset Crashlytics error: $e');
    }
  }

  // ── Events (no-ops) ───────────────────────────────────────────────────────

  Future<void> trackAppOpen() async {}
  Future<void> trackLogin({required String method}) async {}
  Future<void> trackLogout() async {}
  Future<void> trackQuestionAnswered({
    required bool isCorrect,
    required bool fromNotification,
  }) async {}
  Future<void> trackOnboardingCompleted() async {}
  Future<void> trackNotificationTapped() async {}
  Future<void> trackQuestionCreated() async {}
  Future<void> trackCategoryCreated() async {}
  Future<void> trackScheduleChanged({
    required int frequency,
    required bool randomAnytime,
    required int timerSeconds,
  }) async {}
}
