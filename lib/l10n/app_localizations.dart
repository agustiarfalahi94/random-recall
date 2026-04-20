import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Random Recall'**
  String get appTitle;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @secondsUnit.
  ///
  /// In en, this message translates to:
  /// **'s'**
  String get secondsUnit;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'English / Bahasa Indonesia'**
  String get languageSubtitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageIndonesian.
  ///
  /// In en, this message translates to:
  /// **'Bahasa Indonesia'**
  String get languageIndonesian;

  /// No description provided for @dayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get dayMon;

  /// No description provided for @dayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get dayTue;

  /// No description provided for @dayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get dayWed;

  /// No description provided for @dayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get dayThu;

  /// No description provided for @dayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get dayFri;

  /// No description provided for @daySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get daySat;

  /// No description provided for @daySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get daySun;

  /// No description provided for @presetDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get presetDaily;

  /// No description provided for @presetWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get presetWeekdays;

  /// No description provided for @presetWeekends.
  ///
  /// In en, this message translates to:
  /// **'Weekends'**
  String get presetWeekends;

  /// No description provided for @everyDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get everyDay;

  /// No description provided for @weekdaysOnly.
  ///
  /// In en, this message translates to:
  /// **'Weekdays only'**
  String get weekdaysOnly;

  /// No description provided for @weekendsOnly.
  ///
  /// In en, this message translates to:
  /// **'Weekends only'**
  String get weekendsOnly;

  /// No description provided for @mustChooseDay.
  ///
  /// In en, this message translates to:
  /// **'You must choose at least 1!'**
  String get mustChooseDay;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get startTime;

  /// No description provided for @endTime.
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get endTime;

  /// No description provided for @selectStartTime.
  ///
  /// In en, this message translates to:
  /// **'Select start time'**
  String get selectStartTime;

  /// No description provided for @selectEndTime.
  ///
  /// In en, this message translates to:
  /// **'Select end time'**
  String get selectEndTime;

  /// No description provided for @fieldQuestion.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get fieldQuestion;

  /// No description provided for @fieldAnswer.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get fieldAnswer;

  /// No description provided for @fieldCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get fieldCategory;

  /// No description provided for @selectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select a category'**
  String get selectCategory;

  /// No description provided for @loginWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Random Recall'**
  String get loginWelcomeTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync your progress and unlock premium features.'**
  String get loginSubtitle;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @continueWithEmail.
  ///
  /// In en, this message translates to:
  /// **'Continue with Email'**
  String get continueWithEmail;

  /// No description provided for @providerGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get providerGoogle;

  /// No description provided for @providerEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get providerEmail;

  /// No description provided for @loginFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Login failed: {error}'**
  String loginFailedSnack(String error);

  /// No description provided for @emailAuthTitle.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get emailAuthTitle;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back!'**
  String get welcomeBack;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddress;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginButton;

  /// No description provided for @needAccount.
  ///
  /// In en, this message translates to:
  /// **'Need an account? Sign up'**
  String get needAccount;

  /// No description provided for @forgotPasswordLink.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPasswordLink;

  /// No description provided for @validationEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get validationEnterEmail;

  /// No description provided for @validationValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get validationValidEmail;

  /// No description provided for @validationEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get validationEnterPassword;

  /// No description provided for @validationPasswordLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get validationPasswordLength;

  /// No description provided for @errorNoAccount.
  ///
  /// In en, this message translates to:
  /// **'No account found for this email.'**
  String get errorNoAccount;

  /// No description provided for @errorWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get errorWrongPassword;

  /// No description provided for @errorInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'The email address is not valid.'**
  String get errorInvalidEmail;

  /// No description provided for @errorAccountDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled.'**
  String get errorAccountDisabled;

  /// No description provided for @errorTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later.'**
  String get errorTooManyRequests;

  /// No description provided for @errorAuthFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Please try again.'**
  String get errorAuthFailed;

  /// No description provided for @errorUnexpected.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try again.'**
  String get errorUnexpected;

  /// No description provided for @signupTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get signupTitle;

  /// No description provided for @joinTitle.
  ///
  /// In en, this message translates to:
  /// **'Join Random Recall'**
  String get joinTitle;

  /// No description provided for @signUpButton.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUpButton;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Login'**
  String get alreadyHaveAccount;

  /// No description provided for @accountCreatedSnack.
  ///
  /// In en, this message translates to:
  /// **'Account created! Please check your email inbox to verify.'**
  String get accountCreatedSnack;

  /// No description provided for @validationEnterNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password'**
  String get validationEnterNewPassword;

  /// No description provided for @errorEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'This email address is already in use. Please log in or use a different email.'**
  String get errorEmailInUse;

  /// No description provided for @errorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'The password is too weak. Please use at least 6 characters.'**
  String get errorWeakPassword;

  /// No description provided for @errorSignUpFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign up failed. Please try again.'**
  String get errorSignUpFailed;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPasswordTitle;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we will send you a reset link if the account exists.'**
  String get forgotPasswordSubtitle;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get sendResetLink;

  /// No description provided for @resetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success! Check your email inbox for the reset link.'**
  String get resetSuccess;

  /// No description provided for @enterYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get enterYourEmail;

  /// No description provided for @resetError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred. Please try again.'**
  String get resetError;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get verifyEmailTitle;

  /// No description provided for @verifyEmailSent.
  ///
  /// In en, this message translates to:
  /// **'We sent a verification link to {email}.\nPlease check your inbox and click the link to continue.'**
  String verifyEmailSent(String email);

  /// No description provided for @iHaveClickedLink.
  ///
  /// In en, this message translates to:
  /// **'I have clicked the link'**
  String get iHaveClickedLink;

  /// No description provided for @resendEmail.
  ///
  /// In en, this message translates to:
  /// **'Resend Email'**
  String get resendEmail;

  /// No description provided for @cancelSignOut.
  ///
  /// In en, this message translates to:
  /// **'Cancel / Sign Out'**
  String get cancelSignOut;

  /// No description provided for @waitingVerification.
  ///
  /// In en, this message translates to:
  /// **'Waiting for verification...'**
  String get waitingVerification;

  /// No description provided for @verificationResent.
  ///
  /// In en, this message translates to:
  /// **'Verification email resent!'**
  String get verificationResent;

  /// No description provided for @signingOut.
  ///
  /// In en, this message translates to:
  /// **'Signing out...'**
  String get signingOut;

  /// No description provided for @onboardingTagline.
  ///
  /// In en, this message translates to:
  /// **'Quiz yourself on anything.\nRandomly.'**
  String get onboardingTagline;

  /// No description provided for @onboardingDescription.
  ///
  /// In en, this message translates to:
  /// **'Add your own questions, pick when you want to be reminded, and let Random Recall keep your knowledge sharp — one random quiz at a time.'**
  String get onboardingDescription;

  /// No description provided for @featureRandom.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get featureRandom;

  /// No description provided for @featureNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get featureNotifications;

  /// No description provided for @featureAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get featureAnalytics;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started →'**
  String get getStarted;

  /// No description provided for @firstQuestionTitle.
  ///
  /// In en, this message translates to:
  /// **'Your first question'**
  String get firstQuestionTitle;

  /// No description provided for @firstQuestionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add something you want to remember. You can add more later.'**
  String get firstQuestionSubtitle;

  /// No description provided for @questionHintOnboarding.
  ///
  /// In en, this message translates to:
  /// **'e.g. What is the capital of France?'**
  String get questionHintOnboarding;

  /// No description provided for @answerHintOnboarding.
  ///
  /// In en, this message translates to:
  /// **'e.g. Paris'**
  String get answerHintOnboarding;

  /// No description provided for @validationEnterQuestion.
  ///
  /// In en, this message translates to:
  /// **'Please enter a question'**
  String get validationEnterQuestion;

  /// No description provided for @validationQuestionTooShort.
  ///
  /// In en, this message translates to:
  /// **'Question is too short'**
  String get validationQuestionTooShort;

  /// No description provided for @validationEnterAnswer.
  ///
  /// In en, this message translates to:
  /// **'Please enter an answer'**
  String get validationEnterAnswer;

  /// No description provided for @validationSelectCategory.
  ///
  /// In en, this message translates to:
  /// **'Please select a category'**
  String get validationSelectCategory;

  /// No description provided for @notifSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'When should we\nremind you?'**
  String get notifSetupTitle;

  /// No description provided for @notifSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can change these settings later in the app.'**
  String get notifSetupSubtitle;

  /// No description provided for @timingSection.
  ///
  /// In en, this message translates to:
  /// **'Timing'**
  String get timingSection;

  /// No description provided for @anytimeOption.
  ///
  /// In en, this message translates to:
  /// **'Anytime (fully random)'**
  String get anytimeOption;

  /// No description provided for @anytimeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications at any hour of the day'**
  String get anytimeSubtitle;

  /// No description provided for @setTimeRange.
  ///
  /// In en, this message translates to:
  /// **'Set time range'**
  String get setTimeRange;

  /// No description provided for @setTimeRangeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only notify within your chosen window'**
  String get setTimeRangeSubtitle;

  /// No description provided for @timeWindowSection.
  ///
  /// In en, this message translates to:
  /// **'Time window'**
  String get timeWindowSection;

  /// No description provided for @activeDaysSection.
  ///
  /// In en, this message translates to:
  /// **'Active days'**
  String get activeDaysSection;

  /// No description provided for @howManyTimesPerDay.
  ///
  /// In en, this message translates to:
  /// **'How many times per day?'**
  String get howManyTimesPerDay;

  /// No description provided for @timePerDay.
  ///
  /// In en, this message translates to:
  /// **'time per day'**
  String get timePerDay;

  /// No description provided for @timesPerDay.
  ///
  /// In en, this message translates to:
  /// **'times per day'**
  String get timesPerDay;

  /// No description provided for @notificationsOff.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off'**
  String get notificationsOff;

  /// No description provided for @notifPermDeniedMsg.
  ///
  /// In en, this message translates to:
  /// **'Tap the button below to open Notification Settings. Enable \"Random Recall\" there, then come back here.'**
  String get notifPermDeniedMsg;

  /// No description provided for @notifNeedsPermission.
  ///
  /// In en, this message translates to:
  /// **'Random Recall needs notifications to remind you. Please allow notifications when prompted.'**
  String get notifNeedsPermission;

  /// No description provided for @checkingPermission.
  ///
  /// In en, this message translates to:
  /// **'Checking notification permission…'**
  String get checkingPermission;

  /// No description provided for @openNotifSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Notification Settings ↗'**
  String get openNotifSettings;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @startRecalling.
  ///
  /// In en, this message translates to:
  /// **'Start Recalling! 🚀'**
  String get startRecalling;

  /// No description provided for @skipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now — enable notifications later'**
  String get skipForNow;

  /// No description provided for @endTimeMustBeAfter.
  ///
  /// In en, this message translates to:
  /// **'End time must be at least 1 hour after start time.'**
  String get endTimeMustBeAfter;

  /// No description provided for @notifRequired.
  ///
  /// In en, this message translates to:
  /// **'Notifications Required'**
  String get notifRequired;

  /// No description provided for @notifRequiredDesc.
  ///
  /// In en, this message translates to:
  /// **'Random Recall works by sending you random quiz notifications throughout the day. Without this permission, the app cannot function.'**
  String get notifRequiredDesc;

  /// No description provided for @enableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Enable Notifications'**
  String get enableNotifications;

  /// No description provided for @exitApp.
  ///
  /// In en, this message translates to:
  /// **'Exit App'**
  String get exitApp;

  /// No description provided for @enableInSettings.
  ///
  /// In en, this message translates to:
  /// **'Please enable notifications in system settings to continue.'**
  String get enableInSettings;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTooltip;

  /// No description provided for @syncDataNow.
  ///
  /// In en, this message translates to:
  /// **'Sync Data Now'**
  String get syncDataNow;

  /// No description provided for @syncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pull latest changes from the cloud'**
  String get syncSubtitle;

  /// No description provided for @syncSingleDeviceNote.
  ///
  /// In en, this message translates to:
  /// **'Only one device can be active at a time. Signing in on a new device will automatically sign you out from this one.'**
  String get syncSingleDeviceNote;

  /// No description provided for @sendTestNotification.
  ///
  /// In en, this message translates to:
  /// **'Send test notification'**
  String get sendTestNotification;

  /// No description provided for @sendTestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Verify notifications work on your device'**
  String get sendTestSubtitle;

  /// No description provided for @notifScheduleMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Notification schedule'**
  String get notifScheduleMenuItem;

  /// No description provided for @notifScheduleMenuSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set timing, days & frequency'**
  String get notifScheduleMenuSubtitle;

  /// No description provided for @manageCategoriesMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Manage categories'**
  String get manageCategoriesMenuItem;

  /// No description provided for @manageCategoriesMenuSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add or remove question categories'**
  String get manageCategoriesMenuSubtitle;

  /// No description provided for @sendFeedbackMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get sendFeedbackMenuItem;

  /// No description provided for @sendFeedbackMenuSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us what could be better'**
  String get sendFeedbackMenuSubtitle;

  /// No description provided for @faqMenuItem.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get faqMenuItem;

  /// No description provided for @faqMenuSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Common questions & expected behaviour'**
  String get faqMenuSubtitle;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @syncCompleteSnack.
  ///
  /// In en, this message translates to:
  /// **'Sync complete! Data is up to date. 🔄'**
  String get syncCompleteSnack;

  /// No description provided for @syncFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {error}'**
  String syncFailedSnack(String error);

  /// No description provided for @testNotifSentSnack.
  ///
  /// In en, this message translates to:
  /// **'Test notification sent! Check your notification bar 🔔'**
  String get testNotifSentSnack;

  /// No description provided for @testNotifFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Failed to send: {error}'**
  String testNotifFailedSnack(String error);

  /// No description provided for @signOutFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Sign out failed: {error}'**
  String signOutFailedSnack(String error);

  /// No description provided for @signingOutSafely.
  ///
  /// In en, this message translates to:
  /// **'Signing out safely...'**
  String get signingOutSafely;

  /// No description provided for @backingUpData.
  ///
  /// In en, this message translates to:
  /// **'Backing up your data'**
  String get backingUpData;

  /// No description provided for @sendFeedbackDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get sendFeedbackDialogTitle;

  /// No description provided for @feedbackHint.
  ///
  /// In en, this message translates to:
  /// **'What could be better?'**
  String get feedbackHint;

  /// No description provided for @feedbackSentSnack.
  ///
  /// In en, this message translates to:
  /// **'Feedback sent — thank you!'**
  String get feedbackSentSnack;

  /// No description provided for @feedbackFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Could not send feedback. Try again later.'**
  String get feedbackFailedSnack;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navQuestions.
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get navQuestions;

  /// No description provided for @navAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get navAnalytics;

  /// No description provided for @readyToRecall.
  ///
  /// In en, this message translates to:
  /// **'Ready to recall?'**
  String get readyToRecall;

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap below to practice anytime,\nor wait for a random notification.'**
  String get homeSubtitle;

  /// No description provided for @practiceNow.
  ///
  /// In en, this message translates to:
  /// **'Practice Now'**
  String get practiceNow;

  /// No description provided for @timerChallengeTitle.
  ///
  /// In en, this message translates to:
  /// **'Timer Challenge'**
  String get timerChallengeTitle;

  /// No description provided for @bonusCountLabel.
  ///
  /// In en, this message translates to:
  /// **'+{count} bonus'**
  String bonusCountLabel(int count);

  /// No description provided for @timerChallengeActiveDesc.
  ///
  /// In en, this message translates to:
  /// **'Timer set to {seconds}s — challenge active! Answer daily for 7 days to earn +1 question slot.'**
  String timerChallengeActiveDesc(int seconds);

  /// No description provided for @timerChallengeRelaxedDesc.
  ///
  /// In en, this message translates to:
  /// **'Timer is {seconds}s — too relaxed for challenge. Set to {threshold}s or less to earn streaks.'**
  String timerChallengeRelaxedDesc(int seconds, int threshold);

  /// No description provided for @timerChallengeOffDesc.
  ///
  /// In en, this message translates to:
  /// **'Set a timer ({threshold}s or less) to unlock the challenge. Answer daily for 7 days → earn +1 question slot!'**
  String timerChallengeOffDesc(int threshold);

  /// No description provided for @setATimer.
  ///
  /// In en, this message translates to:
  /// **'Set a Timer'**
  String get setATimer;

  /// No description provided for @streakStart.
  ///
  /// In en, this message translates to:
  /// **'Start today! Answer with the timer on.'**
  String get streakStart;

  /// No description provided for @streakProgress.
  ///
  /// In en, this message translates to:
  /// **'{streak} day{plural} streak — {days} more to earn a bonus!'**
  String streakProgress(int streak, String plural, int days);

  /// No description provided for @notifScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification Schedule'**
  String get notifScheduleTitle;

  /// No description provided for @challengeModeName.
  ///
  /// In en, this message translates to:
  /// **'Challenge\nMode'**
  String get challengeModeName;

  /// No description provided for @challengeModeOff.
  ///
  /// In en, this message translates to:
  /// **'Set timer to {threshold}s or less → answer daily → hit a 7-day streak → earn +1 free question slot!'**
  String challengeModeOff(int threshold);

  /// No description provided for @challengeModeActive.
  ///
  /// In en, this message translates to:
  /// **'🔥 Challenge active! Keep going daily for 7 days to earn +1 free question slot!'**
  String get challengeModeActive;

  /// No description provided for @challengeModeRelaxed.
  ///
  /// In en, this message translates to:
  /// **'Timer is too relaxed. Lower it to {threshold}s or less to activate the challenge.'**
  String challengeModeRelaxed(int threshold);

  /// No description provided for @responseTimer.
  ///
  /// In en, this message translates to:
  /// **'Response timer'**
  String get responseTimer;

  /// No description provided for @noTimeLimit.
  ///
  /// In en, this message translates to:
  /// **'No time limit — relaxed mode'**
  String get noTimeLimit;

  /// No description provided for @autoMarksWrong.
  ///
  /// In en, this message translates to:
  /// **'Auto-marks wrong if time runs out'**
  String get autoMarksWrong;

  /// No description provided for @sendAtAnyTime.
  ///
  /// In en, this message translates to:
  /// **'Send at any time'**
  String get sendAtAnyTime;

  /// No description provided for @sendAtAnyTimeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications arrive throughout the day'**
  String get sendAtAnyTimeSubtitle;

  /// No description provided for @frequencySection.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequencySection;

  /// No description provided for @activeDaysSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Active Days'**
  String get activeDaysSectionTitle;

  /// No description provided for @notifPerDay.
  ///
  /// In en, this message translates to:
  /// **'Notifications per day'**
  String get notifPerDay;

  /// No description provided for @saveSchedule.
  ///
  /// In en, this message translates to:
  /// **'Save Schedule'**
  String get saveSchedule;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @timeWindowError.
  ///
  /// In en, this message translates to:
  /// **'The time window must span at least 1 hour.'**
  String get timeWindowError;

  /// No description provided for @selectActiveDayError.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one active day.'**
  String get selectActiveDayError;

  /// No description provided for @scheduleSavedSnack.
  ///
  /// In en, this message translates to:
  /// **'Notification schedule saved! 🔔'**
  String get scheduleSavedSnack;

  /// No description provided for @saveFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String saveFailedSnack(String error);

  /// No description provided for @batteryOptOn.
  ///
  /// In en, this message translates to:
  /// **'Battery optimisation is ON'**
  String get batteryOptOn;

  /// No description provided for @batteryOptSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap to allow Random Recall to always run (standard Android setting) — fixes missed notifications'**
  String get batteryOptSubtitle;

  /// No description provided for @miuiFixTitle.
  ///
  /// In en, this message translates to:
  /// **'MIUI / HyperOS: fix notification delivery'**
  String get miuiFixTitle;

  /// No description provided for @miuiFixSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap to see Autostart & battery settings guide'**
  String get miuiFixSubtitle;

  /// No description provided for @freqOnce.
  ///
  /// In en, this message translates to:
  /// **'Once a day — nice and easy'**
  String get freqOnce;

  /// No description provided for @freqRecommended.
  ///
  /// In en, this message translates to:
  /// **'{count} times a day — recommended'**
  String freqRecommended(int count);

  /// No description provided for @freqActive.
  ///
  /// In en, this message translates to:
  /// **'{count} times a day — pretty active'**
  String freqActive(int count);

  /// No description provided for @freqIntense.
  ///
  /// In en, this message translates to:
  /// **'{count} times a day — intense!'**
  String freqIntense(int count);

  /// No description provided for @freqMax.
  ///
  /// In en, this message translates to:
  /// **'10 times a day — maximum'**
  String get freqMax;

  /// No description provided for @editQuestionTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Question'**
  String get editQuestionTitle;

  /// No description provided for @newQuestionTitle.
  ///
  /// In en, this message translates to:
  /// **'New Question'**
  String get newQuestionTitle;

  /// No description provided for @questionHintAdd.
  ///
  /// In en, this message translates to:
  /// **'e.g. When cooking fried rice, what to add last?'**
  String get questionHintAdd;

  /// No description provided for @answerHintAdd.
  ///
  /// In en, this message translates to:
  /// **'e.g. Soy sauce and sesame oil'**
  String get answerHintAdd;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @addQuestion.
  ///
  /// In en, this message translates to:
  /// **'Add Question'**
  String get addQuestion;

  /// No description provided for @validationEnterQuestion2.
  ///
  /// In en, this message translates to:
  /// **'Please enter a question'**
  String get validationEnterQuestion2;

  /// No description provided for @validationQuestionTooShort2.
  ///
  /// In en, this message translates to:
  /// **'Question is too short'**
  String get validationQuestionTooShort2;

  /// No description provided for @validationEnterAnswer2.
  ///
  /// In en, this message translates to:
  /// **'Please enter an answer'**
  String get validationEnterAnswer2;

  /// No description provided for @validationSelectCategory2.
  ///
  /// In en, this message translates to:
  /// **'Please select a category'**
  String get validationSelectCategory2;

  /// No description provided for @questionCount.
  ///
  /// In en, this message translates to:
  /// **'{current, plural, =0{No questions} =1{1 / {max} question} other{{current} / {max} questions}}'**
  String questionCount(int current, int max);

  /// No description provided for @questionWarning.
  ///
  /// In en, this message translates to:
  /// **'Approaching question limit — {current} / {max}'**
  String questionWarning(int current, int max);

  /// No description provided for @questionLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Question limit reached — {current} / {max}'**
  String questionLimitReached(int current, int max);

  /// No description provided for @upgradeButton.
  ///
  /// In en, this message translates to:
  /// **'Upgrade ›'**
  String get upgradeButton;

  /// No description provided for @noQuestionsInCategory.
  ///
  /// In en, this message translates to:
  /// **'No questions in this category'**
  String get noQuestionsInCategory;

  /// No description provided for @noQuestionsYet.
  ///
  /// In en, this message translates to:
  /// **'No questions yet'**
  String get noQuestionsYet;

  /// No description provided for @tapToAddFirst.
  ///
  /// In en, this message translates to:
  /// **'Tap the button below to add your first question.'**
  String get tapToAddFirst;

  /// No description provided for @deleteQuestionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete question?'**
  String get deleteQuestionTitle;

  /// No description provided for @newQuestionMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'New Question'**
  String get newQuestionMenuTitle;

  /// No description provided for @newQuestionMenuSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add something you want to remember'**
  String get newQuestionMenuSubtitle;

  /// No description provided for @newCategoryMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'New Category'**
  String get newCategoryMenuTitle;

  /// No description provided for @newCategoryMenuSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Organise questions into a new group'**
  String get newCategoryMenuSubtitle;

  /// No description provided for @categoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoriesTitle;

  /// No description provided for @freePlanLimitReachedBanner.
  ///
  /// In en, this message translates to:
  /// **'Free plan: you\'ve used your 1 custom category slot. Upgrade to Premium for unlimited categories.'**
  String get freePlanLimitReachedBanner;

  /// No description provided for @freePlanInfoBanner.
  ///
  /// In en, this message translates to:
  /// **'Free plan: you can add 1 custom category. Default categories (General, Work) don\'t count against this.'**
  String get freePlanInfoBanner;

  /// No description provided for @noCategoriesYet.
  ///
  /// In en, this message translates to:
  /// **'No custom categories yet'**
  String get noCategoriesYet;

  /// No description provided for @noCategoriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'General and Work are built-in. Tap the button below to create your own.'**
  String get noCategoriesSubtitle;

  /// No description provided for @newCategorySheetTitle.
  ///
  /// In en, this message translates to:
  /// **'New Category'**
  String get newCategorySheetTitle;

  /// No description provided for @iconSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'ICON'**
  String get iconSectionLabel;

  /// No description provided for @nameSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'NAME'**
  String get nameSectionLabel;

  /// No description provided for @categoryNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Cooking, Travel, Finance…'**
  String get categoryNameHint;

  /// No description provided for @validationCategoryNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a category name'**
  String get validationCategoryNameEmpty;

  /// No description provided for @validationCategoryNameShort.
  ///
  /// In en, this message translates to:
  /// **'Name is too short'**
  String get validationCategoryNameShort;

  /// No description provided for @premiumUnlimitedCategories.
  ///
  /// In en, this message translates to:
  /// **'Premium — create as many categories as you like!'**
  String get premiumUnlimitedCategories;

  /// No description provided for @freePlanCategoryNote.
  ///
  /// In en, this message translates to:
  /// **'Free plan: {count} custom category allowed (General & Work are built-in). Upgrade to Premium for unlimited.'**
  String freePlanCategoryNote(int count);

  /// No description provided for @hasQuestions.
  ///
  /// In en, this message translates to:
  /// **'Has questions'**
  String get hasQuestions;

  /// No description provided for @emptySafeToDelete.
  ///
  /// In en, this message translates to:
  /// **'Empty — safe to delete'**
  String get emptySafeToDelete;

  /// No description provided for @cannotDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete — has questions'**
  String get cannotDeleteTooltip;

  /// No description provided for @deleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteTooltip;

  /// No description provided for @deleteCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete category?'**
  String get deleteCategoryTitle;

  /// No description provided for @deleteCategoryContent.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{icon} {name}\"? This cannot be undone.'**
  String deleteCategoryContent(String icon, String name);

  /// No description provided for @categoryHasQuestionsError.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" has questions. Delete or move them first.'**
  String categoryHasQuestionsError(String name);

  /// No description provided for @limitReachedFab.
  ///
  /// In en, this message translates to:
  /// **'Limit Reached'**
  String get limitReachedFab;

  /// No description provided for @newCategoryFab.
  ///
  /// In en, this message translates to:
  /// **'New Category'**
  String get newCategoryFab;

  /// No description provided for @categoryCount.
  ///
  /// In en, this message translates to:
  /// **'{current, plural, =0{No categories} =1{1 / {max} category} other{{current} / {max} categories}}'**
  String categoryCount(int current, int max);

  /// No description provided for @categoryWarning.
  ///
  /// In en, this message translates to:
  /// **'Approaching category limit — {current} / {max}'**
  String categoryWarning(int current, int max);

  /// No description provided for @categoryLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Category limit reached — {current} / {max}'**
  String categoryLimitReached(int current, int max);

  /// No description provided for @saveCategoryFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String saveCategoryFailedSnack(String error);

  /// No description provided for @questionLabel.
  ///
  /// In en, this message translates to:
  /// **'QUESTION'**
  String get questionLabel;

  /// No description provided for @answerLabel.
  ///
  /// In en, this message translates to:
  /// **'ANSWER'**
  String get answerLabel;

  /// No description provided for @revealAnswer.
  ///
  /// In en, this message translates to:
  /// **'Reveal Answer'**
  String get revealAnswer;

  /// No description provided for @didYouKnowIt.
  ///
  /// In en, this message translates to:
  /// **'Did you know it?'**
  String get didYouKnowIt;

  /// No description provided for @didntKnowIt.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t know it'**
  String get didntKnowIt;

  /// No description provided for @knewIt.
  ///
  /// In en, this message translates to:
  /// **'I knew it!'**
  String get knewIt;

  /// No description provided for @nextQuestion.
  ///
  /// In en, this message translates to:
  /// **'Next Question'**
  String get nextQuestion;

  /// No description provided for @backToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get backToHome;

  /// No description provided for @nextQuestionPrompt.
  ///
  /// In en, this message translates to:
  /// **'Next question?'**
  String get nextQuestionPrompt;

  /// No description provided for @keepPracticing.
  ///
  /// In en, this message translates to:
  /// **'Keep practicing!'**
  String get keepPracticing;

  /// No description provided for @failedToSaveScore.
  ///
  /// In en, this message translates to:
  /// **'Failed to save score: {error}'**
  String failedToSaveScore(String error);

  /// No description provided for @undoSuccess.
  ///
  /// In en, this message translates to:
  /// **'Result undone. You can try again! ↩️'**
  String get undoSuccess;

  /// No description provided for @undoFailed.
  ///
  /// In en, this message translates to:
  /// **'Undo failed: {error}'**
  String undoFailed(String error);

  /// No description provided for @undoButton.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undoButton;

  /// No description provided for @undoOncePerDay.
  ///
  /// In en, this message translates to:
  /// **'Undo (only 1 use per day)'**
  String get undoOncePerDay;

  /// No description provided for @noQuestionsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No questions yet'**
  String get noQuestionsEmptyTitle;

  /// No description provided for @noQuestionsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add some questions first from the Questions tab.'**
  String get noQuestionsEmptySubtitle;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get goBack;

  /// No description provided for @skipToNext.
  ///
  /// In en, this message translates to:
  /// **'Skip to next question'**
  String get skipToNext;

  /// No description provided for @scoreRecordedClosing.
  ///
  /// In en, this message translates to:
  /// **'Score recorded! Closing in a moment...'**
  String get scoreRecordedClosing;

  /// No description provided for @closingInMoment.
  ///
  /// In en, this message translates to:
  /// **'Closing in a moment...'**
  String get closingInMoment;

  /// No description provided for @scoreRecordedKeepPracticing.
  ///
  /// In en, this message translates to:
  /// **'Score recorded! Keep practicing'**
  String get scoreRecordedKeepPracticing;

  /// No description provided for @closeButton.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeButton;

  /// No description provided for @streakDayTitle.
  ///
  /// In en, this message translates to:
  /// **'{streak}-Day Streak!'**
  String streakDayTitle(int streak);

  /// No description provided for @streakDescription.
  ///
  /// In en, this message translates to:
  /// **'You\'ve answered with the timer on for {streak} days straight. You earned +1 bonus question slot! 🎉'**
  String streakDescription(int streak);

  /// No description provided for @awesome.
  ///
  /// In en, this message translates to:
  /// **'Awesome!'**
  String get awesome;

  /// No description provided for @analyticsNoData.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get analyticsNoData;

  /// No description provided for @analyticsNoDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Answer some questions first and your stats will appear here.'**
  String get analyticsNoDataSubtitle;

  /// No description provided for @analyticsByCategory.
  ///
  /// In en, this message translates to:
  /// **'By Category'**
  String get analyticsByCategory;

  /// No description provided for @analyticsOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Outstanding!'**
  String get analyticsOutstanding;

  /// No description provided for @analyticsGoodProgress.
  ///
  /// In en, this message translates to:
  /// **'Good progress!'**
  String get analyticsGoodProgress;

  /// No description provided for @analyticsKeepGoing.
  ///
  /// In en, this message translates to:
  /// **'Keep going!'**
  String get analyticsKeepGoing;

  /// No description provided for @analyticsJustStarted.
  ///
  /// In en, this message translates to:
  /// **'Just getting started'**
  String get analyticsJustStarted;

  /// No description provided for @analyticsOverallScore.
  ///
  /// In en, this message translates to:
  /// **'Overall Score'**
  String get analyticsOverallScore;

  /// No description provided for @analyticsAnswered.
  ///
  /// In en, this message translates to:
  /// **'Answered'**
  String get analyticsAnswered;

  /// No description provided for @analyticsCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get analyticsCorrect;

  /// No description provided for @analyticsWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong'**
  String get analyticsWrong;

  /// No description provided for @analyticsTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get analyticsTotal;

  /// No description provided for @analyticsCorrectLabel.
  ///
  /// In en, this message translates to:
  /// **'✅ Correct'**
  String get analyticsCorrectLabel;

  /// No description provided for @analyticsWrongLabel.
  ///
  /// In en, this message translates to:
  /// **'❌ Wrong'**
  String get analyticsWrongLabel;

  /// No description provided for @analyticsUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock Category Analytics'**
  String get analyticsUnlockTitle;

  /// No description provided for @analyticsUnlockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See exactly which categories you struggle with.\nSubscribe to unlock full analytics.'**
  String get analyticsUnlockSubtitle;

  /// No description provided for @analyticsSubscribeButton.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to Unlock'**
  String get analyticsSubscribeButton;

  /// No description provided for @createCategoryButton.
  ///
  /// In en, this message translates to:
  /// **'Create Category'**
  String get createCategoryButton;

  /// No description provided for @upgradeToPremium.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Premium'**
  String get upgradeToPremium;

  /// No description provided for @premiumUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock Full Potential'**
  String get premiumUnlockTitle;

  /// No description provided for @premiumUnlockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Master your knowledge without limits.'**
  String get premiumUnlockSubtitle;

  /// No description provided for @featureUnlimitedQuestions.
  ///
  /// In en, this message translates to:
  /// **'Unlimited Questions'**
  String get featureUnlimitedQuestions;

  /// No description provided for @featureUnlimitedQuestionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add as many facts as you need to remember.'**
  String get featureUnlimitedQuestionsSubtitle;

  /// No description provided for @featureUnlimitedCategories.
  ///
  /// In en, this message translates to:
  /// **'Unlimited Categories'**
  String get featureUnlimitedCategories;

  /// No description provided for @featureUnlimitedCategoriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Organize your learning into specific topics.'**
  String get featureUnlimitedCategoriesSubtitle;

  /// No description provided for @featureUndoMistakes.
  ///
  /// In en, this message translates to:
  /// **'Undo Mistakes'**
  String get featureUndoMistakes;

  /// No description provided for @featureUndoMistakesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Correct a wrong answer to keep your streak alive.'**
  String get featureUndoMistakesSubtitle;

  /// No description provided for @featureAdvancedAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Advanced Analytics'**
  String get featureAdvancedAnalytics;

  /// No description provided for @featureAdvancedAnalyticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Identify your weak spots with per-category scoring.'**
  String get featureAdvancedAnalyticsSubtitle;

  /// No description provided for @featureRealTimeSync.
  ///
  /// In en, this message translates to:
  /// **'Real-time Sync'**
  String get featureRealTimeSync;

  /// No description provided for @featureRealTimeSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Seamless access across all your Android devices.'**
  String get featureRealTimeSyncSubtitle;

  /// No description provided for @getPremiumButton.
  ///
  /// In en, this message translates to:
  /// **'Get Premium — {price}'**
  String getPremiumButton(String price);

  /// No description provided for @loadingPlans.
  ///
  /// In en, this message translates to:
  /// **'Loading available plans...'**
  String get loadingPlans;

  /// No description provided for @restorePurchase.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchase'**
  String get restorePurchase;

  /// No description provided for @cancelAnytime.
  ///
  /// In en, this message translates to:
  /// **'Cancel anytime in Google Play Store. Settings > Subscriptions.'**
  String get cancelAnytime;

  /// No description provided for @purchaseFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed: {error}'**
  String purchaseFailedSnack(String error);

  /// No description provided for @premiumActiveMember.
  ///
  /// In en, this message translates to:
  /// **'You are a Premium Member!'**
  String get premiumActiveMember;

  /// No description provided for @premiumActiveDesc.
  ///
  /// In en, this message translates to:
  /// **'Thank you for supporting Random Recall. Enjoy all features unlocked.'**
  String get premiumActiveDesc;

  /// No description provided for @premiumGreat.
  ///
  /// In en, this message translates to:
  /// **'Great!'**
  String get premiumGreat;

  /// No description provided for @premiumIncludes.
  ///
  /// In en, this message translates to:
  /// **'Premium includes:'**
  String get premiumIncludes;

  /// No description provided for @premiumPerkUnlimitedQuestions.
  ///
  /// In en, this message translates to:
  /// **'✅ Unlimited questions'**
  String get premiumPerkUnlimitedQuestions;

  /// No description provided for @premiumPerkAllCategories.
  ///
  /// In en, this message translates to:
  /// **'✅ All categories'**
  String get premiumPerkAllCategories;

  /// No description provided for @premiumPerkFullAnalytics.
  ///
  /// In en, this message translates to:
  /// **'✅ Full analytics breakdown'**
  String get premiumPerkFullAnalytics;

  /// No description provided for @premiumPerkUndo.
  ///
  /// In en, this message translates to:
  /// **'✅ Undo wrong answer (rewarded)'**
  String get premiumPerkUndo;

  /// No description provided for @questionLimitReachedTitle.
  ///
  /// In en, this message translates to:
  /// **'Question Limit Reached'**
  String get questionLimitReachedTitle;

  /// No description provided for @categoryLimitReachedTitle.
  ///
  /// In en, this message translates to:
  /// **'Category Limit Reached'**
  String get categoryLimitReachedTitle;

  /// No description provided for @questionLimitReachedDesc.
  ///
  /// In en, this message translates to:
  /// **'Free accounts can store up to 20 questions (+ bonus slots from your streak). Upgrade to Premium for unlimited questions.'**
  String get questionLimitReachedDesc;

  /// No description provided for @categoryLimitReachedDesc.
  ///
  /// In en, this message translates to:
  /// **'Free accounts can add questions to up to 2 categories. Upgrade to Premium to use all categories without limits.'**
  String get categoryLimitReachedDesc;

  /// No description provided for @maybeLater.
  ///
  /// In en, this message translates to:
  /// **'Maybe later'**
  String get maybeLater;

  /// No description provided for @miuiDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Fix notifications on MIUI / HyperOS'**
  String get miuiDialogTitle;

  /// No description provided for @miuiDialogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Xiaomi phones restrict background apps by default. Two quick changes will ensure your quiz notifications arrive reliably.'**
  String get miuiDialogSubtitle;

  /// No description provided for @miuiStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Enable Background Start'**
  String get miuiStep1Title;

  /// No description provided for @miuiStep1Desc.
  ///
  /// In en, this message translates to:
  /// **'Settings → Apps → Background Start → find Random Recall → turn ON'**
  String get miuiStep1Desc;

  /// No description provided for @miuiStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Set Power to No Restrictions'**
  String get miuiStep2Title;

  /// No description provided for @miuiStep2Desc.
  ///
  /// In en, this message translates to:
  /// **'Settings → Apps → Random Recall → Power → No Restrictions'**
  String get miuiStep2Desc;

  /// No description provided for @openBackgroundStartBtn.
  ///
  /// In en, this message translates to:
  /// **'Open Background Start Settings'**
  String get openBackgroundStartBtn;

  /// No description provided for @openAppSettingsBtn.
  ///
  /// In en, this message translates to:
  /// **'Open App Settings — Set Power'**
  String get openAppSettingsBtn;

  /// No description provided for @doneDismissBtn.
  ///
  /// In en, this message translates to:
  /// **'I\'ve done this — close'**
  String get doneDismissBtn;

  /// No description provided for @notificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Time for a quick recall! 🧠'**
  String get notificationTitle;

  /// No description provided for @notificationBody.
  ///
  /// In en, this message translates to:
  /// **'Tap to answer the question'**
  String get notificationBody;

  /// No description provided for @testNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Test Notification 🧪'**
  String get testNotificationTitle;

  /// No description provided for @testNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'Tap to answer the question'**
  String get testNotificationBody;

  /// No description provided for @faqTitle.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get faqTitle;

  /// No description provided for @faqSectionNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get faqSectionNotifications;

  /// No description provided for @faqSectionQuestionBank.
  ///
  /// In en, this message translates to:
  /// **'Question Bank & Limits'**
  String get faqSectionQuestionBank;

  /// No description provided for @faqSectionChallengeMode.
  ///
  /// In en, this message translates to:
  /// **'Challenge Mode'**
  String get faqSectionChallengeMode;

  /// No description provided for @faqSectionAccountSync.
  ///
  /// In en, this message translates to:
  /// **'Account & Sync'**
  String get faqSectionAccountSync;

  /// No description provided for @faqSectionPermissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get faqSectionPermissions;

  /// No description provided for @faqQ1.
  ///
  /// In en, this message translates to:
  /// **'Why do all my notifications arrive at once when I unlock my phone?'**
  String get faqQ1;

  /// No description provided for @faqA1.
  ///
  /// In en, this message translates to:
  /// **'On Xiaomi / MIUI / HyperOS devices, the OS holds scheduled alarms while the screen is off and releases them all together when you unlock. This is Android power management — the app can\'t override it directly. Whitelisting the app in battery settings (Settings → Battery → No restrictions) reduces the delay significantly.'**
  String get faqA1;

  /// No description provided for @faqQ2.
  ///
  /// In en, this message translates to:
  /// **'Why does the badge number show fewer than the notifications in my tray?'**
  String get faqQ2;

  /// No description provided for @faqA2.
  ///
  /// In en, this message translates to:
  /// **'The badge counts unique questions pending, not the total number of notifications. If your question bank is small (e.g. 3 questions with frequency set to 6 per day), the same question is scheduled into multiple slots — but you only need to answer it once, so it counts as 1 in the badge.'**
  String get faqA2;

  /// No description provided for @faqQ3.
  ///
  /// In en, this message translates to:
  /// **'Why do multiple notifications disappear when I answer just one?'**
  String get faqQ3;

  /// No description provided for @faqA3.
  ///
  /// In en, this message translates to:
  /// **'When you answer a question, all pending reminders for that same question are cleared at once. If your question bank is small and the same question appeared in several slots, all those notifications go away together. This is correct — you\'ve answered the question, so the reminders are no longer needed.'**
  String get faqA3;

  /// No description provided for @faqQ4.
  ///
  /// In en, this message translates to:
  /// **'Why did my badge count drop after I changed my notification schedule?'**
  String get faqQ4;

  /// No description provided for @faqA4.
  ///
  /// In en, this message translates to:
  /// **'Saving new schedule settings triggers a full reschedule. In earlier versions, this could accidentally discard already-fired notifications from the badge count if their internal ID collided with a new future slot. This bug has been fixed — fired-but-unanswered notifications are now preserved through any schedule change.'**
  String get faqA4;

  /// No description provided for @faqQ5.
  ///
  /// In en, this message translates to:
  /// **'What does \"Send at any time\" mean?'**
  String get faqQ5;

  /// No description provided for @faqA5.
  ///
  /// In en, this message translates to:
  /// **'When enabled, your daily notifications are spread evenly across the full 24-hour day (midnight to 11 PM). When disabled, notifications are spaced within the time window you set (e.g. 9 AM – 6 PM). Use a time window if you only want to be reminded during waking hours.'**
  String get faqA5;

  /// No description provided for @faqQ6.
  ///
  /// In en, this message translates to:
  /// **'Why aren\'t my notifications arriving on time?'**
  String get faqQ6;

  /// No description provided for @faqA6.
  ///
  /// In en, this message translates to:
  /// **'Two common causes: (1) Battery optimisation is ON for the app — whitelist it using the prompt in Notification Schedule settings. (2) MIUI / HyperOS holds alarms while the screen is off and fires them all on unlock — see the first question above.'**
  String get faqA6;

  /// No description provided for @faqQ7.
  ///
  /// In en, this message translates to:
  /// **'How many questions can I add for free?'**
  String get faqQ7;

  /// No description provided for @faqA7.
  ///
  /// In en, this message translates to:
  /// **'The free tier starts with 20 question slots. You can earn additional slots by completing the 7-day Challenge streak (+1 slot per streak). Premium removes the limit entirely.'**
  String get faqA7;

  /// No description provided for @faqQ8.
  ///
  /// In en, this message translates to:
  /// **'How many custom categories can I create for free?'**
  String get faqQ8;

  /// No description provided for @faqA8.
  ///
  /// In en, this message translates to:
  /// **'Free accounts can create 1 custom category. The built-in \"General\" and \"Work\" categories do not count against this limit. Premium gives unlimited categories.'**
  String get faqA8;

  /// No description provided for @faqQ9.
  ///
  /// In en, this message translates to:
  /// **'What is the daily Undo?'**
  String get faqQ9;

  /// No description provided for @faqA9.
  ///
  /// In en, this message translates to:
  /// **'You can undo your last answer once per calendar day. The limit resets at midnight. This is available on both free and premium accounts.'**
  String get faqA9;

  /// No description provided for @faqQ10.
  ///
  /// In en, this message translates to:
  /// **'What is Challenge Mode and how does it work?'**
  String get faqQ10;

  /// No description provided for @faqA10.
  ///
  /// In en, this message translates to:
  /// **'Set the response timer to 20 seconds or less in Notification Schedule settings to activate Challenge Mode. Answer at least one notification per day for 7 consecutive days while Challenge Mode is active, and you permanently earn +1 free question slot. The streak resets if you miss a day.'**
  String get faqA10;

  /// No description provided for @faqQ11.
  ///
  /// In en, this message translates to:
  /// **'Does the timer affect my score if it runs out?'**
  String get faqQ11;

  /// No description provided for @faqA11.
  ///
  /// In en, this message translates to:
  /// **'Yes — if the countdown reaches zero before you answer, the question is automatically marked as incorrect. Set the timer to 0 in settings to disable it and answer at your own pace.'**
  String get faqA11;

  /// No description provided for @faqQ12.
  ///
  /// In en, this message translates to:
  /// **'Do my questions sync across devices?'**
  String get faqQ12;

  /// No description provided for @faqA12.
  ///
  /// In en, this message translates to:
  /// **'Yes. Your questions, categories, and settings are backed up to your account automatically. Signing in on a new device restores everything. You can also trigger a manual sync via Settings → Sync Data Now.'**
  String get faqA12;

  /// No description provided for @faqQ13.
  ///
  /// In en, this message translates to:
  /// **'What happens to my data if I sign out?'**
  String get faqQ13;

  /// No description provided for @faqA13.
  ///
  /// In en, this message translates to:
  /// **'Your data is saved to the cloud before sign-out completes. Nothing is deleted locally or remotely. Signing back in restores all your questions and settings.'**
  String get faqA13;

  /// No description provided for @faqQ14.
  ///
  /// In en, this message translates to:
  /// **'Why does the app ask to disable battery optimisation?'**
  String get faqQ14;

  /// No description provided for @faqA14.
  ///
  /// In en, this message translates to:
  /// **'Android\'s battery optimisation can kill scheduled alarms for apps running in the background. Whitelisting the app (a standard Android setting) tells the OS to keep its alarms active — this is the single most effective fix for missed or delayed notifications on any Android device.'**
  String get faqA14;

  /// No description provided for @faqQ15.
  ///
  /// In en, this message translates to:
  /// **'What do I lose if I deny notification permission?'**
  String get faqQ15;

  /// No description provided for @faqA15.
  ///
  /// In en, this message translates to:
  /// **'The app\'s entire purpose — timed recall prompts — stops working. You won\'t receive any questions. The permission screen will appear on every app open until permission is granted in your device settings.'**
  String get faqA15;

  /// No description provided for @onboardingSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {error}'**
  String onboardingSomethingWentWrong(String error);

  /// No description provided for @profilePageTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profilePageTitle;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneLabel;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @subscriptionStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Subscription Status'**
  String get subscriptionStatusLabel;

  /// No description provided for @subscriptionStatusPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get subscriptionStatusPremium;

  /// No description provided for @subscriptionStatusFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get subscriptionStatusFree;

  /// No description provided for @changePasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePasswordButton;

  /// No description provided for @deleteAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountButton;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'Are you sure? Account deletion is permanent. All your data will be deleted.'**
  String get deleteAccountWarning;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountConfirm;

  /// No description provided for @deleteAccountCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get deleteAccountCancel;

  /// No description provided for @profilePictureSourceCamera.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get profilePictureSourceCamera;

  /// No description provided for @profilePictureSourceGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get profilePictureSourceGallery;

  /// No description provided for @profilePictureUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile picture updated'**
  String get profilePictureUpdated;

  /// No description provided for @profilePictureUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile picture'**
  String get profilePictureUpdateFailed;

  /// No description provided for @profileUpdateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully'**
  String get profileUpdateSuccess;

  /// No description provided for @profileUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile'**
  String get profileUpdateFailed;

  /// No description provided for @passwordChangedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully'**
  String get passwordChangedSuccess;

  /// No description provided for @passwordChangedFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to change password'**
  String get passwordChangedFailed;

  /// No description provided for @accountDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account deleted successfully'**
  String get accountDeletedSuccess;

  /// No description provided for @accountDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account'**
  String get accountDeleteFailed;

  /// No description provided for @googleAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Google Account'**
  String get googleAccountLabel;

  /// No description provided for @emailAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailAccountLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
