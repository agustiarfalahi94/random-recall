import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/database_helper.dart';
import '../../core/notifications/notification_service.dart';
import '../../models/question.dart';
import '../home/home_screen.dart';
import 'first_question_page.dart';
import 'notification_setup_page.dart';
import 'welcome_page.dart';

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
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  void _onFirstQuestionNext(String question, String answer, int categoryId) {
    setState(() {
      _questionText = question;
      _answerText = answer;
      _categoryId = categoryId;
    });
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
      await DatabaseHelper.instance.insertQuestion(Question(
        question: _questionText!,
        answer: _answerText!,
        categoryId: _categoryId!,
        createdAt: DateTime.now(),
      ));

      // Save notification prefs
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setBool('notif_random_anytime', randomAnytime),
        prefs.setInt('notif_start_hour', startHour),
        prefs.setInt('notif_end_hour', endHour),
        prefs.setInt('notif_frequency', frequency),
        prefs.setString('notif_active_days', activeDays.map((d) => d.toString()).join(',')),
        prefs.setBool('onboarding_complete', true),
      ]);

      // Schedule notifications
      await NotificationService.instance.scheduleNotifications();

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => const HomeScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Something went wrong: $e'),
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
              FirstQuestionPage(onNext: _onFirstQuestionNext),
              NotificationSetupPage(
                onComplete: ({
                  required bool randomAnytime,
                  required int startHour,
                  required int endHour,
                  required int frequency,
                  required List<int> activeDays,
                }) =>
                    _onNotificationSetupComplete(
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
