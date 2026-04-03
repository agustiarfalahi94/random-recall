# Changelog

All notable changes to Random Recall are documented here.
Format: **Added** · **Fixed** · **Changed** · **Removed**

---

## [1.2.0] — 2026-04-03

### Added
- **WorkManager background rescheduler** — rebuilds the 7-day notification
  window every 6 hours even when the app is not open; survives Doze mode,
  process death, and device reboots (`workmanager` package)
- **MIUI / HyperOS notification guide** — Xiaomi devices show a step-by-step
  tutorial (Autostart + No Restrictions battery setting) immediately after
  onboarding and via a persistent card in Notification Settings
- `NotificationScheduler` — pure scheduling logic extracted from
  `NotificationService`; fully unit-testable with no platform channels or DB
- 18 new unit tests for `NotificationScheduler` (43 total suite tests pass)
- Onboarding notification page now matches the settings screen exactly:
  Daily / Weekdays / Weekends preset chips, individual square day chips,
  and time picker rows with sun/moon icon containers
- Active days section visible regardless of "Anytime" vs "Set time range"
- "Skip for now" button on the notification onboarding page when permission
  is denied, so users are never stuck
- Back buttons on onboarding sub-pages (Your First Question and Notifications)
- Default active days set to Daily in onboarding
- General category pre-selected by default in the Your First Question page

### Fixed
- **Critical** — Notifications stop after 7 days if the app isn't opened:
  WorkManager now reschedules automatically in the background
- **Critical** — Notifications never delivered on Xiaomi 15 / Xiaomi 12T:
  `tz.local` defaulted to UTC; fixed by calling `setLocalLocation()` with the
  device's real IANA timezone at startup
- **Critical** — `AndroidScheduleMode.exactAllowWhileIdle` silently failed
  on Android 12+ without the "Alarms & Reminders" grant; switched to
  `inexactAllowWhileIdle`
- Onboarding resets to page 1 after returning from Android notification
  settings: draft now persisted to SharedPreferences and restored on cold start
- Onboarding page state (question, answer, category) lost when navigating back
  after touching the category dropdown: fixed with `AutomaticKeepAliveClientMixin`
- Practice Now sessions no longer add to score history or streak
- Test notification no longer records a score entry or counts toward streak
- End time validation false positive: start 1:12 PM + end 1:15 PM (same hour)
  incorrectly showed "End time must be after start time"
- Default active days fallback in scheduler corrected from weekdays to daily
- Category dropdown in Add Question no longer shows locked/dimmed items

### Changed
- `scheduleNotifications()` now fetches all questions in one DB call instead of
  N per-slot queries — cleaner and faster
- Free plan category use limit removed — questions can be added to any category
  freely (1 custom category creation limit remains)
- `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` removed from AndroidManifest

### Removed
- `freeCategoryLimit`, `getCategoryLimit()`, `canUseCategory()` from PlanService
- Locked dropdown item logic in Add Question screen

---

## [1.1.0] — 2026-04-02 · feature/free-limits → develop → main

### Added
- **Category management screen** — create custom categories with an emoji
  picker, rename, delete (if no questions attached)
- Default categories (General, Work) are locked and hidden from
  management screen; identified via `is_default` DB column (migration v3)
- **Challenge Mode** — timer ≤ 20s activates streak tracking and bonus
  question slots; dynamic fire emoji display (1 dimmed / 1 / 3 large)
- Timer challenge card on home screen taps through to notification settings,
  auto-scrolling to the timer section
- FAB redesigned as single "+" that opens an add-menu bottom sheet with
  "New Question" and "New Category" options
- Post-settings permission check: spinner + "Checking notification
  permission…" text while verifying on return from Android settings
- `WidgetsBindingObserver` in onboarding notification page so permission
  is re-checked only when the user actually returns to the app (not when
  Settings opens)

### Fixed
- **Critical** — Notifications never delivered: `tz.local` was defaulting
  to UTC because `setLocalLocation()` was never called; added
  `flutter_timezone` package and set correct device timezone on init
- **Critical** — `AndroidScheduleMode.exactAllowWhileIdle` silently failed
  on Android 12+ without the special "Alarms & Reminders" user grant;
  switched to `inexactAllowWhileIdle` (no special permission needed)
- Notification permission "Try again" did nothing: `AppSettings.openAppSettings()`
  resolves its Future immediately when Settings opens, not when user returns;
  fixed with `WidgetsBindingObserver.didChangeAppLifecycleState`
- Onboarding overflow by ~25px on Xiaomi 15: moved animation wrappers
  (FadeTransition/SlideTransition) outside SingleChildScrollView
- Feature chips overflow on welcome page: Row → Wrap
- `use_build_context_synchronously` warning in Add Question after async gap

### Changed
- App package renamed `com.example.random_recall` → `com.inkpebble.randomrecall`
- Challenge threshold: only timers ≤ 20s count for streak/bonus (not 90s)
- DB version bumped to 3; `is_default` column added to categories table
- Category seeding reduced to 2 defaults (General + Work)
- Free plan: 1 custom category creation limit (`freeMaxCustomCategories = 1`)
- `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` removed from AndroidManifest

### Removed
- "+ Category" chip from question list filter row

---

## [1.0.3] — feature/notification-schedule

### Added
- Notification schedule settings screen with time window, frequency slider,
  active days picker with Daily / Weekdays / Weekends presets
- 7-day fresh notification scheduling (one-time slots, no repeating alarms)
- Response timer slider (0–90s in 5s steps) in notification settings
- Streak tracking: 7-day consecutive challenge streak earns +1 question slot
- Streak milestone dialog at 7-day streak
- Test notification button in settings bottom sheet

### Fixed
- Repeat question back-to-back: questions already used in same day or same
  week are deprioritised when picking notification slots

---

## [1.0.2] — feature/analytics

### Added
- Analytics screen with correct/wrong breakdown per category
- Blurred locked section for free users (premium teaser)

---

## [1.0.1] — feature/practice-improvements · feature/question-mgmt

### Added
- Practice Now button on home screen
- Add/Edit question screen
- Question list screen with category filter chips
- Answer flow screen (reveal answer, grade correct/wrong)
- Notification answer screen (shown when user taps a notification)

### Fixed
- App name display corrected

---

## [1.0.0] — Initial release

### Added
- SQLite database with questions and categories models
- Onboarding flow: welcome → first question → notification setup
- Home screen scaffold
- Notification service with basic scheduling
