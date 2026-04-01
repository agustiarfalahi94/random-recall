import 'package:flutter/material.dart';

import '../../core/notifications/notification_service.dart';
import '../analytics/analytics_screen.dart';
import '../question/question_screen.dart';
import '../question/questions_list_screen.dart';

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
        const _HomeTab(),
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

  Future<void> _sendTestNotification() async {
    setState(() => _isSendingTest = true);
    try {
      await NotificationService.instance.sendTestNotification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent! Check your notification bar 🔔'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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

          // More settings coming soon
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
            subtitle: const Text('Coming soon'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: null,
          ),
        ],
      ),
    );
  }
}

// ── Home tab with Practice Now button ────────────────────────────────────────

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const QuestionScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Practice Now'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Placeholder tabs ──────────────────────────────────────────────────────────

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });

  final String emoji;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 34)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
