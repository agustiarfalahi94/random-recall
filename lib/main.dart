import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/notifications/background_worker.dart';
import 'core/notifications/notification_service.dart';
import 'providers/app_provider.dart';
import 'screens/home/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/question/notification_question_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Wire up navigator key so notification taps can navigate
  NotificationService.instance.navigatorKey = navigatorKey;

  await NotificationService.instance.init();
  await NotificationService.instance.requestPermission();

  // Register a WorkManager periodic task that rebuilds the 7-day notification
  // window every 6 hours. This keeps notifications firing even when the user
  // hasn't opened the app in days, and survives device reboots.
  await registerNotificationWorker();

  final prefs = await SharedPreferences.getInstance();
  final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

  if (onboardingComplete) {
    await NotificationService.instance.scheduleNotifications();
  }

  runApp(RandomRecallApp(onboardingComplete: onboardingComplete));

  // Handle cold-start from notification tap (navigator not ready during init)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    NotificationService.instance.handleNotificationLaunch();
  });
}

class RandomRecallApp extends StatelessWidget {
  const RandomRecallApp({super.key, required this.onboardingComplete});

  final bool onboardingComplete;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: MaterialApp(
        title: 'Random Recall',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        home: onboardingComplete
            ? const HomeScreen()
            : const OnboardingScreen(),
        // Named routes for notification tap navigation
        onGenerateRoute: (settings) {
          if (settings.name == '/question') {
            final questionId = settings.arguments as int?;
            return MaterialPageRoute(
              builder: (_) => NotificationQuestionScreen(questionId: questionId),
            );
          }
          if (settings.name == '/question_practice') {
            final questionId = settings.arguments as int?;
            return MaterialPageRoute(
              builder: (_) => NotificationQuestionScreen(
                  questionId: questionId, isPractice: true),
            );
          }
          return null;
        },
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
        ),
      ),
    );
  }
}
