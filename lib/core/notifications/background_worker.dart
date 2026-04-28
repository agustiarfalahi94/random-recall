import 'package:workmanager/workmanager.dart';

import '../streak/streak_service.dart';
import 'notification_service.dart';

const _kTaskName = 'reschedule_notifications';

/// WorkManager background callback — must be a top-level function so Dart's
/// tree-shaker keeps it alive in release builds.
///
/// Runs every 6 hours. Calls [NotificationService.scheduleNotifications] to
/// rebuild the 7-day notification window even if the user hasn't opened the app.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      // Re-initialise everything needed in this background isolate.
      // StreakService must be initialised before NotificationService.scheduleNotifications()
      // because it reads isChallengeActive / lockedActiveDaysCsv via the late _prefs field.
      await StreakService.instance.initialize();
      await NotificationService.instance.init();
      await NotificationService.instance.scheduleNotifications();
      return true;
    } catch (_) {
      return false;
    }
  });
}

/// Registers the periodic rescheduling task with WorkManager.
///
/// Call once from [main] after [NotificationService.init].
/// [ExistingWorkPolicy.keep] prevents the schedule from being reset on every
/// app launch — the task fires ~every 6 hours regardless of app opens.
Future<void> registerNotificationWorker() async {
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    _kTaskName,
    _kTaskName,
    frequency: const Duration(hours: 6),
    constraints: Constraints(networkType: NetworkType.notRequired),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    backoffPolicy: BackoffPolicy.linear,
    backoffPolicyDelay: const Duration(minutes: 15),
  );
}
