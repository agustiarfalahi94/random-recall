import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/analytics_service.dart';
import '../utils/date_utils.dart' as date_utils;

/// Tracks the user's timer-challenge streak.
///
/// Rules:
/// - Streak only increments when a question is answered with the timer ON.
/// - Answering at least once per calendar day with timer on counts as that day.
/// - Missing a day resets the streak to 1 (the current day).
/// - Every 7-day streak milestone grants +1 bonus question for free-tier users.
class StreakService {

  /// Maximum timer setting that qualifies for the streak challenge.
  /// Challenge Mode only counts for 5-10 second timers.
  /// Timers above 10s (e.g. 15s, 20s, 90s) are too relaxed to earn a streak —
  /// the user must genuinely recall the answer under pressure.
  static const int challengeThreshold = 10; // seconds

  static const _keyStreak = 'timer_streak_days';
  static const _keyLastDate = 'timer_streak_last_date';
  static const _keyBonusQuestions = 'timer_streak_bonus_questions';

  // Challenge mode state constants
  static const _keyChallengeModeActive = 'challenge_mode_active';
  static const _keyChallengeModeStartDate = 'challenge_mode_start_date';
  static const _keyChallengeModeDay = 'challenge_mode_day';
  static const _keyChallengeDuration = 'challenge_duration'; // 7 or 14
  static const _keyChallengeLockedFrequency = 'challenge_locked_frequency';
  static const _keyChallengeLockedActiveDays = 'challenge_locked_active_days'; // csv, e.g. 1,2,3,4,5,6,7
  static const _keyChallengeLockedRandomAnytime = 'challenge_locked_random_anytime'; // bool
  static const _keyChallengeLockedTimerSeconds = 'challenge_locked_timer_seconds'; // int
  static const _keyChallengeLastAnswerDate = 'challenge_last_answer_date';
  static const _keyTotal7DayCompleted = 'total_7day_completed';
  static const _keyTotal14DayCompleted = 'total_14day_completed';
  static const _keyChallengeBadgeUnlocked = 'challenge_badge_unlocked';
  static const _keyHighestTitle = 'highest_title'; // Challenger, Champion, Legend
  static const _keyBonusCategories = 'bonus_categories'; // free-tier only

  // Reward constants
  static const int questionsMax = 200;
  static const int categoriesMax = 20;
  static const int questionBase = 20;
  static const int categoryBase = 4;

  // ── Singleton instance ──────────────────────────────────────────────────────
  static final StreakService _instance = StreakService._internal();

  factory StreakService() {
    return _instance;
  }

  static StreakService get instance => _instance;

  StreakService._internal();

  late SharedPreferences _prefs;

  /// Set up local SharedPreferences cache. Safe to call before auth.
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Sync streak/challenge state from Firestore. Must only be called after
  /// the user is authenticated (i.e. from initializeUserSession).
  Future<void> loadFromCloud() async {
    await _loadFromFirestore();
  }

  // Test helper: expose _prefs for testing purposes
  @visibleForTesting
  SharedPreferences get prefsForTesting => _prefs;

  // ── Instance getters for challenge mode ─────────────────────────────────────

  bool get isChallengeActive => _prefs.getBool(_keyChallengeModeActive) ?? false;
  int get challengeDay => _prefs.getInt(_keyChallengeModeDay) ?? 0;
  int get challengeDuration => _prefs.getInt(_keyChallengeDuration) ?? 7;
  int get lockedFrequency => _prefs.getInt(_keyChallengeLockedFrequency) ?? 0;
  String? get lockedActiveDaysCsv => _prefs.getString(_keyChallengeLockedActiveDays);
  bool? get lockedRandomAnytime => _prefs.getBool(_keyChallengeLockedRandomAnytime);
  int get lockedTimerSeconds => _prefs.getInt(_keyChallengeLockedTimerSeconds) ?? 5;
  int get total7DayCompleted => _prefs.getInt(_keyTotal7DayCompleted) ?? 0;
  int get total14DayCompleted => _prefs.getInt(_keyTotal14DayCompleted) ?? 0;
  bool get challengeBadgeUnlocked =>
      _prefs.getBool(_keyChallengeBadgeUnlocked) ?? false;
  String get highestTitle => _prefs.getString(_keyHighestTitle) ?? '';
  int get bonusCategories => _prefs.getInt(_keyBonusCategories) ?? 0;
  int get bonusQuestions => _prefs.getInt(_keyBonusQuestions) ?? 0;
  int get currentStreak => _prefs.getInt(_keyStreak) ?? 0;

