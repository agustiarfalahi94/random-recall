import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:random_recall/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../providers/app_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/auth_service.dart';
import '../../core/database/database_helper.dart';
import '../../core/notifications/notification_service.dart';
import '../../main.dart' show navigatorKey;
import '../../core/streak/streak_service.dart';
import '../../core/sync/sync_service.dart';
import '../analytics/analytics_screen.dart';
import '../categories/manage_categories_screen.dart';
import '../profile/profile_screen.dart';
import '../question/notification_question_screen.dart';
import '../question/question_screen.dart';
import '../question/questions_list_screen.dart';
import '../settings/faq_screen.dart';
import '../settings/notification_schedule_screen.dart';
import '../auth/display_name_setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.appTitle,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: () => _showSettingsSheet(context),
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settingsTooltip,
          ),
        ],
      ),
      body: [
        _HomeTab(), // Removed 'const' to ensure refresh when switching back to this tab
        const QuestionsListScreen(),
        const AnalyticsScreen(),
        const ProfileScreen(),
      ][_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.format_list_bulleted_outlined),
            selectedIcon: const Icon(Icons.format_list_bulleted_rounded),
            label: l10n.navQuestions,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart_rounded),
            label: l10n.navAnalytics,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outlined),
            selectedIcon: const Icon(Icons.person_rounded),
            label: l10n.profilePageTitle,
          ),
        ],
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows the sheet to expand to fit its content
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _SettingsSheet(),
    );
  }
}

