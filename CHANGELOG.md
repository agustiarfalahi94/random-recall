# Changelog

All notable changes to Random Recall are documented here.
Format: **Added** · **Fixed** · **Changed** · **Removed** · **Improved**

---

## [0.13.0] — 2026-04-28

### Added
- **Feedback now submitted to Firestore** — Feedback dialog previously showed "Feedback sent!" but made no network call (remnant of removed Sentry integration). Now writes to a `feedback` Firestore collection with UID and timestamp.

### Fixed
- **`ChallengeCompleteScreen` entirely hardcoded English** — All strings ("Challenge Complete!", "You completed the X-day challenge!", "Rewards Earned:", reward labels and descriptions) now go through l10n keys in both `app_en.arb` and `app_id.arb`.
- **Challenge titles stored as English strings displayed untranslated** — "Challenger", "Champion", "Legend" were stored as raw English in prefs/Firestore and passed directly to the UI. Now localised at display time via a key lookup in `ChallengeCompleteScreen`.

### Improved
- **`AppProvider` notification strings** — Replaced `if/else` locale check with a language-code lookup map. Adding a new locale now requires one entry here instead of hunting through the provider logic.
- **Stream controller `dispose()` methods** — Added `dispose()` to `DatabaseHelper` and `NotificationService` singletons so stream controllers are cleanly closeable in tests.
- **Extracted shared question widgets** — `_TimerBadge`, `_GradeButton`, `QuestionCard`, and `AnswerCard` were duplicated identically across `question_screen.dart` and `notification_question_screen.dart`. Extracted to `question_widgets.dart`; both screens now import from a single source.

---

## [0.12.9] — 2026-04-28

### Fixed
- **Unsafe CSV parsing crashes notification scheduler** — `int.parse` on persisted active-days CSV would throw `FormatException` on any corrupted or empty value, killing the notification scheduler. Replaced with `int.tryParse` + fallback to all-days in `notification_service.dart` and `notification_schedule_screen.dart`.
- **Phone users excluded from startup restore** — `main.dart` startup flow checked `user.emailVerified` before calling `performRestore`, excluding phone-authenticated users. Now uses `emailVerified || phoneNumber != null`.
- **Device ID check could use stale Firestore cache** — `_checkActiveDevice` read the device ID from Firestore's local cache, which could sign out users on fresh install with a stale hit. Now forces a server read with `GetOptions(source: Source.server)`.
- **Challenge daily check used 24h period instead of calendar-day boundary** — `now.difference(lastAnswerDate).inDays` counts 24-hour periods, not calendar-day crossings. A user answering at 11:59 PM and missing the next calendar day would not fail. Fixed by comparing ISO date strings (`yyyy-MM-dd`).
- **`TextEditingController` leaks in dialogs** — Password change, email re-auth, and phone re-auth dialogs created controllers but never disposed them. Now awaits the dialog and disposes immediately after close.
- **Email field leaked a new `TextEditingController` on every build** — `ProfileScreen` created a controller inline in `build()` with no reference. Moved to a state field initialised in `initState` and disposed in `dispose`.
- **Display name prompt shown on every `initState`** — Dialog could appear multiple times per session on tab re-parenting or app resume. Added `_displayNamePromptShown` session guard.
- **`checkChallengeDailyRequirement` errors silently swallowed** — `.ignore()` hid Firestore write failures that could desync challenge state. Replaced with `.catchError` debug logging.
- **Test ad unit IDs could ship to production** — Ad IDs were always the Google test IDs with no release-mode guard. Added `kReleaseMode` switch; release builds use placeholder real IDs (to be replaced before AdMob account is ready).
- **Dead code removed** — `StreakService.recordActivity` static method and its `StreakResult` class had no callers. Removed entirely.
- **Duplicate `_initCompleter` null check** — Second dead guard in `NotificationService.init()` removed.
- **`MediaQuery.of(context)` called 3× in one build** — Extracted to local `mq` variable in `_AdBannerWrapper.build`.
- **`.ignore()` on fire-and-forget restore** — Made explicit with `.ignore()` to suppress linter warning.

---

## [0.12.8] — 2026-04-28

