import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/database_helper.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/plan/plan_service.dart';
import '../../core/streak/streak_service.dart';
import '../../models/category.dart';
import '../../models/question.dart';
import '../../models/score_record.dart';

/// Shown when the user taps a notification (organic or test).
/// No "next question" flow — grade once, see a brief toast, then app closes.
class NotificationQuestionScreen extends StatefulWidget {
  final int? questionId;

  /// When true (test notification), score and streak are NOT recorded.
  final bool isPractice;

  const NotificationQuestionScreen(
      {super.key, this.questionId, this.isPractice = false});

  @override
  State<NotificationQuestionScreen> createState() =>
      _NotificationQuestionScreenState();
}

class _NotificationQuestionScreenState
    extends State<NotificationQuestionScreen>
    with SingleTickerProviderStateMixin {
  Question? _question;
  Category? _category;
  bool _isLoading = true;
  bool _answerRevealed = false;
  bool _graded = false;
  bool _isCorrect = false;
  int? _lastScoreId;

  // Timer
  int _timerSeconds = 0;
  int _remaining = 0;
  bool _isPremium = false;
  bool _undoUsedToday = false;
  Timer? _countdownTimer;

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
    _loadInitialSettings();
    _loadQuestion();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _revealController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final premium = await PlanService.isPremium();
    final undoUsed = await PlanService.hasUsedUndoToday();
    if (mounted) {
      setState(() {
        _isPremium = premium;
        _undoUsedToday = undoUsed;
        _timerSeconds = prefs.getInt('notif_timer_seconds') ?? 0;
      });
    }
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    if (_timerSeconds <= 0) return;
    setState(() => _remaining = _timerSeconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _remaining--);
      if (_remaining <= 0) { t.cancel(); _grade(false); }
    });
  }

  void _stopTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  // Always pop — popUntil(isFirst) was called before pushing this screen,
  // so HomeScreen is always directly beneath.
  void _close() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      SystemNavigator.pop(); // edge case: cold start with no root yet
    }
  }

  Future<void> _loadQuestion() async {
    setState(() => _isLoading = true);
    try {
      final db = DatabaseHelper.instance;
      Question? question;

      if (widget.questionId != null) {
        question = await db.getQuestionById(widget.questionId!);
      }
      question ??= await db.getRandomQuestion();

      Category? category;
      if (question != null) {
        category = await db.getCategoryById(question.categoryId);
      }

      setState(() {
        _question = question;
        _category = category;
        _isLoading = false;
      });
      _startTimer();
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
    _stopTimer();
    setState(() {
      _graded = true;
      _isCorrect = isCorrect;
    });

    try {
      // Test notifications are practice — don't affect score or streak.
      if (!widget.isPractice) {
        final now = DateTime.now();
        _lastScoreId = await DatabaseHelper.instance.insertScoreRecord(ScoreRecord(
          questionId: _question!.id!,
          categoryId: _question!.categoryId,
          isCorrect: isCorrect,
          answeredAt: now,
          updatedAt: now,
        ));

        // Clear the persistent tray notification for this question.
        await NotificationService.instance.cancelNotificationsForQuestion(_question!.id!);

        // Update last-answer timestamp so the fallback badge count resets.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('last_answer_timestamp', now.millisecondsSinceEpoch);

        // Record streak only when timer is ON and ≤ the challenge threshold.
        if (_timerSeconds > 0 && _timerSeconds <= StreakService.challengeThreshold) {
          final result = await StreakService.recordActivity();
          if (result.milestoneReached && mounted) {
            await showDialog(
              context: context,
              builder: (_) => _StreakMilestoneDialog(streak: result.streak),
            );
          }
        }
      }
    } catch (_) {}

    // Auto-close logic:
    // Close if Correct OR if user is Free OR if Premium used their Undo already.
    // Tests sessions stay open on Wrong answers to allow unlimited Undo.
    if (_isCorrect || !_isPremium || (!widget.isPractice && _undoUsedToday)) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        _close();
      }
    }
  }

  Future<void> _undoGrade() async {
    if (!_graded || !_isPremium || (!widget.isPractice && _undoUsedToday)) return;

    try {
      // If it was a recorded score (not practice), delete it from local DB
      if (!widget.isPractice && _lastScoreId != null) {
        await DatabaseHelper.instance.deleteScoreRecord(_lastScoreId!);
      }
      
      if (!widget.isPractice) {
        await PlanService.consumeUndo();
      }
      
      setState(() {
        _graded = false;
        _isCorrect = false;
        _lastScoreId = null;
        if (!widget.isPractice) {
          _undoUsedToday = true;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Result undone. You can try again! ↩️')),
      );
    } catch (_) {}
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
          Expanded(child: Text(_category!.name, overflow: TextOverflow.ellipsis)),
                ],
              )
      : const Text('Random Recall'),
    leading: IconButton(
      icon: const Icon(Icons.close_rounded),
      onPressed: _close, // Use helper to handle pop vs system pop
    ),
        actions: [
          if (_timerSeconds > 0 && !_graded && !_isLoading)
            _TimerBadge(remaining: _remaining, total: _timerSeconds),
        ],
        // No skip/next button — notification flow is single question only
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
            const Text('📭', style: TextStyle(fontSize: 64)),
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
              onPressed: () => SystemNavigator.pop(),
              child: const Text('Close'),
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

          // ── Question card ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

          // ── Reveal button or answer ────────────────────────────────────────
          if (!_answerRevealed)
            ElevatedButton.icon(
              onPressed: _revealAnswer,
              icon: const Icon(Icons.visibility_rounded),
              label: const Text('Reveal Answer'),
            )
          else ...[
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
                        color: colorScheme.secondary.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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

            // ── Grade buttons or result toast ────────────────────────────────
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
              // Result feedback — shows for 2s then app closes
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
                            _isCorrect 
                                ? (widget.isPractice ? 'Closing in a moment...' : 'Score recorded! Closing in a moment...')
                                : (widget.isPractice ? 'Keep practicing!' : 'Score recorded! Keep practicing'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
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

              if (!_isCorrect && _isPremium && (widget.isPractice || !_undoUsedToday))
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _undoGrade,
                        icon: const Icon(Icons.undo_rounded, size: 18),
                        label: Text(widget.isPractice ? 'Undo' : 'Undo (only 1 use per day)'),
                      ),
                    ),
                  ],
                ),
            ],
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Streak milestone dialog ───────────────────────────────────────────────────

class _StreakMilestoneDialog extends StatelessWidget {
  const _StreakMilestoneDialog({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text(
            '$streak-Day Streak!',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ve answered with the timer on for $streak days straight. '
            'You earned +1 bonus question slot! 🎉',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Awesome!'),
        ),
      ],
    );
  }
}

// ── Timer badge ───────────────────────────────────────────────────────────────

class _TimerBadge extends StatelessWidget {
  const _TimerBadge({required this.remaining, required this.total});
  final int remaining;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? remaining / total : 0.0;
    final color = fraction > 0.5
        ? Colors.green
        : fraction > 0.25
            ? Colors.orange
            : Colors.red;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              strokeWidth: 3,
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Text(
            '$remaining',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Grade button widget ────────────────────────────────────────────────────────

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
