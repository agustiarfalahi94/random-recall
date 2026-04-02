import 'package:flutter/material.dart';

import '../../core/database/database_helper.dart';
import '../../models/category.dart';
import '../../models/question.dart';

class AddEditQuestionScreen extends StatefulWidget {
  /// Pass an existing question to edit, or null to add a new one.
  final Question? question;

  const AddEditQuestionScreen({super.key, this.question});

  @override
  State<AddEditQuestionScreen> createState() => _AddEditQuestionScreenState();
}

class _AddEditQuestionScreenState extends State<AddEditQuestionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _questionController;
  late final TextEditingController _answerController;

  List<Category> _categories = [];
  int? _selectedCategoryId;
  bool _isLoading = false;
  bool _isSaving = false;

  bool get _isEditing => widget.question != null;

  @override
  void initState() {
    super.initState();
    _questionController =
        TextEditingController(text: widget.question?.question ?? '');
    _answerController =
        TextEditingController(text: widget.question?.answer ?? '');
    _selectedCategoryId = widget.question?.categoryId;
    _loadCategories();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    final categories = await DatabaseHelper.instance.getAllCategories();
    setState(() {
      _categories = categories;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    try {
      final db = DatabaseHelper.instance;
      if (_isEditing) {
        await db.updateQuestion(
          widget.question!.copyWith(
            question: _questionController.text.trim(),
            answer: _answerController.text.trim(),
            categoryId: _selectedCategoryId,
          ),
        );
      } else {
        await db.insertQuestion(
          Question(
            question: _questionController.text.trim(),
            answer: _answerController.text.trim(),
            categoryId: _selectedCategoryId!,
            createdAt: DateTime.now(),
          ),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true); // true = data changed
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Question' : 'New Question'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Question ──────────────────────────────────────────
                    _FieldLabel(
                        label: 'Question', colorScheme: colorScheme),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _questionController,
                      maxLines: 4,
                      minLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText:
                            'e.g. When cooking fried rice, what to add last?',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a question';
                        }
                        if (value.trim().length < 5) {
                          return 'Question is too short';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // ── Answer ────────────────────────────────────────────
                    _FieldLabel(
                        label: 'Answer', colorScheme: colorScheme),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _answerController,
                      maxLines: 4,
                      minLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Soy sauce and sesame oil',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an answer';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // ── Category ──────────────────────────────────────────
                    _FieldLabel(
                        label: 'Category', colorScheme: colorScheme),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: _selectedCategoryId,
                      decoration: const InputDecoration(
                        hintText: 'Select a category',
                      ),
                      borderRadius: BorderRadius.circular(12),
                      items: _categories.map((cat) {
                        return DropdownMenuItem<int>(
                          value: cat.id,
                          child: Row(
                            children: [
                              Text(cat.icon,
                                  style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 10),
                              Text(cat.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedCategoryId = value),
                      validator: (value) {
                        if (value == null) return 'Please select a category';
                        return null;
                      },
                    ),

                    const SizedBox(height: 40),

                    // ── Save button ───────────────────────────────────────
                    ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_isEditing
                              ? 'Save Changes'
                              : 'Add Question'),
                    ),
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
