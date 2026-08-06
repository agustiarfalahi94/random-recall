# Interactive Tutorial Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a one-time interactive spotlight tutorial (coach marks) for new users that runs after onboarding on the real app, highlighting Home → Questions → Analytics with a forced-tap pattern, re-runnable from Settings.

**Architecture:** Use `showcaseview` for the spotlight overlay. A `TourService` singleton owns the `tour_completed` pref flag and the step sequence; `tour_overlay.dart` hosts the multi-step driver. GlobalKeys on real controls (Practice Now, nav tabs, Settings gear, Questions FAB, settings-sheet schedule tile). Tour starts after the display-name prompt resolves.

**Tech Stack:** Flutter/Dart, `showcaseview` ^5.1.0, provider (state), shared_preferences, existing l10n en/id.

## Global Constraints

- Branch: work on **`develop`**.
- `flutter analyze` must be **0 issues**; `dart format --set-exit-if-changed lib/ test/` clean; existing **105/105** tests still pass + new.
- All user-facing tour copy must be added to BOTH `app_en.arb` and `app_id.arb`, then `flutter gen-l10n`.
- Do NOT add a profile photo/avatar; do NOT spotlight the Profile tab.
- The tour runs **after** onboarding (`onboarding_complete` true), only when `tour_completed` is unset, and can re-run from Settings.
- Keep `showcaseview` in one place: screens only expose `GlobalKey`s; `tour_overlay.dart` owns the driver.

---

## File Structure

- `lib/core/tutorial/tour_service.dart` — new: `TourService` (pref flag + step definitions)
- `lib/widgets/tour/tour_overlay.dart` — new: `TourOverlay` (hosts the showcaseview driver + Skip + done overlay)
- `lib/screens/home/home_screen.dart` — modify: add GlobalKeys (Practice Now, nav Home/Questions/Analytics, Settings gear); trigger tour; add "Take a tour" settings tile
- `lib/screens/question/questions_list_screen.dart` — modify: add GlobalKey to the Add FAB
- `pubspec.yaml` — add `showcaseview: ^5.1.0`
- `lib/l10n/app_en.arb` + `app_id.arb` — add tour strings
- `test/core/tutorial/tour_service_test.dart` — new: pref-flag logic
- `docs/SESSION_NOTES.md` — resume note update

---

### Task 1: Add `showcaseview` + `TourService` + flag logic

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/core/tutorial/tour_service.dart`
- Test: `test/core/tutorial/tour_service_test.dart`

**Interfaces:**
- Produces:
  - `bool shouldShowTour()` — `!prefs.getBool('tour_completed')`
  - `Future<void> markCompleted()`, `markSkipped()` — set `tour_completed = true`
  - Step definitions: a `List<TourStep>` (ordered) where each has a `GlobalKey`, a copy key, and a behavior enum (`runAction`, `tapThrough`, `tabSwitch`, `done`).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:random_recall/core/tutorial/tour_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TourService', () {
    late TourService tour;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tour = TourService();
      await tour.initialize();
    });

    test('shouldShowTour is true when flag absent', () {
      expect(tour.shouldShowTour(), true);
    });

    test('markCompleted sets flag and hides tour', () async {
      await tour.markCompleted();
      expect(tour.shouldShowTour(), false);
    });

    test('markSkipped sets flag and hides tour', () async {
      await tour.markSkipped();
      expect(tour.shouldShowTour(), false);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/tutorial/tour_service_test.dart`
Expected: FAIL — `TourService` / methods not defined.

- [ ] **Step 3: Implement `TourService`**

```dart
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
```

- [ ] **Step 4: Add the dependency**

```bash
flutter pub add showcaseview:^5.1.0
```

Run: `flutter pub get` — resolves.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/core/tutorial/tour_service_test.dart`
Expected: PASS.

- [ ] **Step 6: Full validation**

Run: `flutter analyze && dart format --set-exit-if-changed lib/ test/ && flutter test`
Expected: 0 issues; format clean; 105 + new pass.

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/tutorial/tour_service.dart test/core/tutorial/tour_service_test.dart
git commit -m "feat(tour): showcaseview dep + TourService flag logic"
```