### Fixed
- **Phone users excluded from cloud sync** — `performBackup` and `performRestore` guarded with `emailVerified` only, permanently blocking phone-authenticated users from cloud backup and restore (data loss). Now accepts phone auth users via `user.phoneNumber != null` check.
- **Account deletion orphaned all Firestore subcollections** — Deleting an account only removed the root `/users/{uid}` document; `questions`, `categories`, `score_records`, and `private` subcollections were left behind (GDPR violation). `_deleteUserData` now batch-deletes all subcollection documents before removing the root doc.
- **Silent data loss on score save failure** — `_grade()` in `NotificationQuestionScreen` swallowed all exceptions with `catch (_) {}`, meaning a failed DB write showed a success state to the user with no error reported to Crashlytics. Now reports to Crashlytics and shows a snackbar.
- **`StreakService._prefs` accessed before `initialize()` in background isolate** — WorkManager's `callbackDispatcher` called `NotificationService.scheduleNotifications()` which reads `StreakService.isChallengeActive` before `StreakService.initialize()` was called, causing a `LateInitializationError` crash in the background. Now initialises `StreakService` first.

---

## [0.12.7] — 2026-04-27

### Fixed
- **Remaining hardcoded English strings** — Password field hints ("Current Password", "New Password", "Confirm Password") in the change-password dialog, the questions list FAB tooltip ("Add"), and the challenge start error snackbar were all hardcoded English. Now wired through ARB keys in both `app_en.arb` and `app_id.arb`.

---

## [0.12.6] — 2026-04-27

### Fixed
- **Challenge Mode card entirely in English** — All strings in the home screen Challenge Mode card were hardcoded English (`"Challenge Mode"`, `"Day X / Y"`, `"7-Day"`, `"14-Day"`, `"Stop Challenge"`, stop dialog title/body/action, active/inactive descriptions). Replaced with proper l10n keys in both `app_en.arb` and `app_id.arb`.
- **Other hardcoded English strings** — Fixed remaining hardcoded strings across screens: `"Back to Home"` in `challenge_complete_screen.dart`, `"Next →"` in `first_question_page.dart`, and `"Update Profile"`, `"Confirm Password"`, `"Enter your password"`, `"Change"`, `"Delete"`, password-mismatch snackbar, and display name validation snackbars in `profile_screen.dart`.

---

## [0.12.5] — 2026-04-27

### Fixed
- **Challenge setup timer not clamped to valid range** — When opening the challenge setup screen (`isStartingChallenge: true`), the timer was initialised from the saved preference (e.g. 15 s), which is outside the 5–10 s challenge range. The slider showed an invalid value. The timer is now clamped to 5–10 s on load when starting a challenge; values below 5 s snap up to 5 s, values above 10 s snap down to 10 s.

---

## [0.12.4] — 2026-04-27

### Removed
- **Sentry** — removed `sentry_flutter` dependency and all Sentry integrations (DSN, navigator observer, user-feedback capture, error forwarding). Crash reporting is handled exclusively by Firebase Crashlytics.
- **PostHog** — removed `posthog_flutter` dependency and all event-tracking calls. `AnalyticsService` event methods are retained as no-ops so call sites are unaffected; only Crashlytics user identity is still set on login/logout.

### Fixed
- **AppBar title overflow in question screen** — When a challenge is active, the action row (day badge + timer badge + skip button) leaves very little space for the title. The category name text now truncates with an ellipsis instead of overflowing 64 px off-screen.

---

## [0.12.2] — 2026-04-26

### Fixed
- **Challenge locked settings incorrectly removed** — v0.12.1 mistakenly stripped all challenge mechanics from the notification settings screen (locked timer, frequency, active days). This is now restored: challenge setup still requires a 5 or 10 s timer, and frequency/active days/anytime mode are locked for the full challenge period.
- **Challenge not fully restored after reinstall** — On a fresh install or clear-data, re-login would restore the challenge active/day/duration from Firestore but would not re-apply the locked notification settings to SharedPreferences, so no notifications would fire. Fixed: `locked_timer_seconds` is now persisted to Firestore; `_loadFromFirestore()` writes all locked settings back to SharedPreferences; and `initializeUserSession()` reschedules notifications immediately after cloud restore when a challenge is active.