  // ── Challenge mode setter methods ───────────────────────────────────────────

  Future<void> startChallenge(
    int duration,
    int frequency, {
    String? lockedActiveDaysCsv,
    bool? lockedRandomAnytime,
    int timerSeconds = 5,
  }) async {
    await _prefs.setBool(_keyChallengeModeActive, true);
    await _prefs.setInt(_keyChallengeDuration, duration);
    await _prefs.setInt(_keyChallengeModeDay, 1);
    await _prefs.setInt(_keyChallengeLockedFrequency, frequency);
    await _prefs.setInt(_keyChallengeLockedTimerSeconds, timerSeconds);
    if (lockedActiveDaysCsv != null) {
      await _prefs.setString(_keyChallengeLockedActiveDays, lockedActiveDaysCsv);
    }
    if (lockedRandomAnytime != null) {
      await _prefs.setBool(_keyChallengeLockedRandomAnytime, lockedRandomAnytime);
    }
    await _prefs.setString(_keyChallengeModeStartDate, DateTime.now().toIso8601String());
    await _saveToFirestore();
    AnalyticsService.instance.trackChallengeStarted(
      duration: duration,
      timerSeconds: timerSeconds,
    ).ignore();
  }

  Future<void> incrementChallengeDay() async {
    final newDay = challengeDay + 1;
    await _prefs.setInt(_keyChallengeModeDay, newDay);
    await _prefs.setString(_keyChallengeLastAnswerDate, DateTime.now().toIso8601String());
    await _saveToFirestore();
  }

  Future<void> resetChallenge() async {
    await _prefs.remove(_keyChallengeModeActive);
    await _prefs.remove(_keyChallengeModeDay);
    await _prefs.remove(_keyChallengeDuration);
    await _prefs.remove(_keyChallengeLockedFrequency);
    await _prefs.remove(_keyChallengeLockedActiveDays);
    await _prefs.remove(_keyChallengeLockedRandomAnytime);
    await _prefs.remove(_keyChallengeModeStartDate);
    await _prefs.remove(_keyChallengeLastAnswerDate);
    // Reset current streak
    await _prefs.setInt(_keyStreak, 0);
    await _saveToFirestore();
  }

  Future<ChallengeCompletion> completeChallengeMode(
    int duration, {
    required bool isPremiumUser,
  }) async {
    // Challenge completed successfully
    int questionsEarned = 0;
    int categoriesEarned = 0;
    bool badgeUnlocked = false;
    String title = '';

    if (duration == 7) {
      await _prefs.setInt(_keyTotal7DayCompleted, total7DayCompleted + 1);
      if (!isPremiumUser) {
        // Award bonus question (free-tier)
        questionsEarned = 1;
        final newQuestions = bonusQuestions + 1;
        await _prefs.setInt(
          _keyBonusQuestions,
          min(newQuestions, questionsMax - questionBase),
        );
      }
    } else if (duration == 14) {
      await _prefs.setInt(_keyTotal14DayCompleted, total14DayCompleted + 1);
      if (!isPremiumUser) {
        // Award bonus question + category (free-tier)
        questionsEarned = 1;
        categoriesEarned = 1;
        final newQuestions = bonusQuestions + 1;
        final newCategories = bonusCategories + 1;
        await _prefs.setInt(
          _keyBonusQuestions,
          min(newQuestions, questionsMax - questionBase),
        );
        await _prefs.setInt(
          _keyBonusCategories,
          min(newCategories, categoriesMax - categoryBase),
        );
      }
    }

    if (isPremiumUser) {
      // Cosmetic rewards (premium)
      badgeUnlocked = true;
      await _prefs.setBool(_keyChallengeBadgeUnlocked, true);

      final totalCompleted = total7DayCompleted + total14DayCompleted + 1;
      // Simple progression: 1+ = Challenger, 3+ = Champion, 7+ = Legend
      if (totalCompleted >= 7) {
        title = 'Legend';
      } else if (totalCompleted >= 3) {
        title = 'Champion';
      } else {
        title = 'Challenger';
      }
      await _prefs.setString(_keyHighestTitle, title);
    }

    await resetChallenge(); // resetChallenge() calls _saveToFirestore()
    AnalyticsService.instance.trackChallengeCompleted(duration: duration).ignore();

    return ChallengeCompletion(
      duration: duration,
      questionsEarned: questionsEarned,
      categoriesEarned: categoriesEarned,
      badgeUnlocked: badgeUnlocked,
      title: title,
    );
  }