---

### Task 2: Localize the tour strings (en + id)

**Files:**
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_id.arb`

**Interfaces:**
- Consumes: the `copyKey`s from Task 1 (`tourPracticeBody` … `tourDoneBody`, `tourSkip`, `tourReplayTile`, `tourReplaySubtitle`).
- Produces: generated `AppLocalizations` getters for all tour strings.

- [ ] **Step 1: Add the ARB keys to `app_en.arb`**

Add to the end of the `app_en.arb` JSON (matching existing key style):

```json
"tourPracticeBody": "Tap **Practice Now** to answer questions from your saved categories.",
"tourQuestionsBody": "Your **Questions** library lives here — add, edit, and organize.",
"tourAddBody": "Tap **+** to add a new question.",
"tourAnalyticsBody": "See your accuracy for each category in **Analytics**.",
"tourHomeBody": "Head back **Home** when you're ready to practice.",
"tourSettingsBody": "Open **Settings** to manage sync, notifications, and more.",
"tourScheduleBody": "Schedule when Random Recall sends you reminders.",
"tourDoneBody": "You're all set! 🎉 Tap anywhere to finish.",
"tourSkip": "Skip",
"tourReplayTile": "Take a tour",
"tourReplaySubtitle": "Replay the interactive guide"
```

> The **bolded** names (Practice Now, Questions, etc.) should match the app's actual localized labels. Verify against the existing `app_en.arb` keys (e.g. `practiceNow`, `navQuestions`, `navAnalytics`, `navHome`) and align the wording so the copy and the highlighted control agree.

- [ ] **Step 2: Add the Indonesian translations to `app_id.arb`**

```json
"tourPracticeBody": "Ketuk **Mulai Latihan** untuk menjawab pertanyaan dari kategori tersimpanmu.",
"tourQuestionsBody": "Perpustakaan **Pertanyaan** ada di sini — tambah, edit, dan atur.",
"tourAddBody": "Ketuk **+** untuk menambah pertanyaan baru.",
"tourAnalyticsBody": "Lihat akurasi setiap kategori di **Analytics**.",
"tourHomeBody": "Kembali ke **Beranda** saat siap berlatih.",
"tourSettingsBody": "Buka **Pengaturan** untuk mengelola sinkronisasi, notifikasi, dan lainnya.",
"tourScheduleBody": "Atur kapan Random Recall mengirim pengingat.",
"tourDoneBody": "Semua siap! 🎉 Ketuk di mana saja untuk selesai.",
"tourSkip": "Lewati",
"tourReplayTile": "Panduan interaktif",
"tourReplaySubtitle": "Lihat kembali panduan interaktif"
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4: Verify the getters exist**

Run: `grep -n "tourPracticeBody\|tourDoneBody\|tourSkip\|tourReplayTile" lib/l10n/app_localizations.dart`
Expected: the generated getters are present.

- [ ] **Step 5: Full validation**

