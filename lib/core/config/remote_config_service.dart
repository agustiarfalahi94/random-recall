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
  int get notifStartHour => _rc.getInt('notif_start_hour');
  int get notifEndHour => _rc.getInt('notif_end_hour');

  // NOTE: the plan-limit getters (free/premium question + category caps and
  // their warning thresholds) were removed with the premium tier. This app is a
  // single full version with no caps, so there is nothing to tune remotely.
}