### Changed
- **Challenge entry point moved to home screen** — The old implicit trigger (setting timer ≤ 10 s in notification settings auto-activated challenge mode) is removed. Challenge is now started exclusively via the "7-Day" / "14-Day" buttons on the home screen Challenge Mode card, which opens the notification settings screen in challenge-setup mode (`isStartingChallenge: true`).
- **Home screen: Challenge Mode card** — Replaces the old Timer Challenge card. Shows "7-Day" and "14-Day" start buttons when no challenge is running. Shows day-progress bar and "Stop Challenge" button when one is active.
- **Timer setting decoupled from challenge trigger** — The notification timer (0–90 s) is now a pure UX preference outside of challenge mode. It does not activate or gate any challenge behaviour. During an active challenge the timer remains locked to the chosen 5 or 10 s value.

---

## [0.12.1] — 2026-04-26

### Added
- **Explicit Challenge Mode entry point** — Home screen now has a dedicated Challenge Mode card with "7-Day" and "14-Day" start buttons. Users opt in deliberately rather than triggering challenge mode implicitly by setting the timer to ≤ 10 s.
  - Active challenge shows a day-progress bar (e.g. Day 3 / 7) and a "Stop Challenge" confirmation button.
  - Start flow reads the current notification frequency from prefs and shows the existing rules/rewards dialog before committing.

### Fixed
- **Ad banner disappeared after second notification question** — `AdService.enterExcludedScreen()` and `exitExcludedScreen()` are called from `initState`/`dispose`, which run during Flutter's build/unmount phases. Synchronously updating the `ValueNotifier` triggered "setState called during build" exceptions, leaving the banner stuck in the hidden state after returning from a question screen. Fixed by deferring the notifier update with `Future.microtask`.
- **Ads not loading on Xiaomi 12T (free user)** — Both test devices (Xiaomi 15 and Xiaomi 12T) are now registered via `MobileAds.instance.updateRequestConfiguration(RequestConfiguration(testDeviceIds: [...]))` so the SDK serves test ads instead of silently failing with error code 0.
- **Premium user received "+1 question slot" on challenge completion** — `_isPremium` in `QuestionScreen` and `NotificationQuestionScreen` defaults to `false` and is loaded asynchronously. If the user graded before `_loadInitialSettings()` resolved, `recordChallengeAnswer(isPremiumUser: false)` ran with the wrong value. Fixed by calling `PlanService.isPremium()` fresh at the start of the grading block.

### Changed
- **Challenge Mode decoupled from timer setting** — The notification timer (0-90 s) is now a pure UX preference. It no longer triggers or gates challenge mode. Notification settings (timer, frequency, active days) are no longer locked while a challenge is active.
- **Challenge Mode header removed from Notification Settings** — The "Challenge Mode" gradient hero section and fire-emoji display are removed from the notification schedule screen. The screen now shows only notification scheduling controls.
- **Timer-streak removed** — `StreakService.recordActivity()` is no longer called from question screens. The old 7-day timer-streak card on the home screen (which accumulated a streak based on answering with a ≤ 10 s timer) is replaced by the explicit Challenge Mode card. Bonus questions are now earned exclusively through challenge completion.
- **ChallengeWarningDialog** — "Timer locked to 5–10 s only" and "Notification frequency locked" rules removed from the warning dialog, as neither constraint applies to the new flow.

---

## [0.12.0] — 2026-04-26

### Added
- **Persistent Ad Banner** — A Google Mobile Ads banner (AdSize.banner, 50dp) is now shown at the bottom of every screen for free-tier users.
  - Sits above the system gesture zone / navigation bar using `MediaQuery.viewPadding.bottom`, so it never conflicts with gesture navigation or 3-button nav (same behaviour as Baby Tracker by NIGHP SOFTWARE).
  - Stays behind the keyboard — the keyboard overlays the banner rather than pushing it up.
  - Hidden on question-answering screens (`QuestionScreen`, `NotificationQuestionScreen`) via `AdService.enterExcludedScreen()` / `exitExcludedScreen()`.
  - Hidden permanently for premium users (set at app init; never shown again during the session).
  - Implemented at `MaterialApp.builder` level so it persists across all pushed routes without any per-screen setup.
  - Retry on failed load (1-minute backoff).