Run: `flutter analyze && dart format --set-exit-if-changed lib/ test/ && flutter test`
Expected: 0 issues; format clean; all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_id.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_id.dart
git commit -m "feat(l10n): tour copy in en + id"
```

---

### Task 3: Add GlobalKeys to Home + Questions screens

**Files:**
- Modify: `lib/screens/home/home_screen.dart`, `lib/screens/question/questions_list_screen.dart`

**Interfaces:**
- Consumes: `TourService.instance` keys from Task 1.
- Produces: GlobalKeys wrapped around Practice Now, the nav Home/Questions/Analytics destinations, the Settings gear, and the Questions Add FAB.

- [ ] **Step 1: Wrap Practice Now + Settings gear in Home**

In `home_screen.dart`:
- Practice Now `ElevatedButton.icon` (in `_HomeTabState.build`): wrap with `KeyedSubtree(key: TourService.instance.practiceButtonKey, child: ElevatedButton.icon(...))`.
- Settings gear `IconButton` (in `_HomeScreenState` AppBar actions): wrap with `KeyedSubtree(key: TourService.instance.settingsGearKey, child: IconButton(...))`.

> Use `KeyedSubtree` to attach the key without changing the button's layout. Alternatively `GlobalKey` directly on the widget.

- [ ] **Step 2: Wrap the nav destinations**

For the Home / Questions / Analytics `NavigationDestination`s, wrap each destination's `icon`/`selectedIcon` (or the destination itself) with the corresponding key (`navHomeKey`, `navQuestionsKey`, `navAnalyticsKey`). Since `NavigationDestination` is not a widget you can put a key on directly, wrap the icon: `icon: KeyedSubtree(key: TourService.instance.navHomeKey, child: Icon(...))`. Keep `selectedIcon` matching.

- [ ] **Step 3: Wrap the Add FAB in Questions**

In `questions_list_screen.dart`, wrap the `FloatingActionButton` with `KeyedSubtree(key: TourService.instance.addFabKey, child: FloatingActionButton(...))`.

- [ ] **Step 4: Verify the keys compile**

Run: `flutter analyze`
Expected: 0 issues (keys are attached; no behavior change yet).

- [ ] **Step 5: Full validation**

Run: `flutter analyze && dart format --set-exit-if-changed lib/ test/ && flutter test`
Expected: 0 issues; format clean; all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/home/home_screen.dart lib/screens/question/questions_list_screen.dart
git commit -m "feat(tour): attach GlobalKeys to tour targets"
```

---

### Task 4: The `TourOverlay` driver

**Files:**
- Create: `lib/widgets/tour/tour_overlay.dart`

**Interfaces:**
- Consumes: `TourService.instance` (steps, keys, `markCompleted`/`markSkipped`), `AppLocalizations` copy.
- Produces: `class TourOverlay extends StatefulWidget` with `void start()` — shows the tour overlay and drives the steps. Uses `Showcase` widgets from `showcaseview` wrapping a `ShowcaseController`.

- [ ] **Step 1: Write the overlay driver**

`TourOverlay` is a full-screen `Stack` that wraps the app content (or sits in the root `Overlay`) with a series of `Showcase` widgets, one per `TourStep`, driven by a `ShowcaseController`. Because the exact `showcaseview` API (controller usage, onTargetClick vs tap-anywhere) must be verified against the resolved package, this task:

- [ ] **Step 2: Verify the `showcaseview` API against the installed source**

After `flutter pub get` in Task 1, the package source is at `~/.pub-cache/hosted/pub.dev/showcaseview-5.1.0/lib/`. Read `showcaseview.dart` / `showcase.dart` / `showcase_controller.dart` to confirm:
- The `Showcase` constructor's named parameters (at least `key`, `title`, `description`).
- How to advance: `onTargetClick` (tap the target to advance) vs a tap-anywhere behavior, and the `ShowcaseController` method to move to the next showcase (e.g. `startShowcase` / `next`).
- Whether a `GlobalKey` on a target inside a modal bottom sheet is addressable by the root overlay.

Then implement `TourOverlay` to:
1. Wrap the app's content in `Showcase` widgets (one per step, keyed).
2. Show them in sequence; each step shows a tooltip with the copy for that step's `copyKey`.
3. **runAction / tabSwitch steps:** let the target's normal `onTap` fire; advance when the route/sheet closes, or after a post-frame for tab switches.
4. **tapThrough step (7):** advance on tap anywhere (no real action).
5. **done step (8):** show the "You're all set 🎉" overlay, tap-anywhere to finish → `markCompleted()`.
6. **Skip button:** visible on every step → `markSkipped()` + dismiss.
7. Handle the **advance-on-close** rule for steps 1/3/6 per the spec.

> **If the installed API makes the in-sheet spotlight (step 7) unreliable** (target not addressable inside the modal sheet), fall back to the spec's documented fallback: step 7 is a plain text overlay over the sheet with tap-anywhere advance, no target highlight.

- [ ] **Step 3: Full validation**

