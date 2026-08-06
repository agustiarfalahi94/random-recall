import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:random_recall/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/ads/ad_service.dart';
import '../../core/database/database_helper.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/plan/plan_service.dart';
import '../../core/services/analytics_service.dart';
import '../../core/streak/streak_service.dart';
import '../../core/utils/screen_security.dart';
import '../../models/category.dart';
import '../../models/question.dart';
import '../../models/score_record.dart';
import '../challenge/challenge_complete_screen.dart';
import 'question_widgets.dart';

/// Shown when the user taps a notification (organic or test).
/// No "next question" flow — grade once, see a brief toast, then app closes.
class NotificationQuestionScreen extends StatefulWidget {
  final int? questionId;

  /// When true (test notification), score and streak are NOT recorded.
  final bool isPractice;

  const NotificationQuestionScreen({
    super.key,
    this.questionId,
    this.isPractice = false,
  });

  @override
  State<NotificationQuestionScreen> createState() =>
      _NotificationQuestionScreenState();
}

class _NotificationQuestionScreenState extends State<NotificationQuestionScreen>
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
    // Block screenshots while question + answer are visible (anti-cheat).
    enableSecureScreen();
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
    disableSecureScreen();
    AdService.instance.exitExcludedScreen();
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
      if (!widget.isPractice) {
        AnalyticsService.instance.trackNotificationTapped().ignore();
      }
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
      // Test notifications are practice — don't affect score or streak.
      if (!widget.isPractice) {
        // Fetch premium status fresh — _isPremium may still be false if
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

        // Clear the persistent tray notification for this question and signal
        // the home screen badge to refresh (always fires, even on MIUI).
        await NotificationService.instance.cancelNotificationsForQuestion(
          _question!.id!,
        );

        AnalyticsService.instance
            .trackQuestionAnswered(
              isCorrect: isCorrect,
              fromNotification: true,
              timerSeconds: _timerSeconds,
              timeToAnswerSeconds: _timerSeconds > 0
                  ? _timerSeconds - _remaining
                  : -1,
            )
            .ignore();

        // NEW Challenge Mode: wrong answer fails; correct answer advances once/day.
        if (StreakService.instance.isChallengeActive) {
          final result = await StreakService.instance.recordChallengeAnswer(
            isCorrect: isCorrect,
            isPremiumUser: isPremiumNow,
          );

          if (mounted && result.outcome == ChallengeAnswerOutcome.failed) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.challengeFailureMessage)),
            );
          }

          if (mounted &&
              result.outcome == ChallengeAnswerOutcome.completed &&
              result.completion != null) {
            final c = result.completion!;
            // In notification flow, we can't keep the app open long;
            // show completion UI briefly, then close.
            await Navigator.of(context).push(
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
          }
        }
      }
    } catch (e, st) {
      FirebaseCrashlytics.instance.recordError(e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.failedToSaveScore(e.toString()),
            ),
          ),
        );
      }
    }

    // Show interstitial ad after every organic answer (test notifications skip).
    // Frequency cap (max 5/day, min 10 min apart) is enforced inside AdService.
    if (!widget.isPractice) {
      AdService.instance.showInterstitialAd().ignore();
    }

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
    if (!_graded || !_isPremium || (!widget.isPractice && _undoUsedToday)) {
      return;
    }

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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.undoSuccess)),
      );
    } catch (_) {}
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
                  Expanded(
                    child: Text(
                      _category!.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            : Text(l10n.appTitle),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _close, // Use helper to handle pop vs system pop
        ),
        actions: [
          if (challengeActive)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
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
            QuestionTimerBadge(remaining: _remaining, total: _timerSeconds),
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
              onPressed: () => SystemNavigator.pop(),
              child: Text(l10n.closeButton),
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

          // ── Question card ──────────────────────────────────────────────────
          QuestionCard(
            questionText: _question!.question,
            label: l10n.questionLabel,
          ),

          const SizedBox(height: 24),

          // ── Reveal button or answer ────────────────────────────────────────
          if (!_answerRevealed)
            ElevatedButton.icon(
              onPressed: _revealAnswer,
              icon: const Icon(Icons.visibility_rounded),
              label: Text(l10n.revealAnswer),
            )
          else ...[
            AnswerCard(
              answerText: _question!.answer,
              label: l10n.answerLabel,
              revealAnim: _revealAnim,
            ),

            const SizedBox(height: 32),

            // ── Grade buttons or result toast ────────────────────────────────
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
                  Expanded(
                    child: QuestionGradeButton(
                      label: l10n.didntKnowIt,
                      emoji: '❌',
                      color: colorScheme.errorContainer,
                      textColor: colorScheme.onErrorContainer,
                      onTap: () => _grade(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: QuestionGradeButton(
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
                                ? (widget.isPractice
                                      ? l10n.closingInMoment
                                      : l10n.scoreRecordedClosing)
                                : (widget.isPractice
                                      ? l10n.keepPracticing
                                      : l10n.scoreRecordedKeepPracticing),
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

              if (!_isCorrect &&
                  _isPremium &&
                  (widget.isPractice || !_undoUsedToday))
                Row(
                  children: [
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