- **Interstitial Ad After Organic Answer** — A full-screen interstitial is shown after the user answers an organic question.
  - Organic sources: notification-triggered questions (`NotificationQuestionScreen`) and home screen badge questions (`QuestionScreen` with `isPractice: false`).
  - NOT shown for: practice mode, test notifications.
  - Shown for all organic questions including Challenge Mode (pass and fail alike).
  - Frequency cap: max **5 interstitials per day**, minimum **10-minute gap** between any two — enforced in `AdService` and persisted across cold starts.
  - Next ad is preloaded immediately after the current one is dismissed.
  - Failures are handled silently — no user-visible error.
- **AdService** (`lib/core/ads/ad_service.dart`) — Singleton managing all ad lifecycle, frequency cap, and premium gating.
- **AdBannerWidget** (`lib/widgets/ad_banner_widget.dart`) — Thin wrapper around `AdWidget`.
- **google_mobile_ads `^5.1.0`** added to `pubspec.yaml`.
- **AndroidManifest**: Google Mobile Ads App ID added (currently test ID — replace with real ID when Google Dev Account is ready).

### Notes
- All ad unit IDs are currently **Google test IDs** that display test ads without requiring a real account. Replace with production IDs in `AdService` when your Google Dev Account and AdMob app are set up.
- Ad display is silently suppressed for users with DNS-level ad blocking (AdGuard, NextDNS, etc.) — no error state is shown.

---

## [0.11.3] — 2026-04-26

### Fixed
- **App Check provider mismatch** — Release builds now use `AndroidProvider.playIntegrity` (production attestation) instead of the debug provider. Debug builds continue to use `AndroidProvider.debug`.
- **App Check debug token timing** — Token is now seeded via `App.attachBaseContext()` (a custom `Application` subclass), which runs before Firebase's `ContentProvider` auto-initializes. Previous approach via `MainActivity.onCreate()` ran too late and was ignored.
- **Kotlin build error** — Replaced `BuildConfig.DEBUG` (which required an explicit import) with `ApplicationInfo.FLAG_DEBUGGABLE`, which resolves without any import.

### Changed
- **Android manifest** — Removed ineffective `meta-data` App Check token entry; seeding is now handled natively in `App.kt`.

---

## [0.11.2] — 2026-04-26

### Fixed
- **Streak milestone reward given to premium users** — `StreakService.recordActivity()` now accepts `isPremiumUser`; the +1 question slot is only granted to free-tier users at every 7-day milestone. The milestone dialog is also suppressed for premium users.
- **App Check debug token** — Initial fix to seed the registered debug token (`F8555F6B-CCF7-450D-9302-3E135386637F`) into Firebase App Check's native SharedPreferences before Firebase initializes. (Superseded by v0.11.3 which corrects the timing.)

---

## [0.11.1] — 2026-04-25

### Added
- **Phone Number Authentication** — Full SMS-based authentication flow alongside existing Google and email sign-in.
  - `AuthService`: `verifyPhoneNumber`, `signInWithPhone`, `linkPhoneNumber`, `changePhoneNumber`
  - `PhoneAuthScreen` with three modes: sign-in, link to existing account, change number
  - `OptionalEmailPromptScreen` — prompts phone-only users to add a recovery email address
  - Auth gate updated to allow phone-verified users through
  - Login screen: "Continue with Phone Number" button
  - Profile screen: auth-driven phone field (shows verified number, link button, or change button)
  - Delete account: re-authenticates phone users via fresh OTP before deletion
  - `ProfileService.deleteAccountPhoneAuth()` for phone-based account deletion
  - Full localization for all phone auth strings in English + Bahasa Indonesia
- **Notification schedule: exact alarm permission warning** — `exact_alarms_not_permitted` `PlatformException` is now caught and shown as a user-friendly snackbar instead of crashing.
- **Notification schedule: change detection** — Save button is visually greyed out and shows "No settings were changed" when tapped with no changes; snapshots settings on load for comparison.

### Fixed
- **Phone auth input** — Phone number field now accepts digits only, enforces max 13 digits, and requires at least 9 digits before enabling Send OTP.

### Removed
- **Auto-show existing streak dialog on home screen** — Was shown every app open which felt intrusive. Dialog is still accessible contextually when starting a new challenge via `ChallengeWarningDialog`.

---

## [0.11.0] — 2026-04-23