Run: `flutter analyze && dart format --set-exit-if-changed lib/ test/ && flutter test && flutter build apk --debug`
Expected: 0 issues; format clean; all pass; debug APK builds.

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/tour/tour_overlay.dart
git commit -m "feat(tour): TourOverlay driver with showcaseview"
```

---

### Task 5: Trigger the tour + Settings re-entry

**Files:**
- Modify: `lib/screens/home/home_screen.dart`

**Interfaces:**
- Consumes: `TourService`, `TourOverlay`.
- Produces: the tour auto-starts after the display-name prompt resolves (first Home after onboarding), and a "Take a tour" tile in the Settings sheet re-runs it.

- [ ] **Step 1: Trigger on first Home after onboarding**

In `_HomeTabState`, after the display-name prompt handling resolves (either "no display name needed" or the dialog's `onComplete`), if `TourService.instance.shouldShowTour()` is true, call the `TourOverlay` start (via a post-frame callback, ~300ms settle). If the rooted-device warning is showing, wait for it to be dismissed before starting.

- [ ] **Step 2: Add the Settings re-entry tile**

In `_SettingsSheetState.build`, add a `ListTile` with `title: l10n.tourReplayTile`, `subtitle: l10n.tourReplaySubtitle`, that dismisses the sheet and starts the tour. Give it `TourService.instance.scheduleTileKey`? No — the settings-sheet tour target (step 7) is the *notification schedule* tile. The replay tile is separate; give it its own key (`replayTileKey`) if needed, but it does NOT need a spotlight.

- [ ] **Step 3: Full validation**

Run: `flutter analyze && dart format --set-exit-if-changed lib/ test/ && flutter test`
Expected: 0 issues; format clean; all pass.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/home/home_screen.dart
git commit -m "feat(tour): auto-start after onboarding + Settings re-entry"
```

---

### Task 6: Final validation + doc sync

**Files:**
- Modify: `CHANGELOG.md`, `docs/SESSION_NOTES.md`

- [ ] **Step 1: Full validation**

Run: `flutter analyze && dart format --set-exit-if-changed lib/ test/ && flutter test && flutter build apk --debug`
Expected: 0 issues; format clean; all pass; debug APK builds.

- [ ] **Step 2: Update CHANGELOG**

Add an entry (or extend the `[Unreleased]` block) describing the interactive tutorial: after-onboarding coach-mark tour, re-runnable from Settings, en+id.

- [ ] **Step 3: Update SESSION_NOTES**

Replace the §11 resume block: mark the tutorial as implemented, note the key design decisions honored, and update the file-map if needed.

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md docs/SESSION_NOTES.md
git commit -m "docs: changelog + session notes for interactive tutorial"
```

---

## Self-Review Notes

**Spec coverage:**
- showcaseview dep + TourService flag logic → Task 1
- en+id localization → Task 2
- GlobalKeys on real controls → Task 3
- TourOverlay driver (advance-on-close, skip, done) → Task 4
- Trigger after onboarding + Settings re-entry → Task 5
- Final validation + docs → Task 6

**Placeholder scan:** The one soft spot is Task 4 Step 2, which explicitly verifies the `showcaseview` API against the installed source before writing the driver — a deliberate, stated exception because the exact API (onTargetClick vs tap-anywhere, controller methods) could not be confirmed from the docs without the installed package. The step is concrete (read the source, confirm the params, implement per the spec). No TBD/TODO.

**Type consistency:** `TourService.instance` keys (`practiceButtonKey`, `navHomeKey`, `navQuestionsKey`, `navAnalyticsKey`, `settingsGearKey`, `addFabKey`, `scheduleTileKey`), `TourStep` (targetKey/copyKey/behavior/closesSheetOnAdvance), `TourStepBehavior` (runAction/tapThrough/tabSwitch/done), `shouldShowTour/markCompleted/markSkipped`, and `TourOverlay` are defined once in Task 1/4 and used consistently in Tasks 3/5. Copy keys match the ARB keys in Task 2.
