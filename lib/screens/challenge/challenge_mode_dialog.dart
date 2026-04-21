import 'package:flutter/material.dart';
import 'package:random_recall/l10n/app_localizations.dart';

class ChallengeFrequencyDialog extends StatefulWidget {
  final int duration; // 7 or 14 days
  final Function(int) onFrequencySelected;

  const ChallengeFrequencyDialog({
    super.key,
    required this.duration,
    required this.onFrequencySelected,
  });

  @override
  State<ChallengeFrequencyDialog> createState() => _ChallengeFrequencyDialogState();
}

class _ChallengeFrequencyDialogState extends State<ChallengeFrequencyDialog> {
  late int _selectedFrequency;

  @override
  void initState() {
    super.initState();
    _selectedFrequency = 10; // Default to 10
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.challengeModeFrequencyTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.challengeModeFrequencyHint(widget.duration),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Text(
              '$_selectedFrequency',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Slider(
              value: _selectedFrequency.toDouble(),
              min: 1,
              max: 50,
              divisions: 49,
              label: '$_selectedFrequency',
              onChanged: (value) {
                setState(() => _selectedFrequency = value.toInt());
              },
            ),
            const SizedBox(height: 8),
            Text(
              l10n.challengeModeFrequencyRange,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.challengeWarningCancel),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onFrequencySelected(_selectedFrequency);
          },
          child: Text(l10n.challengeWarningStart),
        ),
      ],
    );
  }
}
