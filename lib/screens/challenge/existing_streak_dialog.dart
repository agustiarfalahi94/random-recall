import 'package:flutter/material.dart';

class ExistingStreakDialog extends StatelessWidget {
  final int currentStreak;
  final Function() onKeepStreak;
  final Function() onStartChallenge;

  const ExistingStreakDialog({
    super.key,
    required this.currentStreak,
    required this.onKeepStreak,
    required this.onStartChallenge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Active Streak Detected'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You currently have a $currentStreak-day streak!',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'If you start Challenge Mode now, your current streak will be reset to day 1. Do you want to:',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onKeepStreak();
          },
          child: const Text('Keep Streak'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            onStartChallenge();
          },
          child: const Text('Start Challenge'),
        ),
      ],
    );
  }
}
