import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // ── Identity ──────────────────────────────────────────────────────────────

  Future<void> identify(String userId, {String? email}) async {
    try {
      await _analytics.setUserId(id: userId);
      if (!kDebugMode) {
        await FirebaseCrashlytics.instance.setUserIdentifier(userId);
      }
    } catch (e) {
      debugPrint('AnalyticsService.identify error: $e');
    }
  }

  Future<void> reset() async {
    try {
      await _analytics.setUserId(id: null);
      if (!kDebugMode) {
        await FirebaseCrashlytics.instance.setUserIdentifier('');
      }
    } catch (e) {
      debugPrint('AnalyticsService.reset error: $e');
    }
  }

  // ── Events ────────────────────────────────────────────────────────────────

  Future<void> trackAppOpen() async {
    try {
      await _analytics.logAppOpen();
    } catch (e) {
      debugPrint('AnalyticsService.trackAppOpen error: $e');
    }
  }

  Future<void> trackLogin({required String method}) async {
    try {
      await _analytics.logLogin(loginMethod: method);
    } catch (e) {
      debugPrint('AnalyticsService.trackLogin error: $e');
    }
  }

  Future<void> trackLogout() async {
    try {
      await _analytics.logEvent(name: 'logout');
    } catch (e) {
      debugPrint('AnalyticsService.trackLogout error: $e');
    }
  }

  Future<void> trackQuestionAnswered({
    required bool isCorrect,
    required bool fromNotification,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'question_answered',
        parameters: {
          'correct': isCorrect,
          'from_notification': fromNotification,
        },
      );
    } catch (e) {
      debugPrint('AnalyticsService.trackQuestionAnswered error: $e');
    }
  }

  Future<void> trackOnboardingCompleted() async {
    try {
      await _analytics.logEvent(name: 'onboarding_completed');
    } catch (e) {
      debugPrint('AnalyticsService.trackOnboardingCompleted error: $e');
    }
  }

  Future<void> trackNotificationTapped() async {
    try {
      await _analytics.logEvent(name: 'notification_tapped');
    } catch (e) {
      debugPrint('AnalyticsService.trackNotificationTapped error: $e');
    }
  }

  Future<void> trackQuestionCreated() async {
    try {
      await _analytics.logEvent(name: 'question_created');
    } catch (e) {
      debugPrint('AnalyticsService.trackQuestionCreated error: $e');
    }
  }

  Future<void> trackCategoryCreated() async {
    try {
      await _analytics.logEvent(name: 'category_created');
    } catch (e) {
      debugPrint('AnalyticsService.trackCategoryCreated error: $e');
    }
  }

  Future<void> trackScheduleChanged({
    required int frequency,
    required bool randomAnytime,
    required int timerSeconds,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'schedule_changed',
        parameters: {
          'frequency': frequency,
          'random_anytime': randomAnytime,
          'timer_seconds': timerSeconds,
        },
      );
    } catch (e) {
      debugPrint('AnalyticsService.trackScheduleChanged error: $e');
    }
  }

  Future<void> trackChallengeStarted({required int duration}) async {
    try {
      await _analytics.logEvent(
        name: 'challenge_started',
        parameters: {'duration_days': duration},
      );
    } catch (e) {
      debugPrint('AnalyticsService.trackChallengeStarted error: $e');
    }
  }

  Future<void> trackChallengeCompleted({required int duration}) async {
    try {
      await _analytics.logEvent(
        name: 'challenge_completed',
        parameters: {'duration_days': duration},
      );
    } catch (e) {
      debugPrint('AnalyticsService.trackChallengeCompleted error: $e');
    }
  }

  Future<void> trackChallengeFailed({required int dayReached}) async {
    try {
      await _analytics.logEvent(
        name: 'challenge_failed',
        parameters: {'day_reached': dayReached},
      );
    } catch (e) {
      debugPrint('AnalyticsService.trackChallengeFailed error: $e');
    }
  }
}