  Future<void> unlockChallengeBadge() async {
    await _prefs.setBool(_keyChallengeBadgeUnlocked, true);
    await _saveToFirestore();
  }

  Future<void> setHighestTitle(String title) async {
    // title: 'Challenger', 'Champion', 'Legend'
    await _prefs.setString(_keyHighestTitle, title);
    await _saveToFirestore();
  }

  Future<void> failChallenge() async {
    if (isChallengeActive) {
      final dayReached = challengeDay;
      final durationDays = challengeDuration; // capture before resetChallenge() removes the key
      await resetChallenge(); // resets streak to 0 and calls _saveToFirestore() internally
      AnalyticsService.instance.trackChallengeFailed(
        dayReached: dayReached,
        durationDays: durationDays,
      ).ignore();
    }
  }

  Future<void> checkChallengeDailyRequirement() async {
    if (!isChallengeActive) return;

    final lastAnswerDateStr = _prefs.getString(_keyChallengeLastAnswerDate);
    if (lastAnswerDateStr == null) return;

    final now = DateTime.now();
    final lastAnswerKey = lastAnswerDateStr.substring(0, 10); // 'yyyy-MM-dd'
    final yesterdayKey = _dateKey(now.subtract(const Duration(days: 1)));

    // Fail if the last answer was before yesterday (missed a calendar day).
    // Using date strings avoids the 24h-period pitfall of .difference().inDays.
    if (lastAnswerKey.compareTo(yesterdayKey) < 0) {
      await failChallenge();
    }
  }

  /// Called whenever the user answers a question during an active challenge.
  ///
  /// - Wrong answer => immediate failure + reset.
  /// - Correct answer => counts once per calendar day.
  /// - Completion => returns a [ChallengeCompletion] snapshot.
  Future<ChallengeAnswerResult> recordChallengeAnswer({
    required bool isCorrect,
    required bool isPremiumUser,
  }) async {
    if (!isChallengeActive) {
      return const ChallengeAnswerResult(outcome: ChallengeAnswerOutcome.noChallenge);
    }

    if (!isCorrect) {
      await failChallenge();
      return const ChallengeAnswerResult(outcome: ChallengeAnswerOutcome.failed);
    }

    final now = DateTime.now();
    final todayKey = _dateKey(now);
    final lastAnswerDateStr = _prefs.getString(_keyChallengeLastAnswerDate);

    // First ever correct answer in this challenge: mark today as done, keep day=1.
    if (lastAnswerDateStr == null) {
      await _prefs.setString(_keyChallengeLastAnswerDate, now.toIso8601String());
      await _saveToFirestore();
      return const ChallengeAnswerResult(outcome: ChallengeAnswerOutcome.progressed);
    }

    final lastKey = _dateKey(DateTime.parse(lastAnswerDateStr));
    if (lastKey == todayKey) {
      return const ChallengeAnswerResult(
        outcome: ChallengeAnswerOutcome.alreadyCompletedToday,
      );
    }

    // If we reached the final day and get a new-day correct answer, complete.
    if (challengeDay >= challengeDuration) {
      final completion = await completeChallengeMode(
        challengeDuration,
        isPremiumUser: isPremiumUser,
      );
      return ChallengeAnswerResult(
        outcome: ChallengeAnswerOutcome.completed,
        completion: completion,
      );
    }

    await incrementChallengeDay();
    return const ChallengeAnswerResult(outcome: ChallengeAnswerOutcome.progressed);
  }

  // ── Firestore persistence ───────────────────────────────────────────────────

  Future<void> _saveToFirestore() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('private')
          .doc('streakData')
          .set(
            {
              'challenge': {
                'active': isChallengeActive,
                'day': challengeDay,
                'duration': challengeDuration,
                'locked_frequency': lockedFrequency,
                'locked_active_days': lockedActiveDaysCsv,
                'locked_random_anytime': lockedRandomAnytime,
                'locked_timer_seconds': lockedTimerSeconds,
                'start_date': _prefs.getString(_keyChallengeModeStartDate),
                'last_answer_date': _prefs.getString(_keyChallengeLastAnswerDate),
              },
              'streak': {
                'total_7day_completed': total7DayCompleted,
                'total_14day_completed': total14DayCompleted,
              },
              'rewards': {
                'bonus_questions': bonusQuestions,
                'bonus_categories': bonusCategories,
                'challenge_badge_unlocked': challengeBadgeUnlocked,
                'highest_title': highestTitle,
              },
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
    } catch (e) {
      debugPrint('Error saving streak data to Firestore: $e');
    }
  }

