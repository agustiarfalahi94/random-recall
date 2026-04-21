import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

/// Tracks the user's timer-challenge streak.
///
/// Rules:
/// - Streak only increments when a question is answered with the timer ON.
/// - Answering at least once per calendar day with timer on counts as that day.
/// - Missing a day resets the streak to 1 (the current day).
/// - Every 7-day streak milestone grants +1 bonus question for free-tier users.
class StreakService {

  /// Maximum timer setting that qualifies for the streak challenge.
  /// Timers above this value (e.g. 90s) are too relaxed to earn a streak —
  /// the user must genuinely recall the answer under pressure.
  static const int challengeThreshold = 20; // seconds

  static const _keyStreak = 'timer_streak_days';
  static const _keyLastDate = 'timer_streak_last_date';
  static const _keyBonusQuestions = 'timer_streak_bonus_questions';

  // Challenge mode state constants
  static const _keyChallengeModeActive = 'challenge_mode_active';
  static const _keyChallengeModeStartDate = 'challenge_mode_start_date';
  static const _keyChallengeModeDay = 'challenge_mode_day';
  static const _keyChallengeDuration = 'challenge_duration'; // 7 or 14
  static const _keyChallengeLockedFrequency = 'challenge_locked_frequency';
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

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
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
  int get total7DayCompleted => _prefs.getInt(_keyTotal7DayCompleted) ?? 0;
  int get total14DayCompleted => _prefs.getInt(_keyTotal14DayCompleted) ?? 0;
  bool get challengeBadgeUnlocked =>
      _prefs.getBool(_keyChallengeBadgeUnlocked) ?? false;
  String get highestTitle => _prefs.getString(_keyHighestTitle) ?? '';
  int get bonusCategories => _prefs.getInt(_keyBonusCategories) ?? 0;
  int get bonusQuestions => _prefs.getInt(_keyBonusQuestions) ?? 0;
  int get currentStreak => _prefs.getInt(_keyStreak) ?? 0;

  // ── Challenge mode setter methods ───────────────────────────────────────────

  Future<void> startChallenge(int duration, int frequency) async {
    await _prefs.setBool(_keyChallengeModeActive, true);
    await _prefs.setInt(_keyChallengeDuration, duration);
    await _prefs.setInt(_keyChallengeModeDay, 1);
    await _prefs.setInt(_keyChallengeLockedFrequency, frequency);
    await _prefs.setString(_keyChallengeModeStartDate, DateTime.now().toIso8601String());
    await _saveToFirestore();
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
    await _prefs.remove(_keyChallengeModeStartDate);
    await _prefs.remove(_keyChallengeLastAnswerDate);
    // Reset current streak
    await _prefs.setInt(_keyStreak, 0);
    await _saveToFirestore();
  }

  Future<void> completeChallengeMode(int duration) async {
    // Challenge completed successfully
    if (duration == 7) {
      await _prefs.setInt(_keyTotal7DayCompleted, total7DayCompleted + 1);
      // Award bonus question (free-tier)
      final newQuestions = bonusQuestions + 1;
      await _prefs.setInt(_keyBonusQuestions, min(newQuestions, questionsMax - questionBase));
    } else if (duration == 14) {
      await _prefs.setInt(_keyTotal14DayCompleted, total14DayCompleted + 1);
      // Award bonus question + category (free-tier)
      final newQuestions = bonusQuestions + 1;
      final newCategories = bonusCategories + 1;
      await _prefs.setInt(_keyBonusQuestions, min(newQuestions, questionsMax - questionBase));
      await _prefs.setInt(_keyBonusCategories, min(newCategories, categoriesMax - categoryBase));
    }

    await resetChallenge(); // resetChallenge() calls _saveToFirestore()
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
    // Wrong answer during challenge - exit and reset
    if (isChallengeActive) {
      await _prefs.setInt(_keyStreak, 0);
      await resetChallenge();
      await _saveToFirestore();
    }
  }

  Future<void> checkChallengeDailyRequirement() async {
    if (!isChallengeActive) return;

    final lastAnswerDateStr = _prefs.getString(_keyChallengeLastAnswerDate);
    if (lastAnswerDateStr == null) return;

    final lastAnswerDate = DateTime.parse(lastAnswerDateStr);
    final now = DateTime.now();
    final daysDiff = now.difference(lastAnswerDate).inDays;

    // If more than 1 day since last answer, challenge failed
    if (daysDiff > 1) {
      await failChallenge();
    }
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
          await _prefs.setBool(_keyChallengeModeActive, challenge['active'] ?? false);
          await _prefs.setInt(_keyChallengeModeDay, challenge['day'] ?? 0);
          await _prefs.setInt(_keyChallengeDuration, challenge['duration'] ?? 7);
          await _prefs.setInt(_keyChallengeLockedFrequency, challenge['locked_frequency'] ?? 0);
          if (challenge['start_date'] != null) {
            await _prefs.setString(_keyChallengeModeStartDate, challenge['start_date']);
          }
          if (challenge['last_answer_date'] != null) {
            await _prefs.setString(_keyChallengeLastAnswerDate, challenge['last_answer_date']);
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

  // ── Record an activity (call when user grades a question with timer on) ────

  static Future<StreakResult> recordActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    final lastDate = prefs.getString(_keyLastDate) ?? '';
    final current = prefs.getInt(_keyStreak) ?? 0;

    // Already counted today → no change
    if (lastDate == today) {
      return StreakResult(streak: current, milestoneReached: false);
    }

    final yesterday = _dateKey(
      DateTime.now().subtract(const Duration(days: 1)),
    );

    // Consecutive day → increment; otherwise reset to 1
    final newStreak = (lastDate == yesterday) ? current + 1 : 1;

    await prefs.setInt(_keyStreak, newStreak);
    await prefs.setString(_keyLastDate, today);

    // Every 7 days grant a bonus question
    bool milestone = false;
    if (newStreak % 7 == 0) {
      final earned = prefs.getInt(_keyBonusQuestions) ?? 0;
      await prefs.setInt(_keyBonusQuestions, earned + 1);
      milestone = true;
    }

    return StreakResult(streak: newStreak, milestoneReached: milestone);
  }

  // ── Getters ────────────────────────────────────────────────────────────────

  static Future<int> getStreak() async {
    final prefs = await SharedPreferences.getInstance();
    // Check if streak is still alive (last date was today or yesterday)
    final lastDate = prefs.getString(_keyLastDate) ?? '';
    final today = _dateKey(DateTime.now());
    final yesterday = _dateKey(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    if (lastDate != today && lastDate != yesterday) {
      // Streak has expired
      await prefs.setInt(_keyStreak, 0);
      return 0;
    }
    return prefs.getInt(_keyStreak) ?? 0;
  }

  static Future<int> getBonusQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyBonusQuestions) ?? 0;
  }

  // ── Total question limit for free tier ────────────────────────────────────

  static Future<int> getFreeQuestionLimit() async {
    final bonus = await getBonusQuestions();
    return 20 + bonus; // base 20 + earned bonuses
  }

  // ── Helper ─────────────────────────────────────────────────────────────────

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class StreakResult {
  final int streak;
  final bool milestoneReached;

  const StreakResult({required this.streak, required this.milestoneReached});
}
