import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // ── Helpers ───────────────────────────────────────────────────────────────

  static int _hourOfDay() => DateTime.now().hour;
  static int _dayOfWeek() => DateTime.now().weekday; // 1=Mon … 7=Sun

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
      await _analytics.logEvent(
        name: 'app_open_detail',
        parameters: {'hour_of_day': _hourOfDay(), 'day_of_week': _dayOfWeek()},
      );
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
    required int timerSeconds,
    required int timeToAnswerSeconds,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'question_answered',
        parameters: {
          'correct': isCorrect ? 1 : 0,
          'from_notification': fromNotification ? 1 : 0,
          'timer_seconds': timerSeconds,
          'time_to_answer_seconds': timeToAnswerSeconds,
          'hour_of_day': _hourOfDay(),
          'day_of_week': _dayOfWeek(),
        },
      );
    } catch (e) {
      debugPrint('AnalyticsService.trackQuestionAnswered error: $e');
    }
  }

  Future<void> trackOnboardingCompleted({required String authMethod}) async {
    try {
      await _analytics.logEvent(
        name: 'onboarding_completed',
        parameters: {'auth_method': authMethod},
      );
    } catch (e) {
      debugPrint('AnalyticsService.trackOnboardingCompleted error: $e');
    }
  }

  Future<void> trackNotificationTapped() async {
    try {
      await _analytics.logEvent(
        name: 'notification_tapped',
        parameters: {'hour_of_day': _hourOfDay(), 'day_of_week': _dayOfWeek()},
      );
    } catch (e) {
      debugPrint('AnalyticsService.trackNotificationTapped error: $e');
    }
  }

  Future<void> trackQuestionCreated({required int totalQuestions}) async {
    try {
      await _analytics.logEvent(
        name: 'question_created',
        parameters: {'total_questions': totalQuestions},
      );
    } catch (e) {
      debugPrint('AnalyticsService.trackQuestionCreated error: $e');
    }
  }

  Future<void> trackCategoryCreated({required int totalCategories}) async {
    try {
      await _analytics.logEvent(
        name: 'category_created',
        parameters: {'total_categories': totalCategories},
      );
    } catch (e) {
      debugPrint('AnalyticsService.trackCategoryCreated error: $e');
    }
  }

  Future<void> trackScheduleChanged({
    required int frequency,
    required bool randomAnytime,
    required int timerSeconds,
    required int activeDaysCount,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'schedule_changed',
        parameters: {
          'frequency': frequency,
          'random_anytime': randomAnytime ? 1 : 0,
          'timer_seconds': timerSeconds,
          'active_days_count': activeDaysCount,
        },
      );
    } catch (e) {
      debugPrint('AnalyticsService.trackScheduleChanged error: $e');
    }
  }

  Future<void> trackChallengeStarted({
    required int duration,
    required int timerSeconds,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'challenge_started',
        parameters: {'duration_days': duration, 'timer_seconds': timerSeconds},
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

  Future<void> trackChallengeFailed({
    required int dayReached,
    required int durationDays,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'challenge_failed',
        parameters: {'day_reached': dayReached, 'duration_days': durationDays},
      );
    } catch (e) {
      debugPrint('AnalyticsService.trackChallengeFailed error: $e');
    }
  }
}
