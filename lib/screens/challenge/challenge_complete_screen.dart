import 'package:flutter/material.dart';
import 'package:random_recall/l10n/app_localizations.dart';

class ChallengeCompleteScreen extends StatelessWidget {
  final int duration; // 7 or 14 days
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
                // Header
                Column(
                  children: [
                    const SizedBox(height: 24),
                    const Text(
                      '🎉',
                      style: TextStyle(fontSize: 80),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Challenge Complete!',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You completed the $duration-day challenge!',
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.onPrimaryContainer.withOpacity(0.85),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),

                // Rewards Section
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rewards Earned:',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Question slots
                          if (questionsEarned > 0) ...[
                            Row(
                              children: [
                                const Text(
                                  '✨',
                                  style: TextStyle(fontSize: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '+$questionsEarned Question Slot${questionsEarned > 1 ? 's' : ''}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      Text(
                                        'Permanently unlock more questions',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color:
                                              colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Category slots
                          if (categoriesEarned > 0) ...[
                            Row(
                              children: [
                                const Text(
                                  '🎯',
                                  style: TextStyle(fontSize: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '+$categoriesEarned Category Slot${categoriesEarned > 1 ? 's' : ''}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      Text(
                                        'Create more custom categories',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color:
                                              colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Badge
                          if (isBadgeUnlocked) ...[
                            Row(
                              children: [
                                const Text(
                                  '🏆',
                                  style: TextStyle(fontSize: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Challenge Badge Unlocked',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      Text(
                                        'Show off your achievement',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color:
                                              colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Title
                          if (title != null && title!.isNotEmpty) ...[
                            Row(
                              children: [
                                const Text(
                                  '👑',
                                  style: TextStyle(fontSize: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Title: $title',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      Text(
                                        'Premium exclusive achievement',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color:
                                              colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                // Back button
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
