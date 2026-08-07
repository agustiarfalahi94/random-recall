// lib/core/tutorial/tour_service.dart
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';

enum TourStepBehavior { runAction, tapThrough, tabSwitch, tapToAdvance, done }

class TourStep {
  final GlobalKey targetKey;
  final String copyKey; // ARB key for this step's body text
  final TourStepBehavior behavior;

  const TourStep({
    required this.targetKey,
    required this.copyKey,
    required this.behavior,
  });
}

class TourService {
  TourService._();
  static final TourService instance = TourService._();

  /// Whether the interactive tour is live.
  ///
  /// REDESIGNED 2026-08-06: the tour now wraps the REAL widgets in
  /// `Showcase(key: ..., child: ...)` (showcaseview's intended API) instead of
  /// the old overlay-box approach that shared GlobalKeys between targets and
  /// showcases (which corrupted the element tree — "RenderBox was not laid
  /// out" crash). Verified on-device before this flag was flipped back on.
  static const bool enabled = true;

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

  /// Dev/testing helper: clears the completion flag so the tour auto-starts
  /// again (or can be re-run from Settings).
  Future<void> resetCompleted() async => _prefs.remove(_completedKey);

  // The GlobalKeys are created here so screens and the overlay share them.
  // The keys are attached to the `Showcase` wrappers in each screen (via
  // `TourTarget`), and each key is used by EXACTLY ONE showcase.
  final practiceButtonKey = GlobalKey();
  final navHomeKey = GlobalKey();
  final navQuestionsKey = GlobalKey();
  final navAnalyticsKey = GlobalKey();
  final settingsGearKey = GlobalKey();
  final addFabKey = GlobalKey();
  final scheduleTileKey =
      GlobalKey(); // step 7: overlay fallback, no real target
  final donePlaceholderKey = GlobalKey(); // step 8: no target

  TourStep? stepForKey(GlobalKey key) {
    for (final step in steps) {
      if (step.targetKey == key) return step;
    }
    return null;
  }

  /// Localized tooltip copy for the step targeting [key], with '**' emphasis
  /// markers stripped (showcaseview renders plain text).
  String copyFor(AppLocalizations l10n, GlobalKey key) {
    final step = stepForKey(key);
    if (step == null) return '';
    return _copy(l10n, step.copyKey).replaceAll('**', '');
  }

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
      // Tap-to-advance: the + FAB is just being pointed at — do NOT fire its
      // real action (which would open/close the add menu and feel like a
      // delay), and never risk getting stuck behind a sheet.
      behavior: TourStepBehavior.tapToAdvance,
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
      targetKey: donePlaceholderKey,
      copyKey: 'tourDoneBody',
      behavior: TourStepBehavior.done,
    ),
  ];

  String _copy(AppLocalizations l10n, String copyKey) {
    switch (copyKey) {
      case 'tourPracticeBody':
        return l10n.tourPracticeBody;
      case 'tourQuestionsBody':
        return l10n.tourQuestionsBody;
      case 'tourAddBody':
        return l10n.tourAddBody;
      case 'tourAnalyticsBody':
        return l10n.tourAnalyticsBody;
      case 'tourHomeBody':
        return l10n.tourHomeBody;
      case 'tourSettingsBody':
        return l10n.tourSettingsBody;
      case 'tourScheduleBody':
        return l10n.tourScheduleBody;
      case 'tourDoneBody':
        return l10n.tourDoneBody;
      default:
        return copyKey;
    }
  }
}
