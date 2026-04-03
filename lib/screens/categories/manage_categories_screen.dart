import 'package:flutter/material.dart';

import '../../core/database/database_helper.dart';
import '../../core/plan/plan_service.dart';
import '../../models/category.dart';
import '../../widgets/upgrade_bottom_sheet.dart';

// ── Available icons for category picker ──────────────────────────────────────
// Curated list covering the most common personal knowledge areas.
const _categoryIcons = [
  '📌', '💼', '🍳', '☕', '📚', '🎵', '💪', '🌍', '💻', '🎨',
  '🏠', '❤️', '🌱', '✈️', '🎮', '💰', '🔬', '🎭', '🚗', '⚽',
  '🧘', '🍕', '📷', '🎯', '🧠', '🌙', '🔑', '🛒', '🐶', '🎁',
];

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  List<Category> _customCategories = []; // non-default categories — shown in list
  Set<int> _usedCategoryIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = DatabaseHelper.instance;
    final categories = await db.getAllCategories();
    final usedIds = await db.getUsedCategoryIds();
    setState(() {
      _customCategories = categories.where((c) => !c.isDefault).toList();
      _usedCategoryIds = usedIds;
      _isLoading = false;
    });
  }

  Future<void> _openAddSheet() async {
    // Check creation limit — only custom (non-default) categories count
    final canAdd = await PlanService.canAddCategory(_customCategories.length);
    if (!mounted) return;
    if (!canAdd) {
      UpgradeBottomSheet.show(context, trigger: UpgradeTrigger.categoryLimit);
      return;
    }

    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddCategorySheet(usedCategoryIds: _usedCategoryIds),
    );
    if (added == true) _loadData();
  }

  Future<void> _deleteCategory(Category cat) async {
    // Can't delete a category that has questions — guard it
    if (_usedCategoryIds.contains(cat.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${cat.name}" has questions. Delete or move them first.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          'Delete "${cat.icon} ${cat.name}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseHelper.instance.deleteCategory(cat.id!);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Categories',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Free-tier info banner
                FutureBuilder<bool>(
                  future: PlanService.isPremium(),
                  builder: (_, snap) {
                    if (snap.data == true) return const SizedBox.shrink();
                    final atCreationLimit = _customCategories.length >=
                        PlanService.freeMaxCustomCategories;
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: atCreationLimit
                            ? colorScheme.errorContainer
                            : colorScheme.primaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        atCreationLimit
                            ? 'Free plan: you\'ve used your 1 custom category slot. '
                                'Upgrade to Premium for unlimited categories.'
                            : 'Free plan: you can add 1 custom category. '
                                'Default categories (General, Work) don\'t count against this.',
                        style: TextStyle(
                          fontSize: 13,
                          color: atCreationLimit
                              ? colorScheme.onErrorContainer
                              : colorScheme.onPrimaryContainer,
                          height: 1.4,
                        ),
                      ),
                    );
                  },
                ),

                // Custom category list (default categories are hidden here)
                Expanded(
                  child: _customCategories.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('🏷️',
                                    style: const TextStyle(fontSize: 48)),
                                const SizedBox(height: 16),
                                Text(
                                  'No custom categories yet',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'General and Work are built-in. '
                                  'Tap the button below to create your own.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                          itemCount: _customCategories.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, index) {
                            final cat = _customCategories[index];
                            final hasQuestions =
                                _usedCategoryIds.contains(cat.id);
                            return _CategoryTile(
                              category: cat,
                              hasQuestions: hasQuestions,
                              onDelete: () => _deleteCategory(cat),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FutureBuilder<bool>(
        future: PlanService.canAddCategory(_customCategories.length),
        builder: (_, snap) {
          final canAdd = snap.data ?? true;
          return FloatingActionButton.extended(
            onPressed: _openAddSheet,
            icon: Icon(canAdd ? Icons.add_rounded : Icons.lock_rounded),
            label: Text(canAdd ? 'New Category' : 'Limit Reached'),
            backgroundColor: canAdd
                ? colorScheme.primary
                : colorScheme.surfaceContainerHigh,
            foregroundColor: canAdd
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
          );
        },
      ),
    );
  }
}

// ── Category tile ─────────────────────────────────────────────────────────────

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.hasQuestions,
    required this.onDelete,
  });

  final Category category;
  final bool hasQuestions;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  category.icon,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (hasQuestions)
                    Text(
                      'Has questions',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                    )
                  else
                    Text(
                      'Empty — safe to delete',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: hasQuestions
                    ? colorScheme.onSurface.withOpacity(0.3)
                    : colorScheme.error,
              ),
              tooltip: hasQuestions ? 'Cannot delete — has questions' : 'Delete',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add category bottom sheet ─────────────────────────────────────────────────

class _AddCategorySheet extends StatefulWidget {
  const _AddCategorySheet({required this.usedCategoryIds});
  final Set<int> usedCategoryIds;

  @override
  State<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends State<_AddCategorySheet> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedIcon = '📌';
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    try {
      await DatabaseHelper.instance.insertCategory(
        Category(
          name: _nameController.text.trim(),
          icon: _selectedIcon,
          createdAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 20),

            Text(
              'New Category',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),

            // Icon picker
            Text(
              'ICON',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categoryIcons.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final icon = _categoryIcons[i];
                  final selected = icon == _selectedIcon;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = icon),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: selected
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(10),
                        border: selected
                            ? Border.all(
                                color: colorScheme.primary, width: 2)
                            : null,
                      ),
                      child: Center(
                        child: Text(icon,
                            style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // Name field
            Text(
              'NAME',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. Cooking, Travel, Finance…',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter a category name';
                }
                if (v.trim().length < 2) return 'Name is too short';
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Free-plan note
            FutureBuilder<bool>(
              future: PlanService.isPremium(),
              builder: (_, snap) {
                final isPremium = snap.data ?? false;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isPremium
                            ? Icons.workspace_premium_rounded
                            : Icons.info_outline_rounded,
                        size: 16,
                        color: isPremium
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isPremium
                              ? 'Premium — create as many categories as you like!'
                              : 'Free plan: ${PlanService.freeMaxCustomCategories} custom '
                                  'category allowed (General & Work are built-in). '
                                  'Upgrade to Premium for unlimited.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isPremium
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text('$_selectedIcon  Create Category'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
