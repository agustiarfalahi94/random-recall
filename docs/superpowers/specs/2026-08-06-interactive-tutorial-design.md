# Interactive Tutorial (Coach Marks) Design

## Goal

Add a one-time, interactive spotlight tutorial for new users that runs **after onboarding completes**, highlighting real app controls (Home → Questions → Analytics) using a forced-tap "lock everything else" pattern, and is re-runnable from Settings.

Product decisions confirmed with the user:
- **Run point:** after onboarding, on the real app (not inside the onboarding flow).
- **Scope:** core journey (~8 spotlight steps), not a full app tour.
- **Profile tab:** explicitly NOT part of the tour (respects the no-profile-photo stance).

## Architecture

Use the `showcaseview` package for coach-mark overlays. It wraps each real target widget with a `Showcase` (via a `GlobalKey`), dims everything outside a spotlight, and intercepts taps except on the highlighted target. A `ShowcaseController` drives the multi-step sequence.

A new `TourService` owns the tour's state machine:
- `bool shouldShowTour()` — reads a new `SharedPreferences` flag `tour_completed` (default false).
- `void markCompleted()` / `void markSkipped()` — both set `tour_completed = true`.
- The tour is **started** from the Home screen's first post-frame callback (after onboarding), and **re-started** from a new Settings tile.

### Trigger coordination (important)

On the first Home build after onboarding, the display-name prompt dialog (non-dismissible for new users) also appears. The tour must **not** fight it for the overlay. Design decision: **the tour start is gated on the display-name prompt being resolved** — it starts from the display-name handling's completion path (the "no display name needed" branch, or the dialog's `onComplete`), plus a short settle delay (~300 ms). This guarantees the tour never appears on top of the display-name setup. The rooted-device warning is dismissible and rare; if it's showing when the tour is ready, the tour waits for it to be dismissed (poll a flag the warning sets).

### Advance-on-close rule (the fiddly part)

Several tour targets run a real action that pushes a **route or opens a bottom sheet**. If the tour just advanced, the next step's target would be hidden behind that route. So the tour follows an explicit rule:

- **Target opens a route/sheet that covers the next target** → the tour lets the action happen, then **closes what it opened** before showing the next step:
  - Step 1 (Practice Now → pushes QuestionScreen): advance when the pushed route pops (user backs out). No auto-close.
  - Step 3 (+ Add FAB → opens the Add-menu bottom sheet): the tour pops the Add menu after a short delay (~600 ms so the user sees it), then advances to step 4.
  - Step 6 (Settings gear → opens the settings sheet): keep the sheet open — step 7's target is *inside* it. Close the sheet after the final (done) step.
- **Target is a bottom-nav tab switch** (steps 2, 4, 5): the destination's normal `onTap` fires (changes `_currentIndex`) AND the tour advances — after a post-frame callback, once the newly-shown screen is settled.

### In-sheet spotlight (step 7)

`showcaseview` inserts its overlay into the **root `Overlay`**, which sits above the modal-bottom-sheet route, so a `GlobalKey` on a tile inside `_SettingsSheet` is still addressable. Before advancing to any step whose target lives on a freshly-shown screen or sheet, the tour waits a frame and verifies the target's `GlobalKey` context is attached (retry next frame if not). **Fallback if on-device testing shows the in-sheet spotlight is unreliable:** replace step 7 with a plain text overlay over the sheet (tap-anywhere advance), no target highlight.

## New files

- `lib/core/tutorial/tour_service.dart` — `TourService` singleton: owns `tour_completed` flag, `shouldShowTour()`, `markCompleted()`, `markSkipped()`, and the step definitions (target keys + copy keys).
- `lib/widgets/tour/tour_overlay.dart` — a thin wrapper/host around `showcaseview`'s controller that owns the 8-step sequence, the Skip button, and the final "all set" overlay. (Keeps the showcaseview dependency in one place so screens only expose `GlobalKey`s.)

## Modified files

- `pubspec.yaml` — add `showcaseview`.
- `lib/screens/home/home_screen.dart` — add `GlobalKey`s: Practice Now button, the 3 tour-relevant nav destinations (Home/Questions/Analytics), and the Settings gear. Trigger the tour in a post-frame callback when `tour_completed` is false. Add a "Take a tour" tile to `_SettingsSheet` (re-entry) with its own key.
- `lib/screens/question/questions_list_screen.dart` — add a `GlobalKey` to the FloatingActionButton (Add).
- `lib/l10n/app_en.arb` + `app_id.arb` — new tour strings (then `flutter gen-l10n`).
- `docs/SESSION_NOTES.md` — note the feature and this spec/plan paths (resume-point convention).

## The 8 tour steps

