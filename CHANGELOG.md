# Changelog

All notable changes to Random Recall are documented here.
Format: **Added** · **Fixed** · **Changed** · **Removed** · **Improved**

---

## [0.8.18] — 2026-04-20

### Fixed
- **TextEditingController 'used after dispose' crash in feedback dialog** — Deferred controller disposal until after frame completion using `WidgetsBinding.addPostFrameCallback()` to prevent the controller from being accessed during dialog closing animation.

---

## [0.8.17] — 2026-04-20

### Added
- **Configurable category limits** — Free users limited to 1 custom category, premium users to 20. All limits tunable via Firebase Remote Config.
- **Configurable question limits** — Free users limited to 20 questions, premium users to 200 (changed from unlimited). All limits tunable via Firebase Remote Config.
- **Warning thresholds with color coding** — Category limits show amber warning at 18/20 (90%), question limits show amber at 195/200 (97.5%). Count pills transition gray → amber → red as users approach and reach limits.
- **Character limits on question and answer fields** — Questions limited to 200 characters, answers to 500 characters. Flutter renders live character counters below each field.
- **Show/hide password toggles** — Eye icon button on login and signup screens allows users to reveal password before submission.
- **Count pill displays for all users** — Both free and premium users now see question count with appropriate limits and thresholds. Premium users see category count in Manage Categories screen; free users see count showing 1/1 at limit.
- **Remote Config integration** — All limits (free_question_base, premium_question_limit, free_max_custom_categories, premium_max_custom_categories, category_warning_threshold, question_warning_threshold) now live in Firebase Remote Config with sensible defaults, allowing server-side tuning without app updates.

### Changed
- **Premium question limit** — Changed from unlimited (9999) to 200 questions max. This is a breaking change but intentional to prevent abuse and ensure fair limits for all premium users.

---

## [0.8.16] — 2026-04-20

### Added
- **Bahasa Indonesia (i18n)** — Full Indonesian localization across every screen, dialog, notification, and error message. Language can be switched at runtime from Settings.
- **GitHub Actions CI/CD** — Automated pipeline on version tags: `flutter analyze`, `flutter test`, debug APK build, Android App Bundle, and GitHub release creation.
- **Single-device policy note** — Informational text in Settings under Sync explaining that only one device can be active at a time and that signing in elsewhere auto-signs out the current session.

### Fixed
- **Sign-out stuck on current screen** — Restructured `AuthService.signOut()` with a `finally` block so Firebase sign-out and the UI callback always execute, even if the backup or DB clear throws.
- **Data loss on first email login** — `_HomeGate._initFlow()` now queries Firestore directly when local data is absent, so existing cloud data is restored before showing the home screen instead of redirecting to onboarding.
- **HomeTab not refreshing after restore** — Added a `DatabaseHelper.onDatabaseUpdated` listener in `_HomeTabState` so the home screen reflects synced data immediately after `performRestore()`.
- **Device ID not claimed after restore** — `SyncService.performRestore()` now writes `last_active_device_id` to Firestore after a successful restore, preventing the old device from retaining its claim.
- **Email login not initializing session** — `AuthService.signInWithEmail()` now calls `initializeUserSession()` (RevenueCat login + cloud restore) for verified users, matching the behaviour of Google sign-in.
- **Auth race condition on email login** — Force-reloads the Firebase user from the server after sign-in to catch accounts deleted in the console before proceeding.
- **Time picker minutes resetting to :00** — Auto-computed end time now preserves the originally picked minutes instead of always rounding down to the hour.
- **Indonesian timer unit showing "d"** — Replaced placeholder `{seconds}d` / `{threshold}d` with `{seconds} detik` / `{threshold} detik` across all five affected ARB strings.
- **Preset chip overflow for long Indonesian labels** — Wrapped each `_PresetChip` in `Expanded` so "Akhir Pekan" and other long labels scale to fit instead of overflowing.
- **Time picker appearance in Indonesian locale** — Forced English locale inside the `showTimePicker` builder so the AM/PM dial always renders correctly regardless of the app language.
- **Deleted questions reappearing after restore** — Sync restore no longer re-inserts questions that were deleted by the user.
- **Notification badge count stuck** — Badge count now updates correctly after answering a notification question.
- **Google/email sign-in parity** — Both providers now go through the same post-login initialization path.

