import 'dart:async';

import 'package:flutter/material.dart';
import 'package:random_recall/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/ads/ad_service.dart';
import '../../core/database/database_helper.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/plan/plan_service.dart';
import '../../core/services/analytics_service.dart';
import '../../core/streak/streak_service.dart';
import '../../models/category.dart';
import '../../models/question.dart';
import '../../models/score_record.dart';
import '../challenge/challenge_complete_screen.dart';

class QuestionScreen extends StatefulWidget {
  /// Pass a specific questionId when coming from a notification tap.
  /// If null, a random question is loaded.
  final int? questionId;

  /// When true the session is a free-practice run — scores and streak are
  /// NOT recorded so the user can drill freely without affecting analytics.
  final bool isPractice;

  const QuestionScreen({super.key, this.questionId, this.isPractice = false});

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
  int? _lastQuestionId; // prevents same question back-to-back
  int? _lastScoreId; // stored to allow "Undo" for premium users

  // Timer
  int _timerSeconds = 0; // 0 = off, loaded from prefs
  int _remaining = 0;
  bool _isPremium = false;
  bool _undoUsedToday = false;
  Timer? _countdownTimer;

  late final AnimationController _revealController;
  late final Animation<double> _revealAnim;

  @override
  void initState() {
    super.initState();
    AdService.instance.enterExcludedScreen();
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
    AdService.instance.exitExcludedScreen();
    _countdownTimer?.cancel();
    _revealController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final isPremium = await PlanService.isPremium();
    final undoUsed = await PlanService.hasUsedUndoToday();
    if (mounted) {
      setState(() {
        _isPremium = isPremium;
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
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        _grade(false);
      }
    });
  }

  void _stopTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
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
      question ??= await db.getRandomQuestion(excludeId: _lastQuestionId);

      Category? category;
      if (question != null) {
        category = await db.getCategoryById(question.categoryId);
      }

      setState(() {
        _lastQuestionId = question?.id;
        _question = question;
        _category = category;
        _isLoading = false;
        _answerRevealed = false;
        _graded = false;
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
    final l10n = AppLocalizations.of(context)!;
    _stopTimer();
    setState(() {
      _graded = true;
      _isCorrect = isCorrect;
    });

    try {
      final streakService = StreakService.instance;

      // Practice sessions don't affect score history or streak.
      if (!widget.isPractice) {
        // Fetch premium status fresh here — _isPremium may still be false if
        // grading happens before _loadInitialSettings() resolves.
        final isPremiumNow = await PlanService.isPremium();
        final now = DateTime.now();
        _lastScoreId = await DatabaseHelper.instance.insertScoreRecord(
          ScoreRecord(
            questionId: _question!.id!,
            categoryId: _question!.categoryId,
            isCorrect: isCorrect,
            answeredAt: now,
            updatedAt: now,
          ),
        );

        // Clear any persistent notification from the system tray for this question
        await NotificationService.instance.cancelNotificationsForQuestion(
          _question!.id!,
        );

        AnalyticsService.instance
            .trackQuestionAnswered(
              isCorrect: isCorrect,
              fromNotification: false,
            )
            .ignore();

        // Record streak only when timer is ON and ≤ the challenge threshold.
        if (_timerSeconds > 0 &&
            _timerSeconds <= StreakService.challengeThreshold) {
          final result = await StreakService.recordActivity(
            isPremiumUser: isPremiumNow,
          );
          if (result.milestoneReached && !isPremiumNow && mounted) {
            _showStreakMilestoneDialog(result.streak);
          }
        }

        // NEW Challenge Mode: wrong answer fails; correct answer advances once/day.
        if (streakService.isChallengeActive) {
          final result = await streakService.recordChallengeAnswer(
            isCorrect: isCorrect,
            isPremiumUser: isPremiumNow,
          );

          if (!mounted) return;

          if (result.outcome == ChallengeAnswerOutcome.failed) {
            // End the run immediately on failure.
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                title: Text(l10n.challengeFailureMessage),
                content: Text(l10n.challengeFailureMessage),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(l10n.awesome),
                  ),
                ],
              ),
            );
            if (mounted) Navigator.of(context).pop();
            return;
          }

          if (result.outcome == ChallengeAnswerOutcome.completed &&
              result.completion != null) {
            final c = result.completion!;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ChallengeCompleteScreen(
                  duration: c.duration,
                  questionsEarned: c.questionsEarned,
                  categoriesEarned: c.categoriesEarned,
                  isBadgeUnlocked: c.badgeUnlocked,
                  title: c.title.isEmpty ? null : c.title,
                ),
              ),
            );
            return;
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToSaveScore(e.toString()))),
        );
      }
    }

    // Show interstitial ad after every organic answer (frequency cap enforced
    // inside AdService — max 5/day, min 10 min apart).
    if (!widget.isPractice) {
      AdService.instance.showInterstitialAd().ignore();
    }
  }

  Future<void> _undoGrade() async {
    // Manual practice allows unlimited undo.
    if (!_graded || (!widget.isPractice && _undoUsedToday)) return;

    // Only Premium users can undo
    if (!_isPremium) return;

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

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.undoSuccess)));
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.undoFailed(e.toString()))));
      }
    }
  }

  void _showStreakMilestoneDialog(int streak) {
    showDialog(
      context: context,
      builder: (_) => _StreakMilestoneDialog(streak: streak),
    );
  }

  void _nextQuestion() {
    _stopTimer();
    _revealController.reset();
    _loadQuestion();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final challengeActive = StreakService.instance.isChallengeActive;

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
            : Text(l10n.appTitle),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (challengeActive)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  l10n.challengeDayCounter(
                    StreakService.instance.challengeDay,
                    StreakService.instance.challengeDuration,
                  ),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ),
          if (_timerSeconds > 0 && !_graded && !_isLoading)
            _TimerBadge(remaining: _remaining, total: _timerSeconds),
          // Next question button
          IconButton(
            icon: const Icon(Icons.skip_next_rounded),
            tooltip: l10n.skipToNext,
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
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📭', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 24),
            Text(
              l10n.noQuestionsEmptyTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.noQuestionsEmptySubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.goBack),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme colorScheme, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
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
              border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l10n.questionLabel,
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
              label: Text(l10n.revealAnswer),
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
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              l10n.answerLabel,
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
                l10n.didYouKnowIt,
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
                      label: l10n.didntKnowIt,
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
                      label: l10n.knewIt,
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
                            _isCorrect
                                ? l10n.nextQuestionPrompt
                                : l10n.keepPracticing,
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

              Row(
                children: [
                  if (!_isCorrect &&
                      _isPremium &&
                      (widget.isPractice || !_undoUsedToday)) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _undoGrade,
                        icon: const Icon(Icons.undo_rounded, size: 18),
                        label: Text(
                          widget.isPractice
                              ? l10n.undoButton
                              : l10n.undoOncePerDay,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _nextQuestion,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(l10n.nextQuestion),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Back to home
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.backToHome),
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
    final l10n = AppLocalizations.of(context)!;
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
            l10n.streakDayTitle(streak),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.streakDescription(streak),
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
          child: Text(l10n.awesome),
        ),
      ],
    );
  }
}

// ── Timer badge widget ────────────────────────────────────────────────────────

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