// ── Settings bottom sheet ─────────────────────────────────────────────────────

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  bool _isSendingTest = false;
  bool _isSyncingManual = false;

  Future<void> _syncNow() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isSyncingManual = true);
    try {
      await SyncService.instance.performRestore(force: true);
      if (!mounted) return;
      Navigator.of(context).pop(); // Close settings sheet on success
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.syncCompleteSnack)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.syncFailedSnack(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _isSyncingManual = false);
    }
  }

  Future<void> _sendTestNotification() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    setState(() => _isSendingTest = true);
    try {
      await NotificationService.instance.sendTestNotification();
      if (nav.canPop()) nav.pop(); // Close settings sheet
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.testNotifSentSnack),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.testNotifFailedSnack(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _isSendingTest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final user = AuthService.instance.currentUser;
    // More robust check: is the primary sign-in provider Google?
    final isGoogle =
        user?.providerData.any((p) => p.providerId == 'google.com') ?? false;

    final providerLabel = isGoogle ? l10n.providerGoogle : l10n.providerEmail;
    final providerIcon = isGoogle
        ? Icons.g_mobiledata_rounded
        : Icons.alternate_email_rounded;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize:
              MainAxisSize.min, // Still min to keep it compact on large screens
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              l10n.settingsTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),

            // Sync Now button
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.sync_rounded, color: colorScheme.primary),
              ),
              title: Text(
                l10n.syncDataNow,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(l10n.syncSubtitle),
              trailing: _isSyncingManual
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 20),
              onTap: _isSyncingManual ? null : _syncNow,
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.syncSingleDeviceNote,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(),

            // Test notification button
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('🔔', style: TextStyle(fontSize: 20)),
                ),
              ),
              title: Text(
                l10n.sendTestNotification,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(l10n.sendTestSubtitle),
              trailing: _isSendingTest
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right_rounded),
              onTap: _isSendingTest ? null : _sendTestNotification,
            ),

            const Divider(),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('⏰', style: TextStyle(fontSize: 20)),
                ),
              ),
              title: Text(
                l10n.notifScheduleMenuItem,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(l10n.notifScheduleMenuSubtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationScheduleScreen(),
                  ),
                );
              },
            ),

            const Divider(),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('🏷️', style: TextStyle(fontSize: 20)),
                ),
              ),
              title: Text(
                l10n.manageCategoriesMenuItem,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(l10n.manageCategoriesMenuSubtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ManageCategoriesScreen(),
                  ),
                );
              },
            ),

            const Divider(),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    Icons.rate_review_rounded,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              title: Text(
                l10n.sendFeedbackMenuItem,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(l10n.sendFeedbackMenuSubtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showFeedbackDialog(context),
            ),

            const Divider(),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    Icons.help_outline_rounded,
                    color: colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
              title: Text(
                l10n.faqMenuItem,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(l10n.faqMenuSubtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const FaqScreen()));
              },
            ),

            const Divider(),

            // Language switcher
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.language_rounded,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              title: Text(
                l10n.language,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(l10n.languageSubtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showLanguageDialog(context),
            ),

            const Divider(),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    Icons.logout_rounded,
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
              title: Text(
                l10n.signOut,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Row(
                children: [
                  Icon(
                    providerIcon,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '$providerLabel • ${user?.email ?? "User"}',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              onTap: () async {
                final l10n = AppLocalizations.of(context)!;
                // Use the root navigator directly — Navigator.of(context) inside a
                // bottom sheet can resolve to the sheet's sub-tree navigator and
                // silently fail to clear routes on the MaterialApp navigator.
                final rootNav = navigatorKey.currentState!;
                final messenger = ScaffoldMessenger.of(context);

                // Show loading dialog on the root navigator so popUntil can
                // dismiss it together with the settings sheet in one shot.
                rootNav.push(
                  DialogRoute(
                    context: rootNav.overlay!.context,
                    barrierDismissible: false,
                    builder: (_) => Center(
                      child: Card(
                        margin: const EdgeInsets.all(32),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(
                                l10n.signingOutSafely,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.backingUpData,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );

                try {
                  await AuthService.instance.signOut(
                    onBeforeFinalSignOut: () async {
                      // Clear every modal route (dialog + sheet) from the root
                      // navigator so LoginScreen is immediately visible when the
                      // StreamBuilder switches after _auth.signOut() fires.
                      rootNav.popUntil((route) => route.isFirst);
                    },
                  );
                } catch (e) {
                  if (rootNav.canPop()) rootNav.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(l10n.signOutFailedSnack(e.toString())),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFeedbackDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    Navigator.of(context).pop(); // close settings sheet first
    final controller = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.sendFeedbackDialogTitle),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(hintText: l10n.feedbackHint),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.send),
          ),
        ],
      ),
    );

    if (submitted == true && controller.text.trim().isNotEmpty) {
      try {
        final eventId = await Sentry.captureMessage('User feedback');
        await Sentry.captureUserFeedback(
          SentryUserFeedback(
            eventId: eventId,
            comments: controller.text.trim(),
            email: AuthService.instance.currentUser?.email,
          ),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.feedbackSentSnack)));
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.feedbackFailedSnack)));
        }
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
  }

  void _showLanguageDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appProvider = context.read<AppProvider>();
    final currentLocale = appProvider.locale?.languageCode ?? 'en';
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.language),
        children: [
          RadioListTile<String>(
            title: Text(l10n.languageEnglish),
            value: 'en',
            groupValue: currentLocale,
            onChanged: (v) {
              appProvider.setLocale(const Locale('en'));
              Navigator.of(ctx).pop();
            },
          ),
          RadioListTile<String>(
            title: Text(l10n.languageIndonesian),
            value: 'id',
            groupValue: currentLocale,
            onChanged: (v) {
              appProvider.setLocale(const Locale('id'));
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }
}

// ── Home tab with Practice Now button ────────────────────────────────────────

class _HomeTab extends StatefulWidget {
  const _HomeTab({super.key});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> with WidgetsBindingObserver {
  int _streak = 0;
  int _timerSeconds = 0;
  int _bonusQuestions = 0;
  int _unansweredCount = 0;

  StreamSubscription<void>? _answeredSub;
  StreamSubscription<void>? _databaseUpdateSub;
  Timer? _nextNotifTimer;
  Timer? _initRetryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Refresh badge immediately whenever a notification is answered anywhere
    // (covers the case where _onNotificationTapped pushes the answer screen
    // directly without going through the home screen's own navigation).
    _answeredSub = NotificationService.instance.onNotificationAnswered.listen(
      (_) => _refreshData(),
    );

    // Refresh data whenever the database is updated (e.g., after sync restore)
    _databaseUpdateSub = DatabaseHelper.instance.onDatabaseUpdated.listen(
      (_) => _refreshData(),
    );

    _refreshData();
    // The notification plugin initializes in the post-frame callback (main.dart),
    // which runs after the widget tree is built. Retry once after init is likely
    // complete so the badge picks up notifications that fired while closed.
    _initRetryTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) _refreshData();
    });

    // Check if challenge daily requirement is met
    StreakService.instance.checkChallengeDailyRequirement().ignore();

    // Check if user has set a display name, prompt if not
    _checkAndShowDisplayNamePrompt();

  }

  @override
  void dispose() {
    _initRetryTimer?.cancel();
    _answeredSub?.cancel();
    _databaseUpdateSub?.cancel();
    _nextNotifTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkAndShowDisplayNamePrompt() async {
    final user = FirebaseAuth.instance.currentUser;
    debugPrint('HomeTab: Checking display name. User: ${user?.uid}, DisplayName: "${user?.displayName}"');

    if (user != null && (user.displayName == null || user.displayName!.isEmpty)) {
      debugPrint('HomeTab: Showing display name setup dialog');
      // Show display name setup screen
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false, // Can't dismiss for new users
          builder: (context) => DisplayNameSetupScreen(
            canDismiss: false,
            onComplete: () {
              debugPrint('HomeTab: Display name setup completed');
              // Dialog will auto-close, refresh home screen
              setState(() {});
            },
          ),
        );
      } else {
        debugPrint('HomeTab: Widget not mounted, skipping display name dialog');
      }
    } else {
      debugPrint('HomeTab: User has displayName set or user is null, skipping dialog');
    }
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  Future<void> _refreshData() async {
    final prefs = await SharedPreferences.getInstance();
    final streak = await StreakService.getStreak();
    final bonus = await StreakService.getBonusQuestions();
    final unanswered = await NotificationService.instance.getUnansweredCount();

    if (mounted) {
      setState(() {
        _streak = streak;
        _timerSeconds = prefs.getInt('notif_timer_seconds') ?? 0;
        _bonusQuestions = bonus;
        _unansweredCount = unanswered;
      });
    }

    // Schedule a one-shot timer to fire exactly when the next notification is
    // due, so the badge updates in real time while the app is in the foreground.
    _nextNotifTimer?.cancel();
    _nextNotifTimer = null;
    try {
      final log = await NotificationService.instance.getMirrorLog();
      final now = DateTime.now();
      DateTime? nextTime;
      for (final entry in log) {
        final t = DateTime.tryParse(entry['time'] as String? ?? '');
        if (t != null && t.isAfter(now)) {
          if (nextTime == null || t.isBefore(nextTime)) nextTime = t;
        }
      }
      if (nextTime != null && mounted) {
        // Add 2s buffer so the OS alarm has time to fire and the mirror log
        // entry's scheduled time is safely in the past for isBefore() checks.
        _nextNotifTimer = Timer(
          nextTime.difference(now) + const Duration(seconds: 2),
          _refreshData,
        );
      }
    } catch (e) {
      debugPrint('HomeTab: badge timer setup error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? 'Random Recall';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        children: [
          // ── Welcome message ──────────────────────────────────────────────
          Text(
            l10n.welcomeMessage(displayName),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // ── Hero section ─────────────────────────────────────────────────
          GestureDetector(
            onTap: () async {
              if (_unansweredCount > 0) {
                final questionId = await NotificationService.instance
                    .getOldestUnansweredQuestionId();
                if (mounted) {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) => NotificationQuestionScreen(
                            questionId: questionId,
                          ),
                        ),
                      )
                      .then((_) => _refreshData());
                }
              }
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🧠', style: TextStyle(fontSize: 48)),
                  ),
                ),
                if (_unansweredCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colorScheme.error,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.surface,
                          width: 3,
                        ),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      child: Center(
                        child: Text(
                          '$_unansweredCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.readyToRecall,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.homeSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (_) => const QuestionScreen(isPractice: true),
                    ),
                  )
                  .then((_) => _refreshData()); // refresh on return
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(l10n.practiceNow),
          ),

          const SizedBox(height: 32),

          // ── Timer challenge card ─────────────────────────────────────────
          _TimerChallengeCard(
            streak: _streak,
            timerSeconds: _timerSeconds,
            bonusQuestions: _bonusQuestions,
            onSetTimer: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const NotificationScheduleScreen(scrollToTimer: true),
                ),
              );
              _refreshData();
            },
          ),
        ],
      ),
    );
  }
}