  Future<void> _loadFromFirestore() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('private')
          .doc('streakData')
          .get();

      if (doc.exists) {
        final data = doc.data()!;

        // Restore challenge data
        if (data['challenge'] != null) {
          final challenge = data['challenge'];
          final active = challenge['active'] ?? false;
          final freq = challenge['locked_frequency'] ?? 0;
          final daysCsv = challenge['locked_active_days'] as String?;
          final anytime = challenge['locked_random_anytime'] as bool?;
          final timer = challenge['locked_timer_seconds'] ?? 5;

          await _prefs.setBool(_keyChallengeModeActive, active);
          await _prefs.setInt(_keyChallengeModeDay, challenge['day'] ?? 0);
          await _prefs.setInt(_keyChallengeDuration, challenge['duration'] ?? 7);
          await _prefs.setInt(_keyChallengeLockedFrequency, freq);
          await _prefs.setInt(_keyChallengeLockedTimerSeconds, timer);
          if (daysCsv != null) await _prefs.setString(_keyChallengeLockedActiveDays, daysCsv);
          if (anytime != null) await _prefs.setBool(_keyChallengeLockedRandomAnytime, anytime);
          if (challenge['start_date'] != null) {
            await _prefs.setString(_keyChallengeModeStartDate, challenge['start_date']);
          }
          if (challenge['last_answer_date'] != null) {
            await _prefs.setString(_keyChallengeLastAnswerDate, challenge['last_answer_date']);
          }

          // Re-apply locked notification settings to SharedPreferences so
          // notifications can be rescheduled correctly after a fresh install.
          if (active && freq > 0) {
            await _prefs.setInt('notif_frequency', freq);
            await _prefs.setInt('notif_timer_seconds', timer);
            if (daysCsv != null) await _prefs.setString('notif_active_days', daysCsv);
            if (anytime != null) await _prefs.setBool('notif_random_anytime', anytime);
          }
        }

        // Restore rewards data
        if (data['rewards'] != null) {
          final rewards = data['rewards'];
          // Restore both question and category bonuses
          await _prefs.setInt(_keyBonusQuestions, rewards['bonus_questions'] ?? 0);
          await _prefs.setInt(_keyBonusCategories, rewards['bonus_categories'] ?? 0);
          await _prefs.setBool(_keyChallengeBadgeUnlocked, rewards['challenge_badge_unlocked'] ?? false);
          if (rewards['highest_title'] != null) {
            await _prefs.setString(_keyHighestTitle, rewards['highest_title']);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading streak data from Firestore: $e');
    }
  }

  // ── Getters ────────────────────────────────────────────────────────────────

  // These use the singleton's cached _prefs to stay consistent with instance
  // getters and avoid creating a second SharedPreferences handle.
  // NOTE: These will throw LateInitializationError if called before initialize().
  // In practice, initialize() is always awaited before any UI renders, but callers
  // in background isolates must call initialize() themselves first.
  static int getStreak() {
    final prefs = _instance._prefs;
    final lastDate = prefs.getString(_keyLastDate) ?? '';
    final today = _dateKey(DateTime.now());
    final yesterday = _dateKey(DateTime.now().subtract(const Duration(days: 1)));
    if (lastDate != today && lastDate != yesterday) return 0;
    return prefs.getInt(_keyStreak) ?? 0;
  }

  static int getBonusQuestions() {
    return _instance._prefs.getInt(_keyBonusQuestions) ?? 0;
  }

  // ── Total question limit for free tier ────────────────────────────────────

  static int getFreeQuestionLimit() {
    return questionBase + getBonusQuestions();
  }

  // ── Helper ─────────────────────────────────────────────────────────────────

  static String _dateKey(DateTime d) => date_utils.dateKey(d);
}

enum ChallengeAnswerOutcome { noChallenge, alreadyCompletedToday, progressed, completed, failed }

class ChallengeAnswerResult {
  final ChallengeAnswerOutcome outcome;
  final ChallengeCompletion? completion;

  const ChallengeAnswerResult({required this.outcome, this.completion});
}

class ChallengeCompletion {
  final int duration;
  final int questionsEarned;
  final int categoriesEarned;
  final bool badgeUnlocked;
  final String title;

  const ChallengeCompletion({
    required this.duration,
    required this.questionsEarned,
    required this.categoriesEarned,
    required this.badgeUnlocked,
    required this.title,
  });
}