### Fixed
- **Challenge Mode eligibility** — Timers above 10s (15–20s, etc.) no longer count as Challenge Mode.
- **Challenge start Save Schedule black screen** — Removed unsafe double-pop navigation; saving returns safely.

### Changed
- **New Challenge Mode schedule locks** — Starting a new challenge now locks:
  - Active days (locked during the challenge)
  - “Send at any time” choice (locked for the whole challenge; start/end time is only editable when it’s OFF)
- **Challenge gameplay wiring** — Challenge Mode now visibly affects the question experience:
  - Shows “Challenge Day X/Y”
  - Wrong answer triggers challenge failure handling
  - Completion triggers the challenge completion flow and rewards

### Improved
- **Challenge notifications** — Scheduled notifications show a clearer Challenge Mode accent while a challenge is active.

---

## [0.10.0] — 2026-04-21

### Added
- **Display Name Personalization** — New dialog prompts users to set their display name on app launch (new users) or first app open (existing users without name).
  - Real-time character validation (letters, numbers, spaces, hyphens, underscores only; max 50 chars)
  - Google Safe Browsing API integration for profanity detection (stub, ready for full implementation)
  - Firebase Auth displayName sync + Firestore backup for multi-device consistency
  - Non-dismissible dialog for new users ensures all users have a display name
  - Welcome message on home screen displays personalized greeting: "Welcome, [Name]"
  - Full localization: English + Bahasa Indonesia

- **Challenge Mode** — High-difficulty 7-day or 14-day streaks with strict rules and cosmetic rewards.
  - **Rules:** Must answer ALL questions correctly (no mistakes), timer locked to 5-10 seconds, notification frequency locked, consecutive day completion required
  - **Free-tier Rewards:** +1 question slot per 7-day completion, +1 question + 1 category slot per 14-day completion (repeatable, max 200 questions / 20 categories)
  - **Premium Rewards:** 🏆 Unlock badge (shows completion count), 👑 Progressive titles (Challenger → Champion → Legend), 🔥 Special gold-bordered notification during challenge
  - **User Flow:** Frequency selection dialog (1-50 questions/day) → Warning dialog with all rules → Challenge begins with locked settings
  - **Failure Handling:** Wrong answer = instant exit + streak reset + all locks removed. Missed day (>1 day gap) auto-detected and fails challenge.
  - **Existing Streak Dialog:** Users with active streaks choose to keep old rules or start fresh challenge
  - Full Firestore persistence and multi-device sync
  - Full localization: English + Bahasa Indonesia

- **Increased Daily Notification Limit** — Expanded from 10 to 50 questions per day for more granular notification scheduling.
  - Slider range: 1-50 questions/day (previously 1-10)
  - Safety verified: 50 notifications in 60 minutes = 1.2 minute spacing (exceeds 1-minute minimum)
  - Locked during challenge mode (frequency set at challenge start)

---

## [0.9.0] — 2026-04-20

### Added
- **Profile Page** — New 4th tab in bottom navigation bar with essential account management features.
  - View email address (read-only, sourced from login provider)
  - Subscription status display (Free/Premium badge with color coding)
  - Change password button (email users only, hidden for Google sign-in users)
  - Delete account button with two-step re-authentication flow (supports both email and Google authentication methods)
- **Welcome message on home screen** — Personalized greeting using user's display name from Firebase Auth (e.g., "Welcome to Agustiar").

### Changed
- **Simplified profile page** — Removed editable name/phone fields (not used in the app) to reduce unnecessary complexity and Firestore writes.
- **Removed profile picture feature** — Profile picture upload removed to avoid Firebase Storage paid tier requirement. Email and subscription features still available.

### Fixed
- **Change Password dialog layout overflow** — Wrapped dialog content in `ConstrainedBox` + `SingleChildScrollView` to prevent confirm password field from becoming hidden when keyboard appears on Xiaomi devices.
- **Profanity check not working** — Implemented actual profanity detection with 20+ English and Indonesian words (including "fuck", "kontol", "memek", etc.). Previously was a stub that always returned false.
- **Display name mismatch between home screen and profile** — Now syncs Firebase Auth `displayName` when profile is updated in Firestore, ensuring both data sources stay in sync.
- **Home screen not updating after profile name change** — Added `FirebaseAuth.currentUser.reload()` call after profile update to refresh local auth state, ensuring home screen displays the latest name on navigation back.

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