| # | Screen | Spotlight target | Tap behavior |
|---|---|---|---|
| 1 | Home | Practice Now | Starts a real practice session |
| 2 | Home | Questions tab (bottom nav) | Switches to Questions tab |
| 3 | Questions | + Add FAB | Opens the Add menu |
| 4 | Questions | Analytics tab (bottom nav) | Switches to Analytics tab |
| 5 | Analytics | Home tab (bottom nav) | Switches back to Home |
| 6 | Home | Settings gear | Opens the settings sheet |
| 7 | Settings sheet | Notification schedule tile | **Tap-through only** — advances the tour WITHOUT pushing the schedule screen, so the tour isn't stranded on a new route |
| 8 | — | — | Final "You're all set 🎉" overlay; sets `tour_completed` |

Steps 1–6 are genuine forced taps that run the real action. Step 7 is the single deliberate exception (tap-anywhere advance).

**Skip:** a visible "Skip" button on every step; tapping it dismisses the tour and sets `tour_completed`.

## Localization

New ARB keys (both `app_en.arb` and `app_id.arb`, matching the app's existing naming):

| Key | en | id |
|---|---|---|
| `tourPracticeBody` | Tap **Practice Now** to answer questions from your saved categories. | Ketuk **Mulai Latihan** untuk menjawab pertanyaan dari kategori tersimpanmu. |
| `tourQuestionsBody` | Your **Questions** library lives here — add, edit, and organize. | Perpustakaan **Pertanyaan** ada di sini — tambah, edit, dan atur. |
| `tourAddBody` | Tap **+** to add a new question. | Ketuk **+** untuk menambah pertanyaan baru. |
| `tourAnalyticsBody` | See your accuracy for each category in **Analytics**. | Lihat akurasi setiap kategori di **Analytics**. |
| `tourHomeBody` | Head back **Home** when you're ready to practice. | Kembali ke **Beranda** saat siap berlatih. |
| `tourSettingsBody` | Open **Settings** to manage sync, notifications, and more. | Buka **Pengaturan** untuk mengelola sinkronisasi, notifikasi, dan lainnya. |
| `tourScheduleBody` | Schedule when Random Recall sends you reminders. | Atur kapan Random Recall mengirim pengingat. |
| `tourDoneBody` | You're all set! 🎉 Tap anywhere to finish. | Semua siap! 🎉 Ketuk di mana saja untuk selesai. |
| `tourSkip` | Skip | Lewati |
| `tourReplayTile` | Take a tour | Panduan interaktif |
| `tourReplaySubtitle` | Replay the interactive guide | Lihat kembali panduan interaktif |

> The bolded control names in the copy (e.g. **Practice Now**, **+**) should match the app's actual localized labels from the existing ARB keys (e.g. `practiceNow`) so the copy and the highlighted control agree in both languages.

## Edge cases

| Scenario | Behaviour |
|---|---|
| New user with zero questions taps Practice Now | Opens the practice screen's normal empty state — the tour doesn't block it |
| Tour interrupted (app killed / notification opens a route) | `tour_completed` not set; the tour re-runs on next Home launch. Acceptable — the user didn't finish or skip |
| Display-name / root-warning dialog appears at first Home | Tour defers until Home is settled and no dialog is showing (trigger coordination above) |
| Tab target not yet built (lazy `IndexedStack`) | Tour waits a frame and retries until the `GlobalKey` context is attached |
| Large font / small screen | Spotlight sizes to the target; overlay text is width-constrained and can scroll |
| Locale switched mid-tour | Copy is resolved at build time; a mid-tour switch simply shows the old strings for the rest of the tour (accepted) |
| Notification fires mid-tour | A pushed question route covers the tour; the tour state is abandoned (same as interrupt) |

## Testing

- `TourService` pure-logic unit tests: `shouldShowTour()` false after `markCompleted()`/`markSkipped()`; default true when flag absent.
- A widget test that, with `tour_completed` unset, the Home screen schedules the tour to start (overlay appears on first frame / after the trigger delay). Keep it minimal — `showcaseview` overlays are UI-heavy; avoid asserting exact pixel shapes.
- Full-suite validation: `flutter analyze` (0 issues), `dart format --set-exit-if-changed lib/ test/`, `flutter test` (105 existing + new), `flutter build apk --debug`.

## Out of scope

- Full app tour (deep content of every tab).
- Profile tab (respects the no-profile-photo stance).
- Video/animated onboarding.
- Tour shown to existing users automatically (only via Settings re-entry).

## Effort

~8–12h (1.5–2 focused days): library setup, tour controller + trigger, 8 targets across 3 screens, tab-switch dance, Settings re-entry, en+id localization, validation.
