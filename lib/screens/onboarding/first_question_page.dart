import 'package:flutter/material.dart';

import '../../core/database/database_helper.dart';
import '../../models/category.dart';

typedef OnFirstQuestionNext = void Function(
    String question, String answer, int categoryId);

class FirstQuestionPage extends StatefulWidget {
  const FirstQuestionPage({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  final OnFirstQuestionNext onNext;
  final VoidCallback onBack;

  @override
  State<FirstQuestionPage> createState() => _FirstQuestionPageState();
}

class _FirstQuestionPageState extends State<FirstQuestionPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final _answerController = TextEditingController();
  int? _selectedCategoryId;
  List<Category> _categories = [];
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final categories = await DatabaseHelper.instance.getAllCategories();
    // Pre-select "General" so the user doesn't have to pick manually
    final general = categories.where((c) => c.name == 'General').firstOrNull;
    setState(() {
      _categories = categories;
      _selectedCategoryId = general?.id ?? (categories.isNotEmpty ? categories.first.id : null);
      _isLoadingCategories = false;
    });
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onNext(
        _questionController.text.trim(),
        _answerController.text.trim(),
        _selectedCategoryId!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // ── Back button ─────────────────────────────────────────────────
              TextButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                label: const Text('Back'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),

              const SizedBox(height: 16),
              _StepIndicator(currentStep: 2, totalSteps: 3, colorScheme: colorScheme),
              const SizedBox(height: 28),
              Text(
                'Your first question',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add something you want to remember. You can add more later.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),

              _FieldLabel(label: 'Question', colorScheme: colorScheme),
              const SizedBox(height: 8),
              TextFormField(
                controller: _questionController,
                maxLines: 3,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'e.g. What is the capital of France?',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Please enter a question';
                  if (value.trim().length < 5) return 'Question is too short';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              _FieldLabel(label: 'Answer', colorScheme: colorScheme),
              const SizedBox(height: 8),
              TextFormField(
                controller: _answerController,
                maxLines: 3,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'e.g. Paris'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Please enter an answer';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              _FieldLabel(label: 'Category', colorScheme: colorScheme),
              const SizedBox(height: 8),

              if (_isLoadingCategories)
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                DropdownButtonFormField<int>(
                  value: _selectedCategoryId,
                  decoration: const InputDecoration(hintText: 'Select a category'),
                  borderRadius: BorderRadius.circular(12),
                  items: _categories
                      .map((cat) => DropdownMenuItem<int>(
                            value: cat.id,
                            child: Row(
                              children: [
                                Text(cat.icon, style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 10),
                                Text(cat.name),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedCategoryId = value),
                  validator: (value) {
                    if (value == null) return 'Please select a category';
                    return null;
                  },
                ),

              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Next →'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.colorScheme});
  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurfaceVariant,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.currentStep,
    required this.totalSteps,
    required this.colorScheme,
  });
  final int currentStep;
  final int totalSteps;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        final isActive = index < currentStep;
        final isCurrent = index == currentStep - 1;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index < totalSteps - 1 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: isActive
                  ? (isCurrent ? colorScheme.primary : colorScheme.primaryContainer)
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}
