import 'package:flutter/material.dart';

import '../../core/database/database_helper.dart';
import '../../models/category.dart';
import '../../models/question.dart';
import '../../models/score_record.dart';

class QuestionScreen extends StatefulWidget {
  /// Pass a specific questionId when coming from a notification tap.
  /// If null, a random question is loaded.
  final int? questionId;

  const QuestionScreen({super.key, this.questionId});

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen>
    with SingleTickerProviderStateMixin {
  Question? _question;
  Category? _category;
  bool _isLoading = true;
  bool _answerRevealed = false;
  bool _graded = false;
  bool _isCorrect = false;

  late final AnimationController _revealController;
  late final Animation<double> _revealAnim;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _revealAnim = CurvedAnimation(
      parent: _revealController,
      curve: Curves.easeOutCubic,
    );
    _loadQuestion();
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestion() async {
    setState(() => _isLoading = true);
    try {
      final db = DatabaseHelper.instance;
      Question? question;

      if (widget.questionId != null) {
        question = await db.getQuestionById(widget.questionId!);
      }
      // Fallback to random if no id given or question not found
      question ??= await db.getRandomQuestion();

      Category? category;
      if (question != null) {
        category = await db.getCategoryById(question.categoryId);
      }

      setState(() {
        _question = question;
        _category = category;
        _isLoading = false;
        _answerRevealed = false;
        _graded = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _revealAnswer() {
    setState(() => _answerRevealed = true);
    _revealController.forward();
  }

  Future<void> _grade(bool isCorrect) async {
    if (_graded || _question == null) return;
    setState(() {
      _graded = true;
      _isCorrect = isCorrect;
    });

    await DatabaseHelper.instance.insertScoreRecord(ScoreRecord(
      questionId: _question!.id!,
      categoryId: _question!.categoryId,
      isCorrect: isCorrect,
      answeredAt: DateTime.now(),
    ));
  }

  void _nextQuestion() {
    _revealController.reset();
    _loadQuestion();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: _category != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_category!.icon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(_category!.name),
                ],
              )
            : const Text('Random Recall'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Next question button
          IconButton(
            icon: const Icon(Icons.skip_next_rounded),
            tooltip: 'Skip to next question',
            onPressed: _isLoading ? null : _nextQuestion,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _question == null
              ? _buildEmptyState(colorScheme, theme)
              : _buildContent(colorScheme, theme),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📭', style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 24),
            Text(
              'No questions yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add some questions first from the Questions tab.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme colorScheme, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),

          // ── Question card ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'QUESTION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onPrimary,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _question!.question,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Reveal button or answer ──────────────────────────────────────
          if (!_answerRevealed)
            ElevatedButton.icon(
              onPressed: _revealAnswer,
              icon: const Icon(Icons.visibility_rounded),
              label: const Text('Reveal Answer'),
            )
          else ...[
            // Answer card with fade-in animation
            FadeTransition(
              opacity: _revealAnim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.1),
                  end: Offset.zero,
                ).animate(_revealAnim),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorScheme.secondary.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.secondary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'ANSWER',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSecondary,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _question!.answer,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Grade buttons or result ──────────────────────────────────
            if (!_graded) ...[
              Text(
                'Did you know it?',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  // ❌ Didn't know it
                  Expanded(
                    child: _GradeButton(
                      label: "Didn't know it",
                      emoji: '❌',
                      color: colorScheme.errorContainer,
                      textColor: colorScheme.onErrorContainer,
                      onTap: () => _grade(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // ✅ Knew it
                  Expanded(
                    child: _GradeButton(
                      label: 'I knew it!',
                      emoji: '✅',
                      color: const Color(0xFFD4EDDA),
                      textColor: const Color(0xFF155724),
                      onTap: () => _grade(true),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Result feedback
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _isCorrect
                      ? const Color(0xFFD4EDDA)
                      : colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Text(
                      _isCorrect ? '🎉' : '💪',
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isCorrect ? 'Great job!' : 'Keep practicing!',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: _isCorrect
                                  ? const Color(0xFF155724)
                                  : colorScheme.onErrorContainer,
                            ),
                          ),
                          Text(
                            _isCorrect
                                ? 'Score recorded ✓'
                                : "You'll get it next time",
                            style: TextStyle(
                              fontSize: 13,
                              color: _isCorrect
                                  ? const Color(0xFF155724)
                                  : colorScheme.onErrorContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Next question button
              ElevatedButton.icon(
                onPressed: _nextQuestion,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Next Question'),
              ),

              const SizedBox(height: 12),

              // Back to home
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to Home'),
              ),
            ],
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Grade button widget ───────────────────────────────────────────────────────

class _GradeButton extends StatelessWidget {
  const _GradeButton({
    required this.label,
    required this.emoji,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final String emoji;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: textColor,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
