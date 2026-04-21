import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:random_recall/core/streak/streak_service.dart';

void main() {
  group('StreakService Challenge Mode', () {
    late StreakService streakService;

    setUp(() async {
      // Initialize shared preferences for testing
      SharedPreferences.setMockInitialValues({});
      streakService = StreakService();
      await streakService.initialize();
    });

    test('startChallenge sets challenge mode active', () async {
      await streakService.startChallenge(7, 10);
      expect(streakService.isChallengeActive, true);
      expect(streakService.challengeDuration, 7);
      expect(streakService.lockedFrequency, 10);
    });

    test('incrementChallengeDay increases day counter', () async {
      await streakService.startChallenge(7, 10);
      await streakService.incrementChallengeDay();
      expect(streakService.challengeDay, 2);
    });

    test('resetChallenge clears all challenge data', () async {
      await streakService.startChallenge(7, 10);
      await streakService.resetChallenge();
      expect(streakService.isChallengeActive, false);
      expect(streakService.challengeDay, 0);
    });

    test('completeChallengeMode 7-day awards bonus question', () async {
      final before = streakService.bonusQuestions;
      await streakService.startChallenge(7, 10);
      await streakService.completeChallengeMode(7);
      expect(streakService.bonusQuestions, before + 1);
      expect(streakService.isChallengeActive, false);
    });

    test('completeChallengeMode 14-day awards question and category', () async {
      final beforeQ = streakService.bonusQuestions;
      final beforeC = streakService.bonusCategories;
      await streakService.startChallenge(14, 10);
      await streakService.completeChallengeMode(14);
      expect(streakService.bonusQuestions, beforeQ + 1);
      expect(streakService.bonusCategories, beforeC + 1);
    });

    test('failChallenge resets streak and clears challenge', () async {
      await streakService.startChallenge(7, 10);
      await streakService.failChallenge();
      expect(streakService.currentStreak, 0);
      expect(streakService.isChallengeActive, false);
    });

    test('unlockChallengeBadge sets badge flag', () async {
      await streakService.unlockChallengeBadge();
      expect(streakService.challengeBadgeUnlocked, true);
    });

    test('setHighestTitle stores title correctly', () async {
      await streakService.setHighestTitle('Champion');
      expect(streakService.highestTitle, 'Champion');
    });

    test('bonus questions respect max limit', () async {
      // Set bonus questions to near max
      await streakService.startChallenge(7, 10);
      // Manually set to near max for testing
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('timer_streak_bonus_questions', 170);

      // Complete challenge to award bonus
      await streakService.completeChallengeMode(7);

      // Should not exceed max
      expect(streakService.bonusQuestions, lessThanOrEqualTo(200 - 20));
    });

    test('bonus categories respect max limit', () async {
      // Set bonus categories to near max
      await streakService.startChallenge(14, 10);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('bonus_categories', 14);

      // Complete challenge to award bonus
      await streakService.completeChallengeMode(14);

      // Should not exceed max
      expect(streakService.bonusCategories, lessThanOrEqualTo(20 - 4));
    });

    test('total 7-day completed counter increments', () async {
      final before = streakService.total7DayCompleted;
      await streakService.startChallenge(7, 10);
      await streakService.completeChallengeMode(7);
      expect(streakService.total7DayCompleted, before + 1);
    });

    test('total 14-day completed counter increments', () async {
      final before = streakService.total14DayCompleted;
      await streakService.startChallenge(14, 10);
      await streakService.completeChallengeMode(14);
      expect(streakService.total14DayCompleted, before + 1);
    });
  });
}
