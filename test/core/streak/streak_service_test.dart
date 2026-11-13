import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart'
    show FirebaseAuthPlatform, InternalUserDetails, UserPlatform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart'
    show FirebaseAppPlatform, FirebasePlatform, coreNotInitialized;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:random_recall/core/streak/streak_service.dart';

/// Minimal in-memory Firebase platform so `Firebase.initializeApp()` succeeds
/// in unit tests without native platform channels.
///
/// StreakService touches the AnalyticsService singleton (which resolves
/// `Firebase.app()`) on every challenge mutation, so Firebase must be
/// bootstrapped before any challenge test runs.
class _FakeFirebasePlatform extends FirebasePlatform {
  final Map<String, FirebaseAppPlatform> _apps = {};

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    final appName = name ?? defaultFirebaseAppName;
    return _apps.putIfAbsent(
      appName,
      () => FirebaseAppPlatform(
        appName,
        options ??
            const FirebaseOptions(
              apiKey: 'fake-api-key',
              appId: 'fake-app-id',
              messagingSenderId: 'fake-sender-id',
              projectId: 'fake-project-id',
            ),
      ),
    );
  }

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    final app = _apps[name];
    if (app == null) {
      throw coreNotInitialized();
    }
    return app;
  }
}

/// Minimal Firebase Auth platform fake. The real method-channel implementation
/// fires an async `registerIdTokenListener` call in its constructor that fails
/// in unit tests, so it must be replaced before `FirebaseAuth.currentUser` is
/// ever touched (StreakService._saveToFirestore reads it).
class _FakeAuthPlatform extends FirebaseAuthPlatform {
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;

  @override
  UserPlatform? get currentUser => null;

  @override
  Stream<UserPlatform?> authStateChanges() => const Stream.empty();

  @override
  Stream<UserPlatform?> idTokenChanges() => const Stream.empty();

  @override
  Stream<UserPlatform?> userChanges() => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FirebasePlatform.instance = _FakeFirebasePlatform();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _FakeAuthPlatform();
  });

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

    test('completeChallengeMode 7-day unlocks badge and title', () async {
      await streakService.startChallenge(7, 10);
      final completion = await streakService.completeChallengeMode(7);
      expect(completion.badgeUnlocked, true);
      expect(completion.title, 'Challenger');
      expect(streakService.challengeBadgeUnlocked, true);
      expect(streakService.highestTitle, 'Challenger');
      expect(streakService.isChallengeActive, false);
    });

    test('completeChallengeMode 14-day unlocks badge and title', () async {
      await streakService.startChallenge(14, 10);
      final completion = await streakService.completeChallengeMode(14);
      expect(completion.badgeUnlocked, true);
      expect(completion.title, 'Challenger');
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

    test(
      'checkChallengeDailyRequirement fails challenge if day gap > 1',
      () async {
        await streakService.startChallenge(7, 10);

        // Simulate last answer was 2 days ago
        final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
        await streakService.prefsForTesting.setString(
          'challenge_last_answer_date',
          twoDaysAgo.toIso8601String(),
        );

        // Check daily requirement
        await streakService.checkChallengeDailyRequirement();

        // Should fail challenge
        expect(streakService.isChallengeActive, false);
        expect(streakService.currentStreak, 0);
      },
    );
  });
}