---

## [0.8.0] — 2026-04-19

### Changed
- **BREAKING:** Replaced multi-device real-time sync with single active device model
  - Only one device per user can be logged in at a time
  - Users on multiple devices will be silently logged out on next app open
  - Cloud Firestore now acts as backup-only, not real-time sync
  - Eliminates data loss bugs from destructive reconciliation
  - Simplified codebase by removing ~150 lines of complex sync logic

### Removed
- `SyncService.startRealtimeSync()` method
- `SyncService._applyRemoteChanges()` method
- Firestore snapshot listeners for real-time category/question/score updates
- Auto-sync debounce timer (replaced with manual backup on logout/update)

### Fixed
- Fixes issue #7: Deleted questions no longer restored on sync
- Fixes issue #8: Data loss when clearing app data and logging in again

---

## [0.7.0] — 2026-04-08

### Added
- **Mandatory Permission Guard** — Enforces notification access at the app root; the app is now locked behind a requirement screen until permission is granted, ensuring core functionality is never skipped.
- **Differentiated Undo** — The Undo feature now behaves differently based on context:
    - **Organic Notifications**: Limited to exactly 1 use per day to preserve the challenge.
    - **Practice & Tests**: Unlimited uses allowed for learning.

### Fixed
- **Xiaomi Notification Reliability** — Implemented a proactive permission request on app startup (`main.dart`) and bumped test notifications to Max priority to bypass MIUI/HyperOS background restrictions.
- **Backup-on-Logout Race Condition** — Hardened the sign-out flow to force a final cloud backup completion before clearing local data.
- **Auth Restoration Logic** — Fixed a bug where `is_premium` status wasn't pulled from Firestore during the initial device login/restore.

### Improved
- **Contextual UI Feedback** — Unified and refined the wording after answering questions:
    - Organic: "Score recorded! Closing in a moment..."
    - Practice: "Next question?" / "Keep practicing!"
    - Test: "Closing in a moment..."
- **Settings UX** — Settings sheet now automatically closes when firing a test notification.
- **Debugger Cleanup** — Removed redundant OS-level alarm lists to focus on application logic mirror logs.

---

## [0.6.0] — 2026-04-08

### Added (Phase 5 — Subscriptions)
- **Subscription Foundation** — Integrated `in_app_purchase` and synced premium status from Firestore.

## [0.5.2] — 2026-04-07

### Added (Phase 4 — Cloud Sync & Multi-Device)
- **Bidirectional Real-time Sync** — Integrated Firestore Snapshots; changes made on one device reflect instantly on others logged into the same account.
- **Streak Synchronization** — Timer challenge streaks and bonus question slots are now backed up and synced across devices.
- **Manual Refresh** — Added a "Sync Data Now" button in settings for on-demand cloud retrieval.
- **Seamless Device Switching** — New installs automatically detect cloud data during login and bypass the onboarding flow.

### Fixed
- **Sync Robustness** — Hardened data models to handle legacy cloud data and prevent "Null" cast errors during restoration.
- **Logout UI Flow** — Fixed a bug where the UI didn't reset to the login screen after signing out.
- **Privacy & Cleanup** — Ensured cloud listeners stop and all local data is purged upon logout to prevent account leakage.

## [0.5.1] — 2026-04-07

### Changed
- **Email Templates** — Customized sender name, from address, and domain for a professional feel.
- **Authentication UX** — Resolved layout overflow in the settings bottom sheet, fixed the forgot password flow, and professionalized system email templates.
- **Email Authentication** — Added dedicated Login and Sign-up screens for email-based accounts.
- **Sync Preparation** — Migrated database to include `updated_at` timestamps for conflict resolution.
- **Auth Refinement** — Focused on Google and Email login; removed Facebook integration.

