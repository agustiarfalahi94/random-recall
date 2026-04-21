import 'package:flutter/material.dart';
import 'package:random_recall/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.existingStreakTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.existingStreakMessage(currentStreak),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.existingStreakWarning,
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
          child: Text(l10n.existingStreakKeep),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            onStartChallenge();
          },
          child: Text(l10n.existingStreakStart),
        ),
      ],
    );
  }
}
