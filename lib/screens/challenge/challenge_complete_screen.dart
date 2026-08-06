import 'package:flutter/material.dart';
import 'package:random_recall/l10n/app_localizations.dart';

class ChallengeCompleteScreen extends StatelessWidget {
  final int duration;
  final int questionsEarned;
  final int categoriesEarned;
  final bool isBadgeUnlocked;
  final String? title;

  const ChallengeCompleteScreen({
    super.key,
    required this.duration,
    required this.questionsEarned,
    required this.categoriesEarned,
    required this.isBadgeUnlocked,
    this.title,
  });

  /// Localise the stored title key ('Challenger', 'Champion', 'Legend').
  String _localiseTitle(AppLocalizations l10n, String key) {
    switch (key) {
      case 'Legend':
        return l10n.challengeTitleLegend;
      case 'Champion':
        return l10n.challengeTitleChampion;
      default:
        return l10n.challengeTitleChallenger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer,
              colorScheme.secondaryContainer,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    const SizedBox(height: 24),
                    const Text('🎉', style: TextStyle(fontSize: 80)),
                    const SizedBox(height: 24),
                    Text(
                      l10n.challengeCompleteTitle,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.challengeCompletedDaysLabel(duration),
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.85,
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),

                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.challengeRewardsEarnedLabel,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),

                          if (questionsEarned > 0) ...[
                            _RewardRow(
                              emoji: '✨',
                              label: l10n.challengeRewardQuestionSlotsLabel(
                                questionsEarned,
                                questionsEarned > 1 ? 's' : '',
                              ),
                              description: l10n.challengeRewardQuestionsDesc,
                              colorScheme: colorScheme,
                            ),
                            const SizedBox(height: 16),
                          ],

                          if (categoriesEarned > 0) ...[
                            _RewardRow(
                              emoji: '🎯',
                              label: l10n.challengeRewardCategorySlotsLabel(
                                categoriesEarned,
                                categoriesEarned > 1 ? 's' : '',
                              ),
                              description: l10n.challengeRewardCategoriesDesc,
                              colorScheme: colorScheme,
                            ),
                            const SizedBox(height: 16),
                          ],

                          if (isBadgeUnlocked) ...[
                            _RewardRow(
                              emoji: '🏆',
                              label: l10n.challengeRewardBadgeUnlockedLabel,
                              description: l10n.challengeRewardBadgeDesc,
                              colorScheme: colorScheme,
                            ),
                            const SizedBox(height: 16),
                          ],

                          if (title != null && title!.isNotEmpty)
                            _RewardRow(
                              emoji: '👑',
                              label: l10n.challengeRewardTitleLabel(
                                _localiseTitle(l10n, title!),
                              ),
                              description: l10n.challengeRewardTitleDesc,
                              colorScheme: colorScheme,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(l10n.backToHome),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({
    required this.emoji,
    required this.label,
    required this.description,
    required this.colorScheme,
  });

  final String emoji;
  final String label;
  final String description;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