// ── Timer challenge card ──────────────────────────────────────────────────────

class _TimerChallengeCard extends StatelessWidget {
  const _TimerChallengeCard({
    required this.streak,
    required this.timerSeconds,
    required this.bonusQuestions,
    required this.onSetTimer,
  });

  final int streak;
  final int timerSeconds;
  final int bonusQuestions;
  final VoidCallback onSetTimer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final timerOn = timerSeconds > 0;
    // Challenge is only active when timer is ≤ threshold — relaxed timers don't count
    final challengeActive =
        timerSeconds > 0 && timerSeconds <= StreakService.challengeThreshold;
    final daysToNext = challengeActive ? (7 - (streak % 7)) : 7;
    final progressInCycle = challengeActive ? (streak % 7) : 0;

    return GestureDetector(
      onTap: onSetTimer,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: timerOn
                ? colorScheme.primary.withOpacity(0.3)
                : colorScheme.outlineVariant.withOpacity(0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.timerChallengeTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (bonusQuestions > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      l10n.bonusCountLabel(bonusQuestions),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                if (timerOn) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              timerOn
                  ? (timerSeconds <= StreakService.challengeThreshold
                        ? l10n.timerChallengeActiveDesc(timerSeconds)
                        : l10n.timerChallengeRelaxedDesc(
                            timerSeconds,
                            StreakService.challengeThreshold,
                          ))
                  : l10n.timerChallengeOffDesc(
                      StreakService.challengeThreshold,
                    ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),

            if (challengeActive) ...[
              const SizedBox(height: 16),
              // Progress bar: days in current 7-day cycle
              Row(
                children: List.generate(7, (i) {
                  final filled = i < progressInCycle;
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 4),
                      height: 8,
                      decoration: BoxDecoration(
                        color: filled
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                streak == 0
                    ? l10n.streakStart
                    : l10n.streakProgress(
                        streak,
                        streak == 1 ? '' : 's',
                        daysToNext,
                      ),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onSetTimer,
                  icon: const Icon(Icons.timer_outlined, size: 18),
                  label: Text(l10n.setATimer),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ); // GestureDetector + Container
  }
}
