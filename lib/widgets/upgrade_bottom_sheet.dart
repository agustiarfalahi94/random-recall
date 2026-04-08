import 'package:flutter/material.dart';
import '../screens/settings/subscription_screen.dart';

enum UpgradeTrigger { questionLimit, categoryLimit }

class UpgradeBottomSheet extends StatelessWidget {
  const UpgradeBottomSheet({super.key, required this.trigger});

  final UpgradeTrigger trigger;

  static Future<void> show(
    BuildContext context, {
    required UpgradeTrigger trigger,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => UpgradeBottomSheet(trigger: trigger),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final title = trigger == UpgradeTrigger.questionLimit
        ? 'Question Limit Reached'
        : 'Category Limit Reached';

    final description = trigger == UpgradeTrigger.questionLimit
        ? 'Free accounts can store up to 20 questions '
            '(+ bonus slots from your streak). '
            'Upgrade to Premium for unlimited questions.'
        : 'Free accounts can add questions to up to 2 categories. '
            'Upgrade to Premium to use all categories without limits.';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
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
          const SizedBox(height: 24),

          // Lock icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.lock_rounded,
              size: 32,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // What's included in premium
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: colorScheme.outlineVariant.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Premium includes:',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 10),
                for (final perk in [
                  '✅ Unlimited questions',
                  '✅ All categories',
                  '✅ Full analytics breakdown',
                  '✅ Undo wrong answer (rewarded)',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      perk,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Subscribe button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SubscriptionScreen(),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Upgrade to Premium'),
            ),
          ),

          const SizedBox(height: 8),

          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Maybe later'),
          ),
        ],
      ),
    );
  }
}
