// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Random Recall';

  @override
  String get back => 'Back';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get close => 'Close';

  @override
  String get send => 'Send';

  @override
  String get all => 'All';

  @override
  String get off => 'Off';

  @override
  String get secondsUnit => 's';

  @override
  String get language => 'Language';

  @override
  String get languageSubtitle => 'English / Bahasa Indonesia';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageIndonesian => 'Bahasa Indonesia';

  @override
  String get dayMon => 'Mon';

  @override
  String get dayTue => 'Tue';

  @override
  String get dayWed => 'Wed';

  @override
  String get dayThu => 'Thu';

  @override
  String get dayFri => 'Fri';

  @override
  String get daySat => 'Sat';

  @override
  String get daySun => 'Sun';

  @override
  String get presetDaily => 'Daily';

  @override
  String get presetWeekdays => 'Weekdays';

  @override
  String get presetWeekends => 'Weekends';

  @override
  String get everyDay => 'Every day';

  @override
  String get weekdaysOnly => 'Weekdays only';

  @override
  String get weekendsOnly => 'Weekends only';

  @override
  String get mustChooseDay => 'You must choose at least 1!';

  @override
  String get startTime => 'Start time';

  @override
  String get endTime => 'End time';

  @override
  String get selectStartTime => 'Select start time';

  @override
  String get selectEndTime => 'Select end time';

  @override
  String get fieldQuestion => 'Question';

  @override
  String get fieldAnswer => 'Answer';

  @override
  String get fieldCategory => 'Category';

  @override
  String get selectCategory => 'Select a category';

  @override
  String get loginWelcomeTitle => 'Welcome to Random Recall';

  @override
  String get loginSubtitle =>
      'Sign in to sync your progress and unlock premium features.';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueWithEmail => 'Continue with Email';

  @override
  String get providerGoogle => 'Google';

  @override
  String get providerEmail => 'Email';

  @override
  String loginFailedSnack(String error) {
    return 'Login failed: $error';
  }

  @override
  String get emailAuthTitle => 'Login';

  @override
  String get welcomeBack => 'Welcome back!';

  @override
  String get emailAddress => 'Email Address';

  @override
  String get password => 'Password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get loginButton => 'Login';

  @override
  String get needAccount => 'Need an account? Sign up';

  @override
  String get forgotPasswordLink => 'Forgot Password?';

  @override
  String get validationEnterEmail => 'Please enter your email';

  @override
  String get validationValidEmail => 'Please enter a valid email address';

  @override
  String get validationEnterPassword => 'Please enter your password';

  @override
  String get validationPasswordLength =>
      'Password must be at least 6 characters';

  @override
  String get errorNoAccount => 'No account found for this email.';

  @override
  String get errorWrongPassword => 'Incorrect email or password.';

  @override
  String get errorInvalidEmail => 'The email address is not valid.';

  @override
  String get errorAccountDisabled => 'This account has been disabled.';

  @override
  String get errorTooManyRequests =>
      'Too many attempts. Please try again later.';

  @override
  String get errorAuthFailed => 'Authentication failed. Please try again.';

  @override
  String get errorUnexpected =>
      'An unexpected error occurred. Please try again.';

  @override
  String get signupTitle => 'Create Account';

  @override
  String get joinTitle => 'Join Random Recall';

  @override
  String get signUpButton => 'Sign Up';

  @override
  String get alreadyHaveAccount => 'Already have an account? Login';

  @override
  String get accountCreatedSnack =>
      'Account created! Please check your email inbox to verify.';

  @override
  String get validationEnterNewPassword => 'Please enter a password';

  @override
  String get errorEmailInUse =>
      'This email address is already in use. Please log in or use a different email.';

  @override
  String get errorWeakPassword =>
      'The password is too weak. Please use at least 6 characters.';

  @override
  String get errorSignUpFailed => 'Sign up failed. Please try again.';

  @override
  String get resetPasswordTitle => 'Reset Password';

  @override
  String get forgotPasswordTitle => 'Forgot Password?';

  @override
  String get forgotPasswordSubtitle =>
      'Enter your email and we will send you a reset link if the account exists.';

  @override
  String get sendResetLink => 'Send Reset Link';

  @override
  String get resetSuccess =>
      'If an account exists for this email, a reset link has been sent.';

  @override
  String get enterYourEmail => 'Enter your email';

  @override
  String get resetError => 'An error occurred. Please try again.';

  @override
  String get verifyEmailTitle => 'Verify your email';

  @override
  String verifyEmailSent(String email) {
    return 'We sent a verification link to $email.\nPlease check your inbox and click the link to continue.';
  }

  @override
  String get iHaveClickedLink => 'I have clicked the link';

  @override
  String get resendEmail => 'Resend Email';

  @override
  String get cancelSignOut => 'Cancel / Sign Out';

  @override
  String get waitingVerification => 'Waiting for verification...';

  @override
  String get verificationResent => 'Verification email resent!';

  @override
  String get signingOut => 'Signing out...';

  @override
  String get onboardingTagline => 'Quiz yourself on anything.\nRandomly.';

  @override
  String get onboardingDescription =>
      'Add your own questions, pick when you want to be reminded, and let Random Recall keep your knowledge sharp — one random quiz at a time.';

  @override
  String get featureRandom => 'Random';

  @override
  String get featureNotifications => 'Notifications';

  @override
  String get featureAnalytics => 'Analytics';

  @override
  String get getStarted => 'Get Started →';

  @override
  String get firstQuestionTitle => 'Your first question';

  @override
  String get firstQuestionSubtitle =>
      'Add something you want to remember. You can add more later.';

  @override
  String get questionHintOnboarding => 'e.g. What is the capital of France?';

  @override
  String get answerHintOnboarding => 'e.g. Paris';

  @override
  String get validationEnterQuestion => 'Please enter a question';

  @override
  String get validationQuestionTooShort => 'Question is too short';

  @override
  String get validationEnterAnswer => 'Please enter an answer';

  @override
  String get validationSelectCategory => 'Please select a category';

  @override
  String get notifSetupTitle => 'When should we\nremind you?';

  @override
  String get notifSetupSubtitle =>
      'You can change these settings later in the app.';

  @override
  String get timingSection => 'Timing';

  @override
  String get anytimeOption => 'Anytime (fully random)';

  @override
  String get anytimeSubtitle => 'Notifications at any hour of the day';

  @override
  String get setTimeRange => 'Set time range';

  @override
  String get setTimeRangeSubtitle => 'Only notify within your chosen window';

  @override
  String get timeWindowSection => 'Time window';

  @override
  String get activeDaysSection => 'Active days';

  @override
  String get howManyTimesPerDay => 'How many times per day?';

  @override
  String get timePerDay => 'time per day';

  @override
  String get timesPerDay => 'times per day';

  @override
  String get notificationsOff => 'Notifications are turned off';

  @override
  String get notifPermDeniedMsg =>
      'Tap the button below to open Notification Settings. Enable \"Random Recall\" there, then come back here.';

  @override
  String get notifNeedsPermission =>
      'Random Recall needs notifications to remind you. Please allow notifications when prompted.';

  @override
  String get checkingPermission => 'Checking notification permission…';

  @override
  String get openNotifSettings => 'Open Notification Settings ↗';

  @override
  String get tryAgain => 'Try again';

  @override
  String get startRecalling => 'Start Recalling! 🚀';

  @override
  String get skipForNow => 'Skip for now — enable notifications later';

  @override
  String get endTimeMustBeAfter =>
      'End time must be at least 1 hour after start time.';

  @override
  String get notifRequired => 'Notifications Required';

  @override
  String get notifRequiredDesc =>
      'Random Recall works by sending you random quiz notifications throughout the day. Without this permission, the app cannot function.';

  @override
  String get enableNotifications => 'Enable Notifications';

  @override
  String get exitApp => 'Exit App';

  @override
  String get enableInSettings =>
      'Please enable notifications in system settings to continue.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get syncDataNow => 'Sync Data Now';

  @override
  String get syncSubtitle => 'Pull latest changes from the cloud';

  @override
  String get syncSingleDeviceNote =>
      'Only one device can be active at a time. Signing in on a new device will automatically sign you out from this one.';

  @override
  String get sendTestNotification => 'Send test notification';

  @override
  String get sendTestSubtitle => 'Verify notifications work on your device';

  @override
  String get notifScheduleMenuItem => 'Notification schedule';

  @override
  String get notifScheduleMenuSubtitle => 'Set timing, days & frequency';

  @override
  String get manageCategoriesMenuItem => 'Manage categories';

  @override
  String get manageCategoriesMenuSubtitle =>
      'Add or remove question categories';

  @override
  String get sendFeedbackMenuItem => 'Send feedback';

  @override
  String get sendFeedbackMenuSubtitle => 'Tell us what could be better';

  @override
  String get faqMenuItem => 'FAQ';

  @override
  String get faqMenuSubtitle => 'Common questions & expected behaviour';

  @override
  String get signOut => 'Sign Out';

  @override
  String get syncCompleteSnack => 'Sync complete! Data is up to date. 🔄';

  @override
  String syncFailedSnack(String error) {
    return 'Sync failed: $error';
  }

  @override
  String get testNotifSentSnack =>
      'Test notification sent! Check your notification bar 🔔';

  @override
  String testNotifFailedSnack(String error) {
    return 'Failed to send: $error';
  }

  @override
  String signOutFailedSnack(String error) {
    return 'Sign out failed: $error';
  }

  @override
  String get signingOutSafely => 'Signing out safely...';

  @override
  String get backingUpData => 'Backing up your data';

  @override
  String get sendFeedbackDialogTitle => 'Send feedback';

  @override
  String get feedbackHint => 'What could be better?';

  @override
  String get feedbackSentSnack => 'Feedback sent — thank you!';

  @override
  String get feedbackFailedSnack => 'Could not send feedback. Try again later.';

  @override
  String get navHome => 'Home';

  @override
  String get navQuestions => 'Questions';

  @override
  String get navAnalytics => 'Analytics';

  @override
  String get readyToRecall => 'Ready to recall?';

  @override
  String get homeSubtitle =>
      'Tap below to practice anytime,\nor wait for a random notification.';

  @override
  String get practiceNow => 'Practice Now';

  @override
  String get timerChallengeTitle => 'Timer Challenge';

  @override
  String bonusCountLabel(int count) {
    return '+$count bonus';
  }

  @override
  String timerChallengeActiveDesc(int seconds) {
    return 'Timer set to ${seconds}s — challenge active! Answer daily for 7 days to earn +1 question slot.';
  }

  @override
  String timerChallengeRelaxedDesc(int seconds, int threshold) {
    return 'Timer is ${seconds}s — too relaxed for challenge. Set to ${threshold}s or less to earn streaks.';
  }

  @override
  String timerChallengeOffDesc(int threshold) {
    return 'Set a timer (${threshold}s or less) to unlock the challenge. Answer daily for 7 days → earn +1 question slot!';
  }

  @override
  String get setATimer => 'Set a Timer';

  @override
  String get streakStart => 'Start today! Answer with the timer on.';

  @override
  String streakProgress(int streak, String plural, int days) {
    return '$streak day$plural streak — $days more to earn a bonus!';
  }

  @override
  String get notifScheduleTitle => 'Notification Schedule';

  @override
  String get challengeModeName => 'Challenge\nMode';

  @override
  String challengeModeOff(int threshold) {
    return 'Set timer to ${threshold}s or less → answer daily → hit a 7-day streak → earn +1 free question slot!';
  }

  @override
  String get challengeModeActive =>
      '🔥 Challenge active! Keep going daily for 7 days to earn +1 free question slot!';

  @override
  String challengeModeRelaxed(int threshold) {
    return 'Timer is too relaxed. Lower it to ${threshold}s or less to activate the challenge.';
  }

  @override
  String get responseTimer => 'Response timer';

  @override
  String get noTimeLimit => 'No time limit — relaxed mode';

  @override
  String get autoMarksWrong => 'Auto-marks wrong if time runs out';

  @override
  String get sendAtAnyTime => 'Send at any time';

  @override
  String get sendAtAnyTimeSubtitle => 'Notifications arrive throughout the day';

  @override
  String get frequencySection => 'Frequency';

  @override
  String get activeDaysSectionTitle => 'Active Days';

  @override
  String get notifPerDay => 'Notifications per day';

  @override
  String get saveSchedule => 'Save Schedule';

  @override
  String get saving => 'Saving...';

  @override
  String get timeWindowError => 'The time window must span at least 1 hour.';

  @override
  String get selectActiveDayError => 'Please select at least one active day.';

  @override
  String get scheduleSavedSnack => 'Notification schedule saved! 🔔';

  @override
  String get exactAlarmPermissionWarning =>
      'Settings saved, but notifications couldn\'t be scheduled — please grant \'Alarms & Reminders\' permission in your device settings.';

  @override
  String get noSettingsChanged => 'No settings were changed.';

  @override
  String saveFailedSnack(String error) {
    return 'Failed to save: $error';
  }

  @override
  String get batteryOptOn => 'Battery optimisation is ON';

  @override
  String get batteryOptSubtitle =>
      'Tap to allow Random Recall to always run (standard Android setting) — fixes missed notifications';

  @override
  String get miuiFixTitle => 'MIUI / HyperOS: fix notification delivery';

  @override
  String get miuiFixSubtitle => 'Tap to see Autostart & battery settings guide';

  @override
  String get freqOnce => 'Once a day — nice and easy';

  @override
  String freqRecommended(int count) {
    return '$count times a day — recommended';
  }

  @override
  String freqActive(int count) {
    return '$count times a day — pretty active';
  }

  @override
  String freqIntense(int count) {
    return '$count times a day — intense!';
  }

  @override
  String get freqMax => '10 times a day — maximum';

  @override
  String get editQuestionTitle => 'Edit Question';

  @override
  String get newQuestionTitle => 'New Question';

  @override
  String get questionHintAdd =>
      'e.g. When cooking fried rice, what to add last?';

  @override
  String get answerHintAdd => 'e.g. Soy sauce and sesame oil';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get addQuestion => 'Add Question';

  @override
  String get validationEnterQuestion2 => 'Please enter a question';

  @override
  String get validationQuestionTooShort2 => 'Question is too short';

  @override
  String get validationEnterAnswer2 => 'Please enter an answer';

  @override
  String get validationSelectCategory2 => 'Please select a category';

  @override
  String questionCount(int current, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      current,
      locale: localeName,
      other: '$current / $max questions',
      one: '1 / $max question',
      zero: 'No questions',
    );
    return '$_temp0';
  }

  @override
  String questionWarning(int current, int max) {
    return 'Approaching question limit — $current / $max';
  }

  @override
  String questionLimitReached(int current, int max) {
    return 'Question limit reached — $current / $max';
  }

  @override
  String get upgradeButton => 'Upgrade ›';

  @override
  String get noQuestionsInCategory => 'No questions in this category';

  @override
  String get noQuestionsYet => 'No questions yet';

  @override
  String get tapToAddFirst =>
      'Tap the button below to add your first question.';

  @override
  String get deleteQuestionTitle => 'Delete question?';

  @override
  String get newQuestionMenuTitle => 'New Question';

  @override
  String get newQuestionMenuSubtitle => 'Add something you want to remember';

  @override
  String get newCategoryMenuTitle => 'New Category';

  @override
  String get newCategoryMenuSubtitle => 'Organise questions into a new group';

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get freePlanLimitReachedBanner =>
      'Free plan: you\'ve used your 1 custom category slot. Upgrade to Premium for unlimited categories.';

  @override
  String get freePlanInfoBanner =>
      'Free plan: you can add 1 custom category. Default categories (General, Work) don\'t count against this.';

  @override
  String get noCategoriesYet => 'No custom categories yet';

  @override
  String get noCategoriesSubtitle =>
      'General and Work are built-in. Tap the button below to create your own.';

  @override
  String get newCategorySheetTitle => 'New Category';

  @override
  String get iconSectionLabel => 'ICON';

  @override
  String get nameSectionLabel => 'NAME';

  @override
  String get categoryNameHint => 'e.g. Cooking, Travel, Finance…';

  @override
  String get validationCategoryNameEmpty => 'Please enter a category name';

  @override
  String get validationCategoryNameShort => 'Name is too short';

  @override
  String get premiumUnlimitedCategories =>
      'Premium — create as many categories as you like!';

  @override
  String freePlanCategoryNote(int count) {
    return 'Free plan: $count custom category allowed (General & Work are built-in). Upgrade to Premium for unlimited.';
  }

  @override
  String get hasQuestions => 'Has questions';

  @override
  String get emptySafeToDelete => 'Empty — safe to delete';

  @override
  String get cannotDeleteTooltip => 'Cannot delete — has questions';

  @override
  String get deleteTooltip => 'Delete';

  @override
  String get deleteCategoryTitle => 'Delete category?';

  @override
  String deleteCategoryContent(String icon, String name) {
    return 'Delete \"$icon $name\"? This cannot be undone.';
  }

  @override
  String categoryHasQuestionsError(String name) {
    return '\"$name\" has questions. Delete or move them first.';
  }

  @override
  String get limitReachedFab => 'Limit Reached';

  @override
  String get newCategoryFab => 'New Category';

  @override
  String categoryCount(int current, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      current,
      locale: localeName,
      other: '$current / $max categories',
      one: '1 / $max category',
      zero: 'No categories',
    );
    return '$_temp0';
  }

  @override
  String categoryWarning(int current, int max) {
    return 'Approaching category limit — $current / $max';
  }

  @override
  String categoryLimitReached(int current, int max) {
    return 'Category limit reached — $current / $max';
  }

  @override
  String saveCategoryFailedSnack(String error) {
    return 'Failed to save: $error';
  }

  @override
  String get questionLabel => 'QUESTION';

  @override
  String get answerLabel => 'ANSWER';

  @override
  String get revealAnswer => 'Reveal Answer';

  @override
  String get didYouKnowIt => 'Did you know it?';

  @override
  String get didntKnowIt => 'Didn\'t know it';

  @override
  String get knewIt => 'I knew it!';

  @override
  String get nextQuestion => 'Next Question';

  @override
  String get backToHome => 'Back to Home';

  @override
  String get nextQuestionPrompt => 'Next question?';

  @override
  String get keepPracticing => 'Keep practicing!';

  @override
  String failedToSaveScore(String error) {
    return 'Failed to save score: $error';
  }

  @override
  String get undoSuccess => 'Result undone. You can try again! ↩️';

  @override
  String undoFailed(String error) {
    return 'Undo failed: $error';
  }

  @override
  String get undoButton => 'Undo';

  @override
  String get undoOncePerDay => 'Undo (only 1 use per day)';

  @override
  String get noQuestionsEmptyTitle => 'No questions yet';

  @override
  String get noQuestionsEmptySubtitle =>
      'Add some questions first from the Questions tab.';

  @override
  String get goBack => 'Go back';

  @override
  String get skipToNext => 'Skip to next question';

  @override
  String get scoreRecordedClosing => 'Score recorded! Closing in a moment...';

  @override
  String get closingInMoment => 'Closing in a moment...';

  @override
  String get scoreRecordedKeepPracticing => 'Score recorded! Keep practicing';

  @override
  String get closeButton => 'Close';

  @override
  String streakDayTitle(int streak) {
    return '$streak-Day Streak!';
  }

  @override
  String streakDescription(int streak) {
    return 'You\'ve answered with the timer on for $streak days straight. You earned +1 bonus question slot! 🎉';
  }

  @override
  String get awesome => 'Awesome!';

  @override
  String get analyticsNoData => 'No data yet';

  @override
  String get analyticsNoDataSubtitle =>
      'Answer some questions first and your stats will appear here.';

  @override
  String get analyticsByCategory => 'By Category';

  @override
  String get analyticsOutstanding => 'Outstanding!';

  @override
  String get analyticsGoodProgress => 'Good progress!';

  @override
  String get analyticsKeepGoing => 'Keep going!';

  @override
  String get analyticsJustStarted => 'Just getting started';

  @override
  String get analyticsOverallScore => 'Overall Score';

  @override
  String get analyticsAnswered => 'Answered';

  @override
  String get analyticsCorrect => 'Correct';

  @override
  String get analyticsWrong => 'Wrong';

  @override
  String get analyticsTotal => 'Total';

  @override
  String get analyticsCorrectLabel => '✅ Correct';

  @override
  String get analyticsWrongLabel => '❌ Wrong';

  @override
  String get analyticsUnlockTitle => 'Unlock Category Analytics';

  @override
  String get analyticsUnlockSubtitle =>
      'See exactly which categories you struggle with.\nSubscribe to unlock full analytics.';

  @override
  String get analyticsSubscribeButton => 'Subscribe to Unlock';

  @override
  String get createCategoryButton => 'Create Category';

  @override
  String get upgradeToPremium => 'Upgrade to Premium';

  @override
  String get premiumUnlockTitle => 'Unlock Full Potential';

  @override
  String get premiumUnlockSubtitle => 'Master your knowledge without limits.';

  @override
  String get featureUnlimitedQuestions => 'Unlimited Questions';

  @override
  String get featureUnlimitedQuestionsSubtitle =>
      'Add as many facts as you need to remember.';

  @override
  String get featureUnlimitedCategories => 'Unlimited Categories';

  @override
  String get featureUnlimitedCategoriesSubtitle =>
      'Organize your learning into specific topics.';

  @override
  String get featureUndoMistakes => 'Undo Mistakes';

  @override
  String get featureUndoMistakesSubtitle =>
      'Correct a wrong answer to keep your streak alive.';

  @override
  String get featureAdvancedAnalytics => 'Advanced Analytics';

  @override
  String get featureAdvancedAnalyticsSubtitle =>
      'Identify your weak spots with per-category scoring.';

  @override
  String get featureRealTimeSync => 'Real-time Sync';

  @override
  String get featureRealTimeSyncSubtitle =>
      'Seamless access across all your Android devices.';

  @override
  String getPremiumButton(String price) {
    return 'Get Premium — $price';
  }

  @override
  String get loadingPlans => 'Loading available plans...';

  @override
  String get restorePurchase => 'Restore Purchase';

  @override
  String get cancelAnytime =>
      'Cancel anytime in Google Play Store. Settings > Subscriptions.';

  @override
  String purchaseFailedSnack(String error) {
    return 'Purchase failed: $error';
  }

  @override
  String get premiumActiveMember => 'You are a Premium Member!';

  @override
  String get premiumActiveDesc =>
      'Thank you for supporting Random Recall. Enjoy all features unlocked.';

  @override
  String get premiumGreat => 'Great!';

  @override
  String get premiumIncludes => 'Premium includes:';

  @override
  String get premiumPerkUnlimitedQuestions => '✅ Unlimited questions';

  @override
  String get premiumPerkAllCategories => '✅ All categories';

  @override
  String get premiumPerkFullAnalytics => '✅ Full analytics breakdown';

  @override
  String get premiumPerkUndo => '✅ Undo wrong answer (rewarded)';

  @override
  String get questionLimitReachedTitle => 'Question Limit Reached';

  @override
  String get categoryLimitReachedTitle => 'Category Limit Reached';

  @override
  String get questionLimitReachedDesc =>
      'Free accounts can store up to 20 questions (+ bonus slots from your streak). Upgrade to Premium for unlimited questions.';

  @override
  String get categoryLimitReachedDesc =>
      'Free accounts can add questions to up to 2 categories. Upgrade to Premium to use all categories without limits.';

  @override
  String get maybeLater => 'Maybe later';

  @override
  String get miuiDialogTitle => 'Fix notifications on MIUI / HyperOS';

  @override
  String get miuiDialogSubtitle =>
      'Xiaomi phones restrict background apps by default. Two quick changes will ensure your quiz notifications arrive reliably.';

  @override
  String get miuiStep1Title => 'Enable Background Start';

  @override
  String get miuiStep1Desc =>
      'Settings → Apps → Background Start → find Random Recall → turn ON';

  @override
  String get miuiStep2Title => 'Set Power to No Restrictions';

  @override
  String get miuiStep2Desc =>
      'Settings → Apps → Random Recall → Power → No Restrictions';

  @override
  String get openBackgroundStartBtn => 'Open Background Start Settings';

  @override
  String get openAppSettingsBtn => 'Open App Settings — Set Power';

  @override
  String get doneDismissBtn => 'I\'ve done this — close';

  @override
  String get notificationTitle => 'Time for a quick recall! 🧠';

  @override
  String get notificationBody => 'Tap to answer the question';

  @override
  String get testNotificationTitle => 'Test Notification 🧪';

  @override
  String get testNotificationBody => 'Tap to answer the question';

  @override
  String get faqTitle => 'FAQ';

  @override
  String get faqSectionNotifications => 'Notifications';

  @override
  String get faqSectionQuestionBank => 'Question Bank & Limits';

  @override
  String get faqSectionChallengeMode => 'Challenge Mode';

  @override
  String get faqSectionAccountSync => 'Account & Sync';

  @override
  String get faqSectionPermissions => 'Permissions';

  @override
  String get faqQ1 =>
      'Why do all my notifications arrive at once when I unlock my phone?';

  @override
  String get faqA1 =>
      'On Xiaomi / MIUI / HyperOS devices, the OS holds scheduled alarms while the screen is off and releases them all together when you unlock. This is Android power management — the app can\'t override it directly. Whitelisting the app in battery settings (Settings → Battery → No restrictions) reduces the delay significantly.';

  @override
  String get faqQ2 =>
      'Why does the badge number show fewer than the notifications in my tray?';

  @override
  String get faqA2 =>
      'The badge counts unique questions pending, not the total number of notifications. If your question bank is small (e.g. 3 questions with frequency set to 6 per day), the same question is scheduled into multiple slots — but you only need to answer it once, so it counts as 1 in the badge.';

  @override
  String get faqQ3 =>
      'Why do multiple notifications disappear when I answer just one?';

  @override
  String get faqA3 =>
      'When you answer a question, all pending reminders for that same question are cleared at once. If your question bank is small and the same question appeared in several slots, all those notifications go away together. This is correct — you\'ve answered the question, so the reminders are no longer needed.';

  @override
  String get faqQ4 =>
      'Why did my badge count drop after I changed my notification schedule?';

  @override
  String get faqA4 =>
      'Saving new schedule settings triggers a full reschedule. In earlier versions, this could accidentally discard already-fired notifications from the badge count if their internal ID collided with a new future slot. This bug has been fixed — fired-but-unanswered notifications are now preserved through any schedule change.';

  @override
  String get faqQ5 => 'What does \"Send at any time\" mean?';

  @override
  String get faqA5 =>
      'When enabled, your daily notifications are spread evenly across the full 24-hour day (midnight to 11 PM). When disabled, notifications are spaced within the time window you set (e.g. 9 AM – 6 PM). Use a time window if you only want to be reminded during waking hours.';

  @override
  String get faqQ6 => 'Why aren\'t my notifications arriving on time?';

  @override
  String get faqA6 =>
      'Two common causes: (1) Battery optimisation is ON for the app — whitelist it using the prompt in Notification Schedule settings. (2) MIUI / HyperOS holds alarms while the screen is off and fires them all on unlock — see the first question above.';

  @override
  String get faqQ7 => 'How many questions can I add for free?';

  @override
  String get faqA7 =>
      'The free tier starts with 20 question slots. You can earn additional slots through Challenge Mode: completing the 7-day challenge earns +1 question slot, and completing the 14-day challenge earns +1 question slot and +1 category slot. Premium removes all limits entirely.';

  @override
  String get faqQ8 => 'How many custom categories can I create for free?';

  @override
  String get faqA8 =>
      'Free accounts can create 1 custom category. The built-in \"General\" and \"Work\" categories do not count against this limit. You can earn an extra category slot by completing the 14-day Challenge Mode. Premium gives unlimited categories.';

  @override
  String get faqQ9 => 'What is the daily Undo?';

  @override
  String get faqA9 =>
      'You can undo your last answer once per calendar day. The limit resets at midnight. This is available on both free and premium accounts.';

  @override
  String get faqQ10 => 'What is Challenge Mode and how does it work?';

  @override
  String get faqA10 =>
      'Start Challenge Mode from Notification Schedule. Choose between a 7-day or 14-day challenge — both lock the timer to 5–10 seconds and require correct answers on every question. Answer at least one notification per day for the full duration. Missing a day or answering incorrectly fails the challenge. Completing the 7-day challenge earns +1 question slot (free users) or a badge + title (premium). Completing the 14-day challenge earns +1 question slot and +1 category slot (free users) or a badge + title (premium).';

  @override
  String get faqQ11 => 'Does the timer affect my score if it runs out?';

  @override
  String get faqA11 =>
      'Yes — if the countdown reaches zero before you answer, the question is automatically marked as incorrect. You can set the timer to 0 in Notification Schedule settings to disable it and answer at your own pace. Note: during an active Challenge Mode, the timer is locked between 5–10 seconds and cannot be disabled.';

  @override
  String get faqQ12 => 'Do my questions sync across devices?';

  @override
  String get faqA12 =>
      'Yes. Your questions, categories, and settings are backed up to your account automatically. Signing in on a new device restores everything. You can also trigger a manual sync via Settings → Sync Data Now.';

  @override
  String get faqQ13 => 'What happens to my data if I sign out?';

  @override
  String get faqA13 =>
      'Your data is saved to the cloud before sign-out completes. Nothing is deleted locally or remotely. Signing back in restores all your questions and settings.';

  @override
  String get faqQ14 => 'Why does the app ask to disable battery optimisation?';

  @override
  String get faqA14 =>
      'Android\'s battery optimisation can kill scheduled alarms for apps running in the background. Whitelisting the app (a standard Android setting) tells the OS to keep its alarms active — this is the single most effective fix for missed or delayed notifications on any Android device.';

  @override
  String get faqQ15 => 'What do I lose if I deny notification permission?';

  @override
  String get faqA15 =>
      'The app\'s entire purpose — timed recall prompts — stops working. You won\'t receive any questions. The permission screen will appear on every app open until permission is granted in your device settings.';

  @override
  String onboardingSomethingWentWrong(String error) {
    return 'Something went wrong: $error';
  }

  @override
  String welcomeMessage(String name) {
    return 'Welcome, $name';
  }

  @override
  String get profilePageTitle => 'Profile';

  @override
  String get nameLabel => 'Name';

  @override
  String get phoneLabel => 'Phone Number';

  @override
  String get emailLabel => 'Email';

  @override
  String get subscriptionStatusLabel => 'Subscription Status';

  @override
  String get subscriptionStatusPremium => 'Premium';

  @override
  String get subscriptionStatusFree => 'Free';

  @override
  String get changePasswordButton => 'Change Password';

  @override
  String get deleteAccountButton => 'Delete Account';

  @override
  String get deleteAccountWarning =>
      'Are you sure? Account deletion is permanent. All your data will be deleted.';

  @override
  String get deleteAccountConfirm => 'Delete Account';

  @override
  String get deleteAccountCancel => 'Cancel';

  @override
  String get profileUpdateSuccess => 'Profile updated successfully';

  @override
  String get profileUpdateFailed => 'Failed to update profile';

  @override
  String get passwordChangedSuccess => 'Password changed successfully';

  @override
  String get passwordChangedFailed => 'Failed to change password';

  @override
  String get accountDeletedSuccess => 'Account deleted successfully';

  @override
  String get accountDeleteFailed => 'Failed to delete account';

  @override
  String get googleAccountLabel => 'Google Account';

  @override
  String get emailAccountLabel => 'Email';

  @override
  String get displayNameInputHint => 'Enter your name';

  @override
  String get displayNameLabel => 'Display Name';

  @override
  String get displayNameMaxLength => '50 characters maximum';

  @override
  String get displayNameInvalidCharacters =>
      'Only letters, numbers, spaces, hyphens, and underscores allowed.';

  @override
  String get displayNameEmpty => 'Please enter a name.';

  @override
  String get displayNameProfanity =>
      'This name contains inappropriate content. Please choose another.';

  @override
  String get displayNameError => 'Error saving name. Please try again.';

  @override
  String get displayNameSubmit => 'Continue';

  @override
  String get displayNameCancel => 'Cancel';

  @override
  String get challengeModeFrequencyTitle =>
      'Challenge Mode: Select Daily Frequency';

  @override
  String challengeModeFrequencyHint(int duration) {
    return 'How many questions per day during this $duration-day challenge?';
  }

  @override
  String get challengeModeFrequencyRange => '1-50 questions per day';

  @override
  String challengeWarningTitle(int duration) {
    return '⚠️ Challenge Mode — $duration-Day Streak';
  }

  @override
  String get challengeWarningRule1 =>
      '• Must answer ALL questions correctly (no mistakes allowed)';

  @override
  String get challengeWarningRule2 =>
      '• Timer locked between 5 - 10 seconds only';

  @override
  String get challengeWarningRule3 =>
      '• Notification frequency locked (cannot change)';

  @override
  String challengeWarningRule4(int duration) {
    return '• Must complete every day for $duration consecutive days';
  }

  @override
  String challengeWarningRule5(int duration) {
    return 'Complete all $duration days to earn rewards';
  }

  @override
  String get challengeWarningCancel => 'Cancel';

  @override
  String get challengeWarningStart => 'I Understand, Start Challenge';

  @override
  String challengeRewardFreeQuestions(int count) {
    return '+$count question slot';
  }

  @override
  String challengeRewardFreeCategories(int count) {
    return '+$count category slot';
  }

  @override
  String get challengeRewardBadge => '🏆 Badge';

  @override
  String get challengeRewardTitle => '👑 Progressive Title';

  @override
  String get challengeRewardNotification =>
      '🔥 Special notification appearance';

  @override
  String get challengeFailureMessage =>
      'You missed a day or answered incorrectly. Challenge failed.';

  @override
  String get challengeCompleteMessage => 'Challenge complete! Rewards earned.';

  @override
  String challengeDayCounter(int day, int total) {
    return 'Challenge Day $day/$total';
  }

  @override
  String get lockedDuringChallenge => 'Locked during challenge';

  @override
  String get challengeTimerRequirementSnack =>
      'Challenge Mode requires timer to be 5 or 10 seconds only.';

  @override
  String challengeActivatedSnack(int days) {
    return '🔥 Challenge Mode activated! You have $days days.';
  }

  @override
  String challengeConfirmTitle(int days) {
    return '🔥 Start $days-Day Challenge Mode?';
  }

  @override
  String get challengeConfirmBody =>
      'This will reset your current Regular Streak and start a new challenge.';

  @override
  String get challengeConfirmRequirementsTitle =>
      'Challenge Mode Requirements:';

  @override
  String get challengeConfirmRequirementAnswers =>
      '✓ Answer ALL questions correctly';

  @override
  String challengeConfirmRequirementTimer(int seconds) {
    return '✓ Timer locked to ${seconds}s';
  }

  @override
  String challengeConfirmRequirementFrequency(int count) {
    return '✓ Notification frequency locked to $count/day';
  }

  @override
  String challengeConfirmRequirementDays(int days) {
    return '✓ Complete the challenge in $days consecutive days';
  }

  @override
  String get challengeConfirmFooter =>
      'All of your settings will be locked before the challenge ends, beware of what you choose! For the specific timing settings, start and end time would be customizable throughout the challenge period if Send at any time is switched off.';

  @override
  String get existingStreakTitle => 'You Have an Active Regular Streak';

  @override
  String existingStreakMessage(int streak) {
    return 'You currently have a $streak-day regular streak! Keep improving or try the new Challenge Mode.';
  }

  @override
  String get existingStreakWarning =>
      '⚠️  Choose Your Path:\n\n📊 REGULAR STREAK (Keep):\n• Answer daily with any timer\n• Slower pace, forgiving\n• Build consistency\n\n🔥 CHALLENGE MODE (New):\n• 7-day intensive mode\n• MUST answer ALL correctly\n• MUST use 5–10s timer only\n• Active days locked during challenge\n• Timing settings locked for the whole challenge\n• Missing one = restart\n• Win = Reward badge + free questions';

  @override
  String get existingStreakKeep => 'Keep Regular Streak';

  @override
  String get existingStreakStart => 'Start Challenge Mode';

  @override
  String get nextButton => 'Next →';

  @override
  String get updateProfileButton => 'Update Profile';

  @override
  String get confirmPasswordTitle => 'Confirm Password';

  @override
  String get enterPasswordHint => 'Enter your password';

  @override
  String get changePasswordConfirmAction => 'Change';

  @override
  String get currentPasswordHint => 'Current Password';

  @override
  String get newPasswordHint => 'New Password';

  @override
  String get confirmPasswordHint => 'Confirm Password';

  @override
  String get addTooltip => 'Add';

  @override
  String challengeStartError(String error) {
    return 'Error starting challenge: $error';
  }

  @override
  String get challengeCompleteTitle => 'Challenge Complete!';

  @override
  String challengeCompletedDaysLabel(int duration) {
    return 'You completed the $duration-day challenge!';
  }

  @override
  String get challengeRewardsEarnedLabel => 'Rewards Earned:';

  @override
  String challengeRewardQuestionSlotsLabel(int count, String plural) {
    return '+$count Question Slot$plural';
  }

  @override
  String get challengeRewardQuestionsDesc =>
      'Permanently unlock more questions';

  @override
  String challengeRewardCategorySlotsLabel(int count, String plural) {
    return '+$count Category Slot$plural';
  }

  @override
  String get challengeRewardCategoriesDesc => 'Create more custom categories';

  @override
  String get challengeRewardBadgeUnlockedLabel => 'Challenge Badge Unlocked';

  @override
  String get challengeRewardBadgeDesc => 'Show off your achievement';

  @override
  String challengeRewardTitleLabel(String title) {
    return 'Title: $title';
  }

  @override
  String get challengeRewardTitleDesc => 'Premium exclusive achievement';

  @override
  String get challengeTitleChallenger => 'Challenger';

  @override
  String get challengeTitleChampion => 'Champion';

  @override
  String get challengeTitleLegend => 'Legend';

  @override
  String get challengeModeCardTitle => 'Challenge Mode';

  @override
  String challengeDayProgress(int day, int total) {
    return 'Day $day / $total';
  }

  @override
  String get challengeActiveDesc =>
      'Answer one question correctly every day to keep your streak alive.';

  @override
  String get challengeInactiveDesc =>
      'Answer correctly every day for 7 or 14 days to earn rewards. One wrong answer resets the run.';

  @override
  String get challengeSevenDay => '7-Day';

  @override
  String get challengeFourteenDay => '14-Day';

  @override
  String get challengeStopButton => 'Stop Challenge';

  @override
  String get challengeStopTitle => 'Stop Challenge?';

  @override
  String get challengeStopBody =>
      'This will reset your current challenge progress. Are you sure?';

  @override
  String get challengeStopAction => 'Stop';

  @override
  String get continueWithPhone => 'Continue with Phone Number';

  @override
  String get phoneAuthTitle => 'Phone Number';

  @override
  String get phoneAuthEnterNumber => 'Enter your phone number';

  @override
  String get phoneAuthSendOtp => 'Send OTP';

  @override
  String get phoneAuthEnterCode => 'Enter the 6-digit code';

  @override
  String phoneAuthCodeSentTo(String phone) {
    return 'Code sent to $phone';
  }

  @override
  String get phoneAuthVerify => 'Verify';

  @override
  String get phoneAuthResend => 'Resend';

  @override
  String phoneAuthResendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get phoneAuthInvalidCode =>
      'Invalid verification code. Please try again.';

  @override
  String get phoneAuthTooManyRequests =>
      'Too many attempts. Please try again later.';

  @override
  String get phoneAuthCredentialInUse =>
      'This phone number is already linked to another account.';

  @override
  String get phoneAuthFailed => 'Phone verification failed. Please try again.';

  @override
  String get linkPhoneTitle => 'Link Phone Number';

  @override
  String get changePhoneTitle => 'Change Phone Number';

  @override
  String get profilePhoneLinkedLabel => 'Verified phone';

  @override
  String get profileLinkPhone => 'Link phone number';

  @override
  String get profileChangePhone => 'Change';

  @override
  String get optionalEmailTitle => 'Add Recovery Email';

  @override
  String get optionalEmailSubtitle =>
      'Add an email address so you can recover your account if you ever lose access to your phone number.';

  @override
  String get optionalEmailAddButton => 'Add Email';

  @override
  String get optionalEmailSkip => 'Skip for now';

  @override
  String get optionalEmailCreatePassword => 'Create a password';

  @override
  String get optionalEmailConfirmPassword => 'Confirm password';

  @override
  String get optionalEmailSuccess =>
      'Recovery email added! Check your inbox to verify it.';

  @override
  String get optionalEmailPasswordMismatch => 'Passwords do not match.';

  @override
  String get optionalEmailPasswordLength =>
      'Password must be at least 6 characters.';

  @override
  String get profileAddRecoveryEmail => 'Add recovery email';

  @override
  String get profileAddRecoveryEmailSubtitle =>
      'Protect your account with a backup email address';

  @override
  String get phoneDeleteReauthTitle => 'Confirm with SMS Code';

  @override
  String phoneDeleteReauthSubtitle(String phone) {
    return 'We\'ll send a verification code to $phone to confirm.';
  }
}
