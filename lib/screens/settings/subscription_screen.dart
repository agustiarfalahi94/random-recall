import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../core/plan/subscription_service.dart';
import '../../core/plan/plan_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = true;
  ProductDetails? _monthlyProduct;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final premium = await PlanService.isPremium();
    final product = await SubscriptionService.instance.getMonthlyProduct();
    if (mounted) {
      setState(() {
        _isPremium = premium;
        _monthlyProduct = product;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSubscribe() async {
    if (_monthlyProduct == null) return;
    setState(() => _isLoading = true);
    try {
      await SubscriptionService.instance.subscribe(_monthlyProduct!);
      // Note: UI will update via the purchase stream in SubscriptionService
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade to Premium')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isPremium 
              ? _buildPremiumActive(theme, colorScheme)
              : _buildPaywall(theme, colorScheme),
    );
  }

  Widget _buildPaywall(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text('💎', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'Unlock Full Potential',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Master your knowledge without limits.',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          
          _FeatureTile(
            icon: Icons.all_inclusive_rounded,
            title: 'Unlimited Questions',
            subtitle: 'Add as many facts as you need to remember.',
            color: Colors.blue,
          ),
          _FeatureTile(
            icon: Icons.category_rounded,
            title: 'Unlimited Categories',
            subtitle: 'Organize your learning into specific topics.',
            color: Colors.purple,
          ),
          _FeatureTile(
            icon: Icons.undo_rounded,
            title: 'Undo Mistakes',
            subtitle: 'Correct a wrong answer to keep your streak alive.',
            color: Colors.redAccent,
          ),
          _FeatureTile(
            icon: Icons.analytics_rounded,
            title: 'Advanced Analytics',
            subtitle: 'Identify your weak spots with per-category scoring.',
            color: Colors.orange,
          ),
          _FeatureTile(
            icon: Icons.cloud_done_rounded,
            title: 'Real-time Sync',
            subtitle: 'Seamless access across all your Android devices.',
            color: Colors.green,
          ),

          const SizedBox(height: 48),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Text(
                  _monthlyProduct?.price ?? '\$2.99',
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text('per month', style: theme.textTheme.bodySmall),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _handleSubscribe,
                  child: const Text('Subscribe Now'),
                ),
                TextButton(
                  onPressed: () => SubscriptionService.instance.restorePurchases(),
                  child: const Text('Restore Purchase'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Cancel anytime in Google Play Store. Settings > Subscriptions.',
            style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumActive(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🌟', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 24),
            Text('You are a Premium Member!', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Thank you for supporting Random Recall. Enjoy all features unlocked.', textAlign: TextAlign.center),
            const SizedBox(height: 32),
            OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Great!')),
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
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}