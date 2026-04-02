import 'package:shared_preferences/shared_preferences.dart';

/// Tracks the user's timer-challenge streak.
///
/// Rules:
/// - Streak only increments when a question is answered with the timer ON.
/// - Answering at least once per calendar day with timer on counts as that day.
/// - Missing a day resets the streak to 1 (the current day).
/// - Every 7-day streak milestone grants +1 bonus question for free-tier users.
class StreakService {
  StreakService._();

  /// Maximum timer setting that qualifies for the streak challenge.
  /// Timers above this value (e.g. 90s) are too relaxed to earn a streak —
  /// the user must genuinely recall the answer under pressure.
  static const int challengeThreshold = 20; // seconds

  static const _keyStreak = 'timer_streak_days';
  static const _keyLastDate = 'timer_streak_last_date';
  static const _keyBonusQuestions = 'timer_streak_bonus_questions';

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

  const StreakResult({
    required this.streak,
    required this.milestoneReached,
  });
}
