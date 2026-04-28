import 'package:flutter/material.dart';
import 'package:random_recall/l10n/app_localizations.dart';
import 'package:random_recall/core/streak/streak_service.dart';
import 'existing_streak_dialog.dart';

class ChallengeWarningDialog extends StatefulWidget {
  final int duration; // 7 or 14
  final int frequency; // questions per day (1-50)
  final bool isPremiumUser;
  final VoidCallback onStartChallenge;

  const ChallengeWarningDialog({
    super.key,
    required this.duration,
    required this.frequency,
    required this.isPremiumUser,
    required this.onStartChallenge,
  });

  @override
  State<ChallengeWarningDialog> createState() => _ChallengeWarningDialogState();
}

class _ChallengeWarningDialogState extends State<ChallengeWarningDialog> {
  bool _isLoading = false;

  Future<void> _start() async {
    setState(() => _isLoading = true);

    try {
      final streakService = StreakService();
      await streakService.startChallenge(widget.duration, widget.frequency);

      widget.onStartChallenge();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.challengeStartError(e.toString()))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Check if there's an existing streak and show dialog if so
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentStreak = StreakService.instance.currentStreak;
      if (currentStreak > 0) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => ExistingStreakDialog(
            currentStreak: currentStreak,
            onKeepStreak: () {
              // User chose to keep streak - just close this dialog, don't start challenge
              Navigator.pop(context);
            },
            onStartChallenge: () {
              // User chose to start challenge - proceed normally
              // This dialog will continue to show the warning
            },
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.challengeWarningTitle(widget.duration),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Rules:',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(l10n.challengeWarningRule1),
              const SizedBox(height: 8),
              Text(l10n.challengeWarningRule2),
              const SizedBox(height: 8),
              Text(l10n.challengeWarningRule4(widget.duration)),
              const SizedBox(height: 8),
              Text(l10n.challengeWarningRule5(widget.duration)),
              const SizedBox(height: 24),
              Text(
                'Rewards:',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (widget.isPremiumUser) ...[
                Text(l10n.challengeRewardBadge),
                const SizedBox(height: 8),
                Text(l10n.challengeRewardTitle),
                const SizedBox(height: 8),
                Text(l10n.challengeRewardNotification),
              ] else ...[
                Text(l10n.challengeRewardFreeQuestions(1)),
                if (widget.duration == 14) ...[
                  const SizedBox(height: 8),
                  Text(l10n.challengeRewardFreeCategories(1)),
                ],
              ],
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      child: Text(l10n.challengeWarningCancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isLoading ? null : _start,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.challengeWarningStart),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