## [0.5.0] — 2026-04-07

### Added
- **Authentication Foundation** — Integrated Firebase Core and Auth dependencies.

## [0.4.3] — 2026-04-06

### Fixed
- **Analytics Layout** — Anchored the subscription CTA directly below the "By Category" header to prevent layout shifting as categories are added.
- **Toast Logic** — Harmonized feedback messages between notification-tap flow and in-app practice flow.

---
## [0.4.0] — 2026-04-05

### Added
- **Cheat Prevention** — Notification alerts now hide the question text until the 
  app is opened, ensuring the timer challenge cannot be bypassed.
- **Question Repeating** — If the requested daily frequency exceeds the number of 
  available questions, the app will now repeat questions to fulfill the schedule.

### Fixed
- **Sunday Scheduling Bug** — Fixed an issue where Sunday slots were not being 
  registered correctly in some timezones.
- **Notification Persistence** — Removed notification grouping that caused all 
  alerts to disappear when only one was opened.
- **Toast Logic** — Corrected feedback messages for Practice vs. Scored modes.
- **Analytics Layout** — Pinned the subscription lock section directly below the 
  category header to prevent it from shifting with list growth.

---
## [0.3.1] — 2026-04-05

### Added
- **Developer Debug Mode** — Access a hidden notification debugger by tapping the 
  "Notification Schedule" title 7 times.
- Added logic to mirror notification schedules to local storage for inspection.

---

## [0.3.0] — 2026-04-05

### Added
- **Battery optimisation whitelist** (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`) —
  the app now shows a one-time Android system dialog ("Allow app to always run
  in background?") immediately after notification permission is granted during
  onboarding. This ensures notifications are never blocked by Xiaomi's battery saver.
- Existing users (app update) are prompted automatically on next launch via a
  post-frame callback in `main.dart`.
- Battery optimisation fix card in Notification Settings — shown only when the
  whitelist was denied; lets users re-request at any time.

### Fixed
- **Critical** — App showing blank screen on launch: Fixed a deadlock where the 
  app got stuck waiting for the notification system. The app now opens immediately.
- **Critical** — Notifications clumping: Notifications are now spaced out properly 
  throughout the day instead of appearing all at once.
- **Critical** — Duplicate questions: If a question is already waiting in your 
  notification tray, the app will now update the existing card instead of creating a duplicate.
- **Critical** — Background Scheduler: Fixed a "WorkManager" crash that prevented 
  the app from automatically refreshing the next 7 days of notifications.

### Improved
- Added support for Android 13+ "Predictive Back" gestures.
- Optimized scheduling speed to prevent the app from lagging when saving settings.

---

## [0.2.0] — 2026-04-03

### Added
- **WorkManager background rescheduler** — rebuilds the 7-day notification
  window every 6 hours even when the app is not open; survives Doze mode,
  process death, and device reboots (`workmanager` package)
- **MIUI / HyperOS notification guide** — Xiaomi devices show a step-by-step
  tutorial immediately after onboarding and via a persistent card in
  Notification Settings; step 1 button launches Background Start settings
  directly via `android_intent_plus`, step 2 opens app info for Power setting
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

## [0.0.0] — 2026-04-02 · feature/free-limits → develop → main

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

## [0.0.3] — feature/notification-schedule

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

## [0.0.2] — feature/analytics

### Added
- Analytics screen with correct/wrong breakdown per category
- Blurred locked section for free users (premium teaser)

---

## [0.0.1] — feature/practice-improvements · feature/question-mgmt

### Added
- Practice Now button on home screen
- Add/Edit question screen
- Question list screen with category filter chips
- Answer flow screen (reveal answer, grade correct/wrong)
- Notification answer screen (shown when user taps a notification)

### Fixed
- App name display corrected

---

## [0.0.0] — Initial release

### Added
- SQLite database with questions and categories models
- Onboarding flow: welcome → first question → notification setup
- Home screen scaffold
- Notification service with basic scheduling
