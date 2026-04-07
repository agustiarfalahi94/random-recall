import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/notifications/background_worker.dart';
import 'core/notifications/notification_service.dart';
import 'core/utils/battery_optimization.dart';
import 'providers/app_provider.dart';
import 'screens/home/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'core/sync/sync_service.dart';
import 'screens/auth/login_screen.dart';
import 'core/auth/auth_service.dart';
import 'core/plan/subscription_service.dart';
import 'screens/question/notification_question_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Start In-App Purchase listener
  SubscriptionService.instance.init();

  // Wire up navigator key so notification taps can navigate
  NotificationService.instance.navigatorKey = navigatorKey;

  runApp(const RandomRecallApp());

  // Handle cold-start from notification tap (navigator not ready during init)
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      // Initialize service and check launch details
      await NotificationService.instance.init();
      await NotificationService.instance.handleNotificationLaunch();
      
      // Setup background worker and initial scheduling
      final prefs = await SharedPreferences.getInstance();
      final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
      final currentUser = AuthService.instance.currentUser;

      if (onboardingComplete && currentUser != null) {
        // Perform an initial sync restore to ensure this device has the latest cloud data
        SyncService.instance.performRestore();
        await registerNotificationWorker().catchError((e) => debugPrint('WorkManager failed: $e'));
      }
    } catch (e) {
      debugPrint('Startup background tasks failed: $e');
    }

    // For existing users who updated the app: silently request battery
    // optimisation whitelist if not already granted. The system dialog only
    // appears once and is non-blocking — no UX disruption.
    final prefs = await SharedPreferences.getInstance();
    final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
    if (onboardingComplete) {
      isIgnoringBatteryOptimizations().then((isIgnoring) {
        if (!isIgnoring) requestIgnoreBatteryOptimizations();
      });
    }
  });
}

class RandomRecallApp extends StatelessWidget {
  const RandomRecallApp({super.key});

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
        home: StreamBuilder<User?>(
          stream: AuthService.instance.authStateChanges,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final user = snapshot.data;
            if (user == null) {
              return const LoginScreen();
            }
            return const _HomeGate();
          },
        ),
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

class _HomeGate extends StatefulWidget {
  const _HomeGate();

  @override
  State<_HomeGate> createState() => _HomeGateState();
}

class _HomeGateState extends State<_HomeGate> {
  bool _isChecking = true;
  bool _onboardingComplete = false;

  @override
  void initState() {
    super.initState();
    _initFlow();
  }

  Future<void> _initFlow() async {
    final prefs = await SharedPreferences.getInstance();
    bool complete = prefs.getBool('onboarding_complete') ?? false;

    if (!complete) {
      // If locally incomplete, check the cloud once before forcing onboarding
      debugPrint('HomeGate: Checking cloud for existing data...');
      await SyncService.instance.performRestore();
      // Re-check after restore attempt
      complete = prefs.getBool('onboarding_complete') ?? false;
    }

    // Start the real-time bidirectional listeners
    SyncService.instance.startRealtimeSync();

    if (mounted) {
      setState(() {
        _onboardingComplete = complete;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _onboardingComplete ? const HomeScreen() : const OnboardingScreen();
  }
}
