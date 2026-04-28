import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:random_recall/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/database_helper.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/device_info.dart';
import '../../models/question.dart';
import '../../widgets/miui_battery_dialog.dart';
import '../home/home_screen.dart';
import 'first_question_page.dart';
import 'notification_setup_page.dart';
import 'welcome_page.dart';

// SharedPreferences keys used to survive process death mid-onboarding
const _kOnboardingPage = 'onboarding_draft_page';
const _kOnboardingQuestion = 'onboarding_draft_question';
const _kOnboardingAnswer = 'onboarding_draft_answer';
const _kOnboardingCategoryId = 'onboarding_draft_category_id';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();

  String? _questionText;
  String? _answerText;
  int? _categoryId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _restoreDraft();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Restore in-progress onboarding if the app was killed mid-flow
  /// (e.g. user left to enable notifications and Android killed the process).
  Future<void> _restoreDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPage = prefs.getInt(_kOnboardingPage) ?? 0;
    final savedQuestion = prefs.getString(_kOnboardingQuestion);
    final savedAnswer = prefs.getString(_kOnboardingAnswer);
    final savedCategoryId = prefs.getInt(_kOnboardingCategoryId);

    // Only restore if there is valid question data (means the user got past page 1)
    if (savedPage >= 2 &&
        savedQuestion != null &&
        savedAnswer != null &&
        savedCategoryId != null) {
      setState(() {
        _questionText = savedQuestion;
        _answerText = savedAnswer;
        _categoryId = savedCategoryId;
      });
      // Jump without animation since this is a restoration, not user navigation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pageController.jumpToPage(savedPage);
      });
    }
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _onFirstQuestionNext(
    String question,
    String answer,
    int categoryId,
  ) async {
    setState(() {
      _questionText = question;
      _answerText = answer;
      _categoryId = categoryId;
    });

    // Persist draft so the app can recover if killed while the user is on
    // the notification page (e.g. they went to Android settings and Android
    // killed the process due to memory pressure).
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_kOnboardingQuestion, question),
      prefs.setString(_kOnboardingAnswer, answer),
      prefs.setInt(_kOnboardingCategoryId, categoryId),
      prefs.setInt(_kOnboardingPage, 2),
    ]);

    _goToPage(2);
  }

  Future<void> _onNotificationSetupComplete({
    required bool randomAnytime,
    required int startHour,
    required int endHour,
    required int frequency,
    required List<int> activeDays,
  }) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      // Save first question to DB
      final db = DatabaseHelper.instance;
      final now = DateTime.now();
      await db.insertQuestion(
        Question(
          question: _questionText!,
          answer: _answerText!,
          categoryId: _categoryId!,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Save notification prefs + mark onboarding complete
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setBool('notif_random_anytime', randomAnytime),
        prefs.setInt('notif_start_hour', startHour),
        prefs.setInt('notif_end_hour', endHour),
        prefs.setInt('notif_frequency', frequency),
        prefs.setString(
          'notif_active_days',
          activeDays.map((d) => d.toString()).join(','),
        ),
        prefs.setBool('onboarding_complete', true),
        // Clear draft now that onboarding is fully complete
        prefs.remove(_kOnboardingPage),
        prefs.remove(_kOnboardingQuestion),
        prefs.remove(_kOnboardingAnswer),
        prefs.remove(_kOnboardingCategoryId),
      ]);

      final user = FirebaseAuth.instance.currentUser;
      final rawProvider = user?.providerData
              .map((p) => p.providerId)
              .firstWhere(
                (id) => id != 'firebase',
                orElse: () => 'unknown',
              ) ??
          'unknown';
      // Normalise provider IDs to match the values used in trackLogin().
      final authMethod = switch (rawProvider) {
        'google.com' => 'google',
        'password' => 'email',
        _ => rawProvider, // 'phone' is already correct
      };
      AnalyticsService.instance
          .trackOnboardingCompleted(authMethod: authMethod)
          .ignore();

      if (!mounted) return;

      // 1. Clear the saving state and wait for the widget tree to rebuild.
      setState(() => _isSaving = false);

      // Give MIUI/HyperOS a moment to settle the UI and remove the loader overlay.
      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted) return;

      // 2. Use pushReplacement - it is often more stable than pushAndRemoveUntil
      // during heavy lifecycle events like returning from permission settings.
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));

      // 3. Trigger background tasks after the transition is complete.
      // We wait 3 seconds to ensure the Home screen is fully interactive first.
      Future.delayed(const Duration(milliseconds: 3000), () async {
        try {
          final ns = NotificationService.instance;
          // Ensure init is called even if it failed/timed out during main()
          await ns.init();
          await ns.scheduleNotifications();

          final miui = await isMiuiDevice();
          if (miui) {
            // Ensure the Home screen is fully settled before showing MIUI dialog
            await Future.delayed(const Duration(milliseconds: 500));
            final homeContext =
                NotificationService.instance.navigatorKey?.currentContext;
            if (homeContext != null) await MiuiBatteryDialog.show(homeContext);
          }
        } catch (e) {
          debugPrint('Onboarding: Background tasks failed: $e');
        }
      });
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.onboardingSomethingWentWrong(e.toString())),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              WelcomePage(onNext: () => _goToPage(1)),
              FirstQuestionPage(
                onNext: _onFirstQuestionNext,
                onBack: () => _goToPage(0),
              ),
              NotificationSetupPage(
                onBack: () => _goToPage(1),
                onComplete:
                    ({
                      required bool randomAnytime,
                      required int startHour,
                      required int endHour,
                      required int frequency,
                      required List<int> activeDays,
                    }) => _onNotificationSetupComplete(
                      randomAnytime: randomAnytime,
                      startHour: startHour,
                      endHour: endHour,
                      frequency: frequency,
                      activeDays: activeDays,
                    ),
              ),
            ],
          ),
          if (_isSaving)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
