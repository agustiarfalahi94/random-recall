import 'package:flutter/material.dart';
import 'package:random_recall/l10n/app_localizations.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../core/plan/subscription_service.dart';
import '../../core/plan/plan_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = true;
  Offering? _offering;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final premium = await PlanService.isPremium();
    final offering = await SubscriptionService.instance.getOffering();
    if (mounted) {
      setState(() {
        _isPremium = premium;
        _offering = offering;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSubscribe(Package package) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      await SubscriptionService.instance.purchasePackage(package);
      if (await PlanService.isPremium() && mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.purchaseFailedSnack(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.upgradeToPremium)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isPremium
          ? _buildPremiumActive(theme, colorScheme)
          : _buildPaywall(theme, colorScheme),
    );
  }

  Widget _buildPaywall(ThemeData theme, ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text('💎', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            l10n.premiumUnlockTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.premiumUnlockSubtitle,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),

          _FeatureTile(
            icon: Icons.all_inclusive_rounded,
            title: l10n.featureUnlimitedQuestions,
            subtitle: l10n.featureUnlimitedQuestionsSubtitle,
            color: Colors.blue,
          ),
          _FeatureTile(
            icon: Icons.category_rounded,
            title: l10n.featureUnlimitedCategories,
            subtitle: l10n.featureUnlimitedCategoriesSubtitle,
            color: Colors.purple,
          ),
          _FeatureTile(
            icon: Icons.undo_rounded,
            title: l10n.featureUndoMistakes,
            subtitle: l10n.featureUndoMistakesSubtitle,
            color: Colors.redAccent,
          ),
          _FeatureTile(
            icon: Icons.analytics_rounded,
            title: l10n.featureAdvancedAnalytics,
            subtitle: l10n.featureAdvancedAnalyticsSubtitle,
            color: Colors.orange,
          ),
          _FeatureTile(
            icon: Icons.cloud_done_rounded,
            title: l10n.featureRealTimeSync,
            subtitle: l10n.featureRealTimeSyncSubtitle,
            color: Colors.green,
          ),

          const SizedBox(height: 48),

          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (_offering != null) ...[
                  for (var package in _offering!.availablePackages)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ElevatedButton(
                        onPressed: () => _handleSubscribe(package),
                        child: Text(
                          l10n.getPremiumButton(
                            package.storeProduct.priceString,
                          ),
                        ),
                      ),
                    ),
                ] else
                  Text(l10n.loadingPlans),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      SubscriptionService.instance.restorePurchases(),
                  child: Text(l10n.restorePurchase),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.cancelAnytime,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumActive(ThemeData theme, ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🌟', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 24),
            Text(
              l10n.premiumActiveMember,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(l10n.premiumActiveDesc, textAlign: TextAlign.center),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.premiumGreat),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
