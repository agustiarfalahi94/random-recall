import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/database/database_helper.dart';
import '../../core/plan/plan_service.dart';
import '../../models/category.dart';
import '../settings/subscription_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List<Map<String, dynamic>> _stats = [];
  int _totalAnswered = 0;
  int _totalCorrect = 0;
  bool _isLoading = true;
  bool _isPremium = false;

  StreamSubscription? _dbSubscription;
  Timer? _refreshDebounce;

  @override
  void initState() {
    super.initState();
    _loadStats();
    // Listen for database updates (local or cloud-synced) to refresh the UI automatically
    _dbSubscription = DatabaseHelper.instance.onDatabaseUpdated.listen((_) {
      if (_refreshDebounce?.isActive ?? false) _refreshDebounce!.cancel();
      _refreshDebounce = Timer(const Duration(milliseconds: 500), () {
        if (mounted) _loadStats();
      });
    });
  }

  @override
  void dispose() {
    _dbSubscription?.cancel();
    _refreshDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final stats = await DatabaseHelper.instance.getCategoryScoreStats();
    final premium = await PlanService.isPremium();
    int totalAnswered = 0;
    int totalCorrect = 0;
    for (final s in stats) {
      totalAnswered += s['total'] as int;
      totalCorrect += s['correct'] as int;
    }
    setState(() {
      _stats = stats;
      _totalAnswered = totalAnswered;
      _totalCorrect = totalCorrect;
      _isPremium = premium;
      _isLoading = false;
    });
  }

  double get _overallPercentage =>
      _totalAnswered > 0 ? (_totalCorrect / _totalAnswered) * 100 : 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_totalAnswered == 0) {
      return _buildEmptyState(theme, colorScheme);
    }

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // ── Overall score card ─────────────────────────────────────────
          _OverallScoreCard(
            totalAnswered: _totalAnswered,
            totalCorrect: _totalCorrect,
            percentage: _overallPercentage,
            colorScheme: colorScheme,
            theme: theme,
          ),

          const SizedBox(height: 24),

          // ── Per-category breakdown ─────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'By Category',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  if (!_isPremium) _LockBadge(colorScheme: colorScheme),
                ],
              ),
              const SizedBox(height: 12),
              if (!_isPremium)
                _LockedCategorySection(stats: _stats, colorScheme: colorScheme, theme: theme)
              else
                ..._stats.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CategoryScoreCard(stat: s, colorScheme: colorScheme, theme: theme),
                    )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📊', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 24),
            Text(
              'No data yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Answer some questions first and your stats will appear here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Overall score card ────────────────────────────────────────────────────────

class _OverallScoreCard extends StatelessWidget {
  const _OverallScoreCard({
    required this.totalAnswered,
    required this.totalCorrect,
    required this.percentage,
    required this.colorScheme,
    required this.theme,
  });

  final int totalAnswered;
  final int totalCorrect;
  final double percentage;
  final ColorScheme colorScheme;
  final ThemeData theme;

  String get _emoji {
    if (percentage >= 80) return '🔥';
    if (percentage >= 60) return '💪';
    if (percentage >= 40) return '📚';
    return '🌱';
  }

  String get _label {
    if (percentage >= 80) return 'Outstanding!';
    if (percentage >= 60) return 'Good progress!';
    if (percentage >= 40) return 'Keep going!';
    return 'Just getting started';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overall Score',
                    style: TextStyle(
                      color: colorScheme.onPrimary.withOpacity(0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _label,
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Big percentage
          Text(
            '${percentage.toStringAsFixed(0)}%',
            style: TextStyle(
              color: colorScheme.onPrimary,
              fontSize: 56,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),

          const SizedBox(height: 8),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: colorScheme.onPrimary.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
              minHeight: 8,
            ),
          ),

          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              _StatPill(
                label: 'Answered',
                value: '$totalAnswered',
                colorScheme: colorScheme,
              ),
              const SizedBox(width: 10),
              _StatPill(
                label: 'Correct',
                value: '$totalCorrect',
                colorScheme: colorScheme,
              ),
              const SizedBox(width: 10),
              _StatPill(
                label: 'Wrong',
                value: '${totalAnswered - totalCorrect}',
                colorScheme: colorScheme,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.colorScheme,
  });
  final String label;
  final String value;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.onPrimary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onPrimary.withOpacity(0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category score card ───────────────────────────────────────────────────────

class _CategoryScoreCard extends StatelessWidget {
  const _CategoryScoreCard({
    required this.stat,
    required this.colorScheme,
    required this.theme,
  });

  final Map<String, dynamic> stat;
  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final category = stat['category'] as Category;
    final total = stat['total'] as int;
    final correct = stat['correct'] as int;
    final percentage = stat['percentage'] as double;
    final wrong = total - correct;

    // Color based on performance
    final Color progressColor;
    if (percentage >= 80) {
      progressColor = Colors.green;
    } else if (percentage >= 50) {
      progressColor = Colors.orange;
    } else {
      progressColor = colorScheme.error;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(category.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  category.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: progressColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 6,
            ),
          ),

          const SizedBox(height: 10),

          // Stats
          Row(
            children: [
              _MiniStat(
                  label: 'Total', value: '$total', colorScheme: colorScheme),
              const SizedBox(width: 16),
              _MiniStat(
                  label: '✅ Correct',
                  value: '$correct',
                  colorScheme: colorScheme),
              const SizedBox(width: 16),
              _MiniStat(
                  label: '❌ Wrong',
                  value: '$wrong',
                  colorScheme: colorScheme),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.colorScheme,
  });
  final String label;
  final String value;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
            fontSize: 15,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ── Locked section for free users ─────────────────────────────────────────────

class _LockBadge extends StatelessWidget {
  const _LockBadge({required this.colorScheme});
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_rounded,
              size: 12, color: colorScheme.onTertiaryContainer),
          const SizedBox(width: 4),
          Text(
            'Premium',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedCategorySection extends StatelessWidget {
  const _LockedCategorySection({
    required this.stats,
    required this.colorScheme,
    required this.theme,
  });

  final List<Map<String, dynamic>> stats;
  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Lock CTA — Pinned at the top of the section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.5),
            ),
          ),
          child: Column(
            children: [
              const Text('🔒', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 12),
              Text(
                'Unlock Category Analytics',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'See exactly which categories you struggle with.\nSubscribe to unlock full analytics.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SubscriptionScreen(),
                      ),
                    );
                  },
                  child: const Text('Subscribe to Unlock'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Blurred preview cards below the CTA
        ClipRect(
          child: Stack(
            children: [
              // Cards underneath
              Column(
                children: stats
                    .take(2)
                    .map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CategoryScoreCard(
                            stat: s,
                            colorScheme: colorScheme,
                            theme: theme,
                          ),
                        ))
                    .toList(),
              ),
              // Blur + tint overlay
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                  child: Container(
                    color: colorScheme.surface.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
