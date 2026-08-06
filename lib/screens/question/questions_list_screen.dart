import 'dart:async';

import 'package:flutter/material.dart';
import 'package:random_recall/l10n/app_localizations.dart';

import '../../core/config/remote_config_service.dart';
import '../../core/database/database_helper.dart';
import '../../core/plan/plan_service.dart';
import '../../models/category.dart';
import '../../models/question.dart';
import '../../widgets/upgrade_bottom_sheet.dart';
import '../categories/manage_categories_screen.dart';
import '../settings/subscription_screen.dart';
import 'add_edit_question_screen.dart';

class QuestionsListScreen extends StatefulWidget {
  const QuestionsListScreen({super.key});

  @override
  State<QuestionsListScreen> createState() => _QuestionsListScreenState();
}

class _QuestionsListScreenState extends State<QuestionsListScreen> {
  List<Question> _questions = [];
  List<Category> _categories = [];
  bool _isLoading = true;
  int? _selectedCategoryId; // null = show all

  // Plan limits
  int _totalQuestionCount = 0;
  int _questionLimit = PlanService.freeQuestionBase;
  bool _isPremium = false;

  StreamSubscription? _dbSubscription;
  Timer? _refreshDebounce;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Listen for database changes (local or synced) to refresh the list automatically
    _dbSubscription = DatabaseHelper.instance.onDatabaseUpdated.listen((_) {
      if (_refreshDebounce?.isActive ?? false) _refreshDebounce!.cancel();
      _refreshDebounce = Timer(const Duration(milliseconds: 500), () {
        if (mounted) _loadData();
      });
    });
  }

  @override
  void dispose() {
    _dbSubscription?.cancel();
    _refreshDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = DatabaseHelper.instance;
    final questions = await db.getAllQuestions(categoryId: _selectedCategoryId);
    final categories = await db.getAllCategories();
    final totalCount = await db.getQuestionCount();
    final limit = await PlanService.getQuestionLimit();
    final premium = await PlanService.isPremium();
    setState(() {
      _questions = questions;
      _categories = categories;
      _totalQuestionCount = totalCount;
      _questionLimit = limit;
      _isPremium = premium;
      _isLoading = false;
    });
  }

  Future<void> _deleteQuestion(Question question) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteQuestionTitle),
        content: Text(
          '"${question.question}"',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.deleteQuestion(question.id!);
      _loadData();
    }
  }

  Future<void> _openAddEdit({Question? question}) async {
    // When adding (not editing), enforce the question limit
    if (question == null) {
      final canAdd = await PlanService.canAddQuestion(_totalQuestionCount);
      if (!canAdd) {
        if (!mounted) return;
        await UpgradeBottomSheet.show(
          context,
          trigger: UpgradeTrigger.questionLimit,
        );
        return;
      }
    }

    if (!mounted) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddEditQuestionScreen(question: question),
      ),
    );
    if (result == true) _loadData();
  }

  /// Shows a bottom sheet with two choices: Add Question or Add Category.
  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),

                // Add new question
                _AddMenuTile(
                  icon: Icons.quiz_outlined,
                  iconColor: colorScheme.primary,
                  iconBg: colorScheme.primaryContainer,
                  title: AppLocalizations.of(ctx)!.newQuestionMenuTitle,
                  subtitle: AppLocalizations.of(ctx)!.newQuestionMenuSubtitle,
                  onTap: () {
                    Navigator.pop(ctx);
                    _openAddEdit();
                  },
                ),

                const SizedBox(height: 12),

                // Add new category
                _AddMenuTile(
                  icon: Icons.label_outline_rounded,
                  iconColor: colorScheme.tertiary,
                  iconBg: colorScheme.tertiaryContainer,
                  title: AppLocalizations.of(ctx)!.newCategoryMenuTitle,
                  subtitle: AppLocalizations.of(ctx)!.newCategoryMenuSubtitle,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ManageCategoriesScreen(),
                      ),
                    );
                    _loadData();
                  },
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Category? _categoryFor(int categoryId) {
    try {
      return _categories.firstWhere((c) => c.id == categoryId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine pill color: red at limit, amber at warning for premium
    final isAtLimit = _totalQuestionCount >= _questionLimit;
    final isAtWarning =
        _isPremium &&
        _totalQuestionCount >=
            RemoteConfigService.instance.questionWarningThreshold;
    final pillIsError = isAtLimit;
    final pillIsWarning = isAtWarning && !isAtLimit;

    return Scaffold(
      body: Column(
        children: [
          // ── Question count pill ────────────────────────────────────────
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: pillIsError
                          ? colorScheme.errorContainer
                          : pillIsWarning
                          ? colorScheme.tertiaryContainer
                          : colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          pillIsError
                              ? Icons.lock_rounded
                              : Icons.library_books_outlined,
                          size: 13,
                          color: pillIsError
                              ? colorScheme.onErrorContainer
                              : pillIsWarning
                              ? colorScheme.onTertiaryContainer
                              : colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          pillIsError
                              ? l10n.questionLimitReached(
                                  _totalQuestionCount,
                                  _questionLimit,
                                )
                              : pillIsWarning
                              ? l10n.questionWarning(
                                  _totalQuestionCount,
                                  _questionLimit,
                                )
                              : l10n.questionCount(
                                  _totalQuestionCount,
                                  _questionLimit,
                                ),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: pillIsError
                                ? colorScheme.onErrorContainer
                                : pillIsWarning
                                ? colorScheme.onTertiaryContainer
                                : colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (pillIsError && !_isPremium) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SubscriptionScreen(),
                        ),
                      ),
                      child: Text(
                        l10n.upgradeButton,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // ── Category filter chips ──────────────────────────────────────
          if (_categories.isNotEmpty)
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                children: [
                  // "All" chip
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(l10n.all),
                      selected: _selectedCategoryId == null,
                      showCheckmark: false,
                      onSelected: (_) {
                        setState(() => _selectedCategoryId = null);
                        _loadData();
                      },
                      selectedColor: colorScheme.primaryContainer,
                      labelStyle: TextStyle(
                        color: _selectedCategoryId == null
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                        fontWeight: _selectedCategoryId == null
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  // Category chips
                  ..._categories.map((cat) {
                    final isSelected = _selectedCategoryId == cat.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text('${cat.icon} ${cat.name}'),
                        selected: isSelected,
                        showCheckmark: false,
                        onSelected: (_) {
                          setState(
                            () => _selectedCategoryId = isSelected
                                ? null
                                : cat.id,
                          );
                          _loadData();
                        },
                        selectedColor: colorScheme.primaryContainer,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurfaceVariant,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

          // ── Questions list ─────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _questions.isEmpty
                ? _buildEmptyState(colorScheme, theme)
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: _questions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final q = _questions[index];
                        final cat = _categoryFor(q.categoryId);
                        return _QuestionCard(
                          question: q,
                          category: cat,
                          onEdit: () => _openAddEdit(question: q),
                          onDelete: () => _deleteQuestion(q),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: pillIsError ? null : _showAddMenu,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        tooltip: l10n.addTooltip,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📝', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 24),
            Text(
              _selectedCategoryId != null
                  ? l10n.noQuestionsInCategory
                  : l10n.noQuestionsYet,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.tapToAddFirst,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add menu tile ─────────────────────────────────────────────────────────────

class _AddMenuTile extends StatelessWidget {
  const _AddMenuTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Question card ─────────────────────────────────────────────────────────────

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  final Question question;
  final Category? category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Dismissible(
      key: Key('question_${question.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_rounded, color: colorScheme.onErrorContainer),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // We handle deletion manually in onDelete
      },
      child: Card(
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category badge
                if (category != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${category!.icon} ${category!.name}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),

                // Question text
                Text(
                  question.question,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 6),

                // Answer preview
                Text(
                  question.answer,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 10),

                // Action row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Edit
                    IconButton.outlined(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: AppLocalizations.of(context)!.edit,
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(6),
                        minimumSize: const Size(32, 32),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Delete
                    IconButton.outlined(
                      onPressed: onDelete,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: colorScheme.error,
                      ),
                      tooltip: AppLocalizations.of(context)!.delete,
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(6),
                        minimumSize: const Size(32, 32),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
