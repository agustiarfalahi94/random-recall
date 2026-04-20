import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Thin accessor for Firebase Remote Config values.
///
/// All keys have in-code defaults set during app startup (main.dart) that
/// mirror the previous hardcoded values, so behaviour is unchanged until
/// a value is explicitly overridden in the Firebase Console.
class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  final FirebaseRemoteConfig _rc = FirebaseRemoteConfig.instance;

  // Notification settings
  int get notifFrequencyFree => _rc.getInt('notif_frequency_free');
  int get notifFrequencyPremium => _rc.getInt('notif_frequency_premium');
  int get notifStartHour => _rc.getInt('notif_start_hour');
  int get notifEndHour => _rc.getInt('notif_end_hour');

  // Free-tier plan limits
  int get freeQuestionBase => _rc.getInt('free_question_base');
  int get freeMaxCustomCategories => _rc.getInt('free_max_custom_categories');

  // Premium-tier plan limits
  int get premiumMaxCustomCategories =>
      _rc.getInt('premium_max_custom_categories');
  int get premiumQuestionLimit => _rc.getInt('premium_question_limit');
  int get categoryWarningThreshold =>
      _rc.getInt('category_warning_threshold');
  int get questionWarningThreshold =>
      _rc.getInt('question_warning_threshold');
}
