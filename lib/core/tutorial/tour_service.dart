// lib/core/tutorial/tour_service.dart
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TourStepBehavior { runAction, tapThrough, tabSwitch, done }

class TourStep {
  final GlobalKey targetKey;
  final String copyKey; // ARB key for this step's body text
  final TourStepBehavior behavior;
  final bool closesSheetOnAdvance; // only for runAction steps that open a sheet

  const TourStep({
    required this.targetKey,
    required this.copyKey,
    required this.behavior,
    this.closesSheetOnAdvance = false,
  });
}

class TourService {
  TourService._();
  static final TourService instance = TourService._();

  // Public factory so callers (and tests) can write `TourService()` while
  // still receiving the single shared instance. Same pattern as StreakService.
  factory TourService() => instance;

  static const _completedKey = 'tour_completed';

  late SharedPreferences _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  bool shouldShowTour() => !(_prefs.getBool(_completedKey) ?? false);

  Future<void> markCompleted() async => _prefs.setBool(_completedKey, true);
  Future<void> markSkipped() async => _prefs.setBool(_completedKey, true);

  // The GlobalKeys are created here so screens and the overlay share them.
  // The keys are attached by wrapping the target widgets in each screen.
  final practiceButtonKey = GlobalKey();
  final navHomeKey = GlobalKey();
  final navQuestionsKey = GlobalKey();
  final navAnalyticsKey = GlobalKey();
  final settingsGearKey = GlobalKey();
  final addFabKey = GlobalKey();
  final scheduleTileKey = GlobalKey();

  List<TourStep> get steps => [
    TourStep(
      targetKey: practiceButtonKey,
      copyKey: 'tourPracticeBody',
      behavior: TourStepBehavior.runAction,
    ),
    TourStep(
      targetKey: navQuestionsKey,
      copyKey: 'tourQuestionsBody',
      behavior: TourStepBehavior.tabSwitch,
    ),
    TourStep(
      targetKey: addFabKey,
      copyKey: 'tourAddBody',
      behavior: TourStepBehavior.runAction,
      closesSheetOnAdvance: true,
    ),
    TourStep(
      targetKey: navAnalyticsKey,
      copyKey: 'tourAnalyticsBody',
      behavior: TourStepBehavior.tabSwitch,
    ),
    TourStep(
      targetKey: navHomeKey,
      copyKey: 'tourHomeBody',
      behavior: TourStepBehavior.tabSwitch,
    ),
    TourStep(
      targetKey: settingsGearKey,
      copyKey: 'tourSettingsBody',
      behavior: TourStepBehavior.runAction,
    ),
    TourStep(
      targetKey: scheduleTileKey,
      copyKey: 'tourScheduleBody',
      behavior: TourStepBehavior.tapThrough,
    ),
    TourStep(
      targetKey: GlobalKey(), // no target — final step
      copyKey: 'tourDoneBody',
      behavior: TourStepBehavior.done,
    ),
  ];
}
