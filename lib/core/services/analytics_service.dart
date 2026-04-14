import 'package:posthog_flutter/posthog_flutter.dart';

/// Thin singleton wrapper around PostHog.
/// All methods are fire-and-forget — callers use `.ignore()` so they never
/// block the UI. Swallows all errors internally so a PostHog failure can
/// never surface to the user.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

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
