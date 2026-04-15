import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/auth_service.dart';
import '../../core/notifications/notification_service.dart';
import '../../main.dart' show navigatorKey;
import '../../core/streak/streak_service.dart';
import '../../core/sync/sync_service.dart';
import '../analytics/analytics_screen.dart';
import '../categories/manage_categories_screen.dart';
import '../question/notification_question_screen.dart';
import '../question/question_screen.dart';
import '../question/questions_list_screen.dart';
import '../settings/faq_screen.dart';
import '../settings/notification_schedule_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Random Recall',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: () => _showSettingsSheet(context),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: [
        _HomeTab(), // Removed 'const' to ensure refresh when switching back to this tab
        const QuestionsListScreen(),
        const AnalyticsScreen(),
      ][_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.format_list_bulleted_outlined),
            selectedIcon: Icon(Icons.format_list_bulleted_rounded),
            label: 'Questions',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Analytics',
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
    setState(() => _isSyncingManual = true);
    try {
      await SyncService.instance.performRestore();
      if (!mounted) return;
      Navigator.of(context).pop(); // Close settings sheet on success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync complete! Data is up to date. 🔄')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSyncingManual = false);
    }
  }

  Future<void> _sendTestNotification() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    setState(() => _isSendingTest = true);
    try {
      await NotificationService.instance.sendTestNotification();
      if (nav.canPop()) nav.pop(); // Close settings sheet
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Test notification sent! Check your notification bar 🔔'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to send: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSendingTest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final user = AuthService.instance.currentUser;
    // More robust check: is the primary sign-in provider Google?
    final isGoogle = user?.providerData.any((p) => p.providerId == 'google.com') ?? false;
    
    final providerLabel = isGoogle ? 'Google' : 'Email';
    final providerIcon = isGoogle 
        ? Icons.g_mobiledata_rounded 
        : Icons.alternate_email_rounded;

    return SingleChildScrollView(
      child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Still min to keep it compact on large screens
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
            'Settings',
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
            title: const Text(
              'Sync Data Now',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Pull latest changes from the cloud'),
            trailing: _isSyncingManual
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded, size: 20),
            onTap: _isSyncingManual ? null : _syncNow,
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
              child: const Center(child: Text('🔔', style: TextStyle(fontSize: 20))),
            ),
            title: const Text(
              'Send test notification',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Verify notifications work on your device'),
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
              child: const Center(child: Text('⏰', style: TextStyle(fontSize: 20))),
            ),
            title: const Text(
              'Notification schedule',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Set timing, days & frequency'),
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
              child: const Center(child: Text('🏷️', style: TextStyle(fontSize: 20))),
            ),
            title: const Text(
              'Manage categories',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Add or remove question categories'),
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
                child: Icon(Icons.rate_review_rounded,
                    color: colorScheme.onSecondaryContainer),
              ),
            ),
            title: const Text(
              'Send feedback',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Tell us what could be better'),
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
                child: Icon(Icons.help_outline_rounded,
                    color: colorScheme.onTertiaryContainer),
              ),
            ),
            title: const Text(
              'FAQ',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Common questions & expected behaviour'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FaqScreen()),
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
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(Icons.logout_rounded, color: colorScheme.onErrorContainer),
              ),
            ),
            title: const Text(
              'Sign Out',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Row(
              children: [
                Icon(providerIcon, size: 14, color: colorScheme.onSurfaceVariant),
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
                  builder: (_) => const Center(
                    child: Card(
                      margin: EdgeInsets.all(32),
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Signing out safely...', style: TextStyle(fontWeight: FontWeight.w600)),
                            SizedBox(height: 4),
                            Text('Backing up your data', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                messenger.showSnackBar(SnackBar(content: Text('Sign out failed: $e')));
              }
            },
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _showFeedbackDialog(BuildContext context) async {
    Navigator.of(context).pop(); // close settings sheet first
    final controller = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send feedback'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'What could be better?',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (submitted == true && controller.text.trim().isNotEmpty) {
      try {
        final eventId = await Sentry.captureMessage('User feedback');
        await Sentry.captureUserFeedback(SentryUserFeedback(
          eventId: eventId,
          comments: controller.text.trim(),
          email: AuthService.instance.currentUser?.email,
        ));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Feedback sent — thank you!')),
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not send feedback. Try again later.')),
          );
        }
      }
    }
    controller.dispose();
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
  Timer? _nextNotifTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Refresh badge immediately whenever a notification is answered anywhere
    // (covers the case where _onNotificationTapped pushes the answer screen
    // directly without going through the home screen's own navigation).
    _answeredSub = NotificationService.instance.onNotificationAnswered
        .listen((_) => _refreshData());
    _refreshData();
  }

  @override
  void dispose() {
    _answeredSub?.cancel();
    _nextNotifTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
        _nextNotifTimer = Timer(nextTime.difference(now), _refreshData);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        children: [
          // ── Hero section ─────────────────────────────────────────────────
          GestureDetector(
            onTap: () async {
              if (_unansweredCount > 0) {
                final questionId = await NotificationService.instance.getOldestUnansweredQuestionId();
                if (mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NotificationQuestionScreen(questionId: questionId),
                    ),
                  ).then((_) => _refreshData());
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
                        border: Border.all(color: colorScheme.surface, width: 3),
                      ),
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      child: Center(
                        child: Text(
                          '$_unansweredCount',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Ready to recall?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap below to practice anytime,\nor wait for a random notification.',
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
                  .push(MaterialPageRoute(
                    builder: (_) => const QuestionScreen(isPractice: true),
                  ))
                  .then((_) => _refreshData()); // refresh on return
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Practice Now'),
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
                  builder: (_) => const NotificationScheduleScreen(
                    scrollToTimer: true,
                  ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final timerOn = timerSeconds > 0;
    // Challenge is only active when timer is ≤ threshold — relaxed timers don't count
    final challengeActive = timerSeconds > 0 &&
        timerSeconds <= StreakService.challengeThreshold;
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
                  'Timer Challenge',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (bonusQuestions > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '+$bonusQuestions bonus',
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
                    ? 'Timer set to ${timerSeconds}s — challenge active! '
                        'Answer daily for 7 days to earn +1 question slot.'
                    : 'Timer is ${timerSeconds}s — too relaxed for challenge. '
                        'Set to ${StreakService.challengeThreshold}s or less to earn streaks.')
                : 'Set a timer (${StreakService.challengeThreshold}s or less) to unlock '
                    'the challenge. Answer daily for 7 days → earn +1 question slot!',
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
                  ? 'Start today! Answer with the timer on.'
                  : '$streak day${streak == 1 ? '' : 's'} streak — '
                      '$daysToNext more to earn a bonus!',
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
                label: const Text('Set a Timer'),
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
    )); // GestureDetector + Container
  }
}
