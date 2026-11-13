# Session Notes — Random Recall (2026-08-06)

> Everything learned/done in the big release-readiness + bug-fixing session.
> Written so ANY new agent session (Zed, Claude Code, or other) can pick up
> where this one left off. Read this first.

---

## 1. Project at a glance

- **App:** Random Recall — Flutter quiz/notification app (questions + categories + score tracking, challenge mode, streak, ads — single full version, no subscriptions).
- **Version:** `0.14.0+53` (pubspec.yaml).
- **Stack:** Flutter 3.41.6 / Dart 3.11.4 · Firebase (Auth, Firestore, Storage, Analytics, Crashlytics, Performance, Remote Config, App Check) · AdMob (`google_mobile_ads`, **enabled**) · sqflite local DB · `provider` state mgmt · l10n EN/ID.
- **Model:** ONE full version — every feature unlocked for every user, no subscription, no IAP SDK. Ads are the only revenue.
- **Android:** package `com.inkpebble.randomrecall`, minSdk 24, R8 enabled, release keystore `android/app/release-keystore.jks` (gitignored), `key.properties` (gitignored).
- **Test device:** Xiaomi 15 · Android 16 · HyperOS 3.0.302.0 · timezone Asia/Kuala_Lumpur.

## 2. Git workflow (IMPORTANT)

- Remote: `github.com/agustiarfalahi94/random-recall` (private). **Default branch is `develop`** (by design — avoids accidental CI runs).
- Flow: work on `develop` → push → merge into `main` locally → push main → create annotated tag `vX.Y.Z` → push tag → **CI runs** (workflow triggers on `push: tags: [v*]` and PRs to develop/main; NOT on plain pushes).
- CI: `flutter analyze` (strict — infos/warnings fatal), `dart format --set-exit-if-changed lib/`, `flutter test --coverage`, `flutter build apk --debug`, then a GitHub Release with the debug APK.
- CI secrets in use: `GOOGLE_SERVICES_JSON` (base64), `DEBUG_KEYSTORE_BASE64`, and `REVENUECAT_API_KEY` (dart-define, release step only).

## 3. Release history (all 2026-08-06, all CI green)

| Version | What |
|---|---|
| 0.13.14 | Zero analyzer issues (69 fixed), formatting, dead code, streak-test Firebase fakes, RevenueCat key → `--dart-define`, root/jailbreak detection (informational: analytics + one-time warning) |
| 0.13.15 | Security batch: FLAG_SECURE screenshot blocking on quiz screens, anti-enumeration login, `allowBackup=false`, PostHog dead config removed, unused `http` dep removed, Firestore rules 100 KB write cap |
| 0.13.16 | Dependency update pass: Firebase majors (core 4 / auth 6 / firestore 6 / analytics 12 / crashlytics 5 / app_check 0.4 / remote_config 6 / storage 13 / performance 0.11), `flutter_local_notifications` 22, `google_mobile_ads` 9, `purchases_flutter` 10, `workmanager` 0.10, `device_info_plus` 13, `app_settings` 7 (8.x is SPM-only — skipped), `google_sign_in` 7, `timezone` 0.11, `flutter_lints` 6, `desugar_jdk_libs` 2.1.4. Skips: `intl` 0.20.3 (SDK-locked), `app_settings` 8 (SPM) |
| 0.13.17 | Google Sign-In fix (serverClientId + account linking), deferred AdMob init (cold start) |
| 0.13.18 | Black launch screen fix (v31 theme variants), shared CI debug keystore (upgradeable test APKs) |
| 0.14.0 | **Single full version** — subscription tier removed (no paywall, no IAP, no entitlement), ads on for everyone with the UMP consent flow + Settings → Ad privacy, all AdMob IDs in one file, release-logs PII fixed, CI builds the Play AAB |
| 0.13.21 | **Ads switched OFF** (`kAdsEnabled = false`) — fixes typing lag in the question/answer fields caused by the AdMob platform view sitting above every screen |

**Current work (unreleased, on `develop`):** Sync & stability batch — tombstone-based deletes (`sync_deletions` table, schema v5), chunked ≤450-op backup (fixes the Firestore 500-op write cap) with tombstone-first writes + 30-day cloud score prune, paginated tombstone-aware restore (`_fetchAllDocs`, 500-doc pages, drops orphaned scores) + the `dataFound` fix (categories/scores-only users no longer pushed back to onboarding), `AuthService.isVerifiedUser` consolidation, random-OFFSET question query, root detection off the first frame. Tests: **105/105**. Version NOT bumped (still `0.13.18+49`) — changelog entry is under `[Unreleased]`.

Branches: `develop` & `main` in sync. Working tree should be clean after commits.

## 4. Google Sign-In (v7) — critical knowledge

- `google_sign_in` 7.x uses Android **Credential Manager** and **requires `serverClientId` passed to `GoogleSignIn.initialize()`** — it no longer reads it from google-services.json. Implemented in `AuthService._ensureGoogleInitialized()` (value mirrors oauth_client type 3 in `android/app/google-services.json`).
- **Silent `canceled` after picking an account = SHA-1 fingerprint not registered** in Firebase Console (Project settings → Your apps → Android → Add fingerprint). Registered fingerprints:
  - ~~CI test APKs: `D8:3D:DF:7A:0C:69:B8:AC:46:C6:B2:5B:43:F1:E6:6B:56:BF:5C:91`~~ — **obsolete (v0.13.21)**. CI never actually used this key: the `DEBUG_KEYSTORE_BASE64` step silently produced a *different random* fingerprint on every run (verified: v0.13.18 APK = `70:79:F3:E4:…`, 2026-08-13 APK = `08:47:8A:81:…`), so Google Sign-In could never work on a CI debug APK. CI no longer publishes debug APKs at all — build them locally, where the fingerprint below is registered. The `DEBUG_KEYSTORE_BASE64` secret is now unused and can be deleted.
  - Local debug builds: `A6:47:FF:68:C3:3F:36:3D:EC:6A:ED:76:C0:E9:94:89:DE:E0:64:E4`
  - Release keystore: `D3:A4:D2:EE:B9:94:1B:35:05:61:64:9B:ED:90:53:2E:96:8E:A0:BD`
- **`account-exists-with-different-credential`**: Google email already used by an email/password account → `AccountExistsException` → login dialog asks for the password → `linkGoogleToExistingAccount()` links both providers (v0.13.17).
- v7 only exposes `idToken` (no access token) — `GoogleAuthProvider.credential(idToken:)` is sufficient.

## 5. Build/signing gotchas

- **CI APK signature mismatch** ("App not installed" when updating): fixed by the shared debug keystore (`DEBUG_KEYSTORE_BASE64` secret decoded to `~/.android/debug.keystore` in the workflow). All CI APKs are now upgradeable over each other.
- **HyperOS blocks `adb install`** (`INSTALL_FAILED_USER_RESTRICTED`): push the APK to the phone (`adb push app-debug.apk /sdcard/Download/`) and install from the Files app, OR enable Developer options → "USB debugging (Security settings)" (needs Mi account).
- **Old plugins + AGP 8 / Kotlin 2**: `android/build.gradle.kts` has shims — namespace for `flutter_jailbreak_detection` (`appmire.be.flutterjailbreakdetection`) and per-plugin Kotlin `jvmTarget` matching each module's Java level (1.8 vs 17).
- Stale `GeneratedPluginRegistrant.java` in `android/app/src/main/java/io/flutter/plugins/` breaks builds after plugin upgrades → delete it or `flutter clean`.

## 6. Known runtime notes (Xiaomi 15 / Android 16)

- **Exact alarms**: `SCHEDULE_EXACT_ALARM` denied by default on Android 16 → user must grant manually (Settings → Apps → Random Recall → Special access → Alarms & reminders). Notifications still work inexactly.
- Black launch screen fixed (v31 styles now include `@drawable/launch_background`).
- `getActiveNotifications()` can return `[]` on MIUI/HyperOS — handled in `NotificationService` (badge logic relies on the mirror log + always fires the refresh event).
- Cold start 2–3 s in debug builds is normal (JIT + Firebase init); release builds are faster. AdMob init is deferred to the background.

## 7. Testing

- `flutter analyze` → 0 issues. `dart format --set-exit-if-changed lib/ test/` clean. `flutter test` → **77/77**.
- `test/core/streak/streak_service_test.dart` uses fake `FirebasePlatform` / `FirebaseAuthPlatform` (dev deps `firebase_core_platform_interface ^8.1.0`, `firebase_auth_platform_interface ^9.0.6`; classes `InternalUserDetails` not `PigeonUserDetails`).
- Useful: `adb logcat -s flutter -v time` (app logs only), `adb shell dumpsys package com.inkpebble.randomrecall | grep versionName`, `gh run list/watch -R agustiarfalahi94/random-recall`.

## 8. Still open (from the user's side)

- **AdMob — ads are ENABLED** (`kAdsEnabled = true`). Every user sees ads (single full version). Mechanics: UMP consent is gathered before the SDK is initialised (`canRequestAds` gates everything, see §12), banner hidden while the keyboard is up and on `AddEditQuestionScreen` (platform-view typing lag), interstitials after organic answers only (≤5/day, ≥10 min apart), exponential backoff on load failures (1 → 10 min), test-unit IDs in debug / placeholder release IDs until the real ones arrive.
  **Still required before upload:** the three real IDs in `lib/core/ads/ad_config.dart` (`appId`, `bannerAdUnitId`, `interstitialAdUnitId`) — that is the *only* file to edit, the manifest App ID is injected from it by Gradle — and a **message published in AdMob → Privacy & messaging** so the consent form and the Settings → Ad privacy row actually have something to show.
  **Local UMP testing:** debug builds pretend the device is in the EEA, so the consent form and the Settings row appear without a VPN. Override with `--dart-define=UMP_DEBUG_GEOGRAPHY=eea|us|disabled`; the stored consent is only cleared by wiping the app's data, so do that to see the form a second time (the device must be listed in `AdMobConfig.testDeviceIds`).
- **No IAP / no entitlement** — RevenueCat and `purchases_flutter` were removed. Do not add a client-trusted `is_premium` flag back (it used to be restored from the user-writable Firestore doc, i.e. self-grantable).
- **iOS**: dependency upgrades changed iOS plugin versions — run `flutter build ios --no-codesign` to validate before any iOS release. **STATUS: explicitly deferred — iOS is not a near-term target ("maybe next year, maybe never"). Do NOT spend time on iOS validation unless the user says they're targeting iOS.** (Note: `app_settings` 8.x was skipped because it requires Swift Package Manager; revisit that choice only if iOS becomes real.)
- **Play Store**: release signing exists locally; CI release signing + Play upload steps are commented out in the workflow ("FUTURE" section in `CI_CD_SETUP.md`). Data Safety form + privacy policy needed.
- Firestore rules: deployed ✅ (100 KB write cap live).
- **Production-readiness audit (2026-11-13) — code is launch-ready, the release package is not.** Verified good: per-user Firestore rules with default deny, App Check wired (Play Integrity in release), no keystore/`google-services.json`/`key.properties`/`.env` in git, `targetSdk 36` / `minSdk 24` / `versionCode 52`, Crashlytics + Analytics wired, seven maintained docs. Still open: **Play App Signing SHA-1 not registered in Firebase** (Google Sign-In will fail for Play installs — the top blocker), App Check *enforced* per product in the Firebase console, real AdMob IDs + a published consent message, privacy-policy and account-deletion URLs, Data Safety form, store assets, closed testing (12 testers / 14 days). CI now also builds the Play AAB on `v*` tags. PII in release logs and the dead RevenueCat proguard keeps were fixed in the same pass.

## 9. Files map (key ones)

- `lib/main.dart` — startup init order (device id → Firebase → AppCheck → crash/perf/remote config → root detection → streak → premium → ads deferred).
- `lib/core/auth/auth_service.dart` — AuthService, AccountExistsException, Google v7 flow.
- `lib/core/notifications/notification_service.dart` — scheduling (named-param API of v22), channel migration, mirror log, badge logic.
- `lib/core/notifications/notification_scheduler.dart` — pure slot computation (heavily unit-tested).
- `lib/core/database/database_helper.dart` — schema v5 + `sync_deletions` tombstone journal table (categories/questions deleted locally get a journal row; the next backup deletes those cloud docs).
- `lib/core/sync/sync_service.dart` — Firestore backup/restore; chunked ≤450-op tombstone-aware backup (delete-first, 30-day score prune) + paginated tombstone-aware restore via `_fetchAllDocs` (500-doc pages, skips tombstoned docs, drops orphaned score records); device-claim write historically hit permission-denied when rules weren't deployed.
- `lib/core/ads/ad_service.dart` — `kAdsEnabled` kill switch (currently `false`), premium gating, banner/interstitial, daily caps.
- `lib/core/utils/screen_security.dart` + `MainActivity.kt` — FLAG_SECURE channel.
- `lib/core/services/root_detection_service.dart` — jailbreak/root detection (informational).
- `android/build.gradle.kts` — plugin compat shims (namespace + JVM targets).
- `docs/SESSION_NOTES.md` — this file.

---

## 10. PLAY STORE RELEASE RUNBOOK (when the user says "release to Play Store")

This is the checklist for taking the current app state to production. Most items
are prerequisites the USER must do in consoles; the agent's job is to prepare
and verify everything on the code side and walk the user through the console steps.

### A. Agent-side (code/CI — do these when asked to "prepare release")

1. **Run the full validation**: `flutter analyze` (0 issues), `dart format --set-exit-if-changed lib/ test/`, `flutter test` (105/105).
2. **Bump version** in `pubspec.yaml` (e.g. `0.13.19+50`) + add a `CHANGELOG.md` entry for it.
3. **Build the release AAB locally** and verify it compiles + is obfuscated:
   ```bash
   flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info --dart-define=REVENUECAT_API_KEY=<real key>
   ```
   Keep `build/debug-info` for symbolication of Crashlytics stack traces.
4. **Release-signing in CI (optional but recommended)**: add GitHub secrets `KEYSTORE_BASE64` (base64 of `release-keystore.jks`) and `KEYSTORE_PROPERTIES` (contents of `key.properties`); uncomment the "Build App Bundle (release)" + Play upload steps in `.github/workflows/flutter-build.yml` (they're already drafted in the "FUTURE" section).
5. **Verify tag flow**: merge develop → main → tag `vX.Y.Z` → CI runs → GitHub Release created.
6. **Push the AAB** to the user (or let CI upload it to the Play Console internal track).

### B. User-side prerequisites (consoles — the user must do these)

1. **AdMob** (apps.admob.com) — **note: ads are currently switched off via `kAdsEnabled = false`; flip it back to `true` as part of this step**: create account → register app `com.inkpebble.randomrecall` → create **banner** + **interstitial** ad units → give the agent the real IDs to replace in `lib/core/ads/ad_service.dart` and the manifest `APPLICATION_ID` meta-data (currently Google test IDs → real ads need real IDs; also add the user's device as a test device in `RequestConfiguration.testDeviceIds` while developing).
2. **No IAP setup needed** — the subscription tier was removed; ads are the only revenue stream. (RevenueCat is no longer a dependency, and the old `REVENUECAT_API_KEY` secret can be deleted.)
3. **Firebase console**: verify App Check **enforcement is ON** for Firestore (release uses Play Integrity — already coded); the release SHA-1 fingerprint `D3:A4:D2:EE:B9:94:1B:35:05:61:64:9B:ED:90:53:2E:96:8E:A0:BD` must be registered (for Google Sign-In on the release app).
4. **Play Console** (play.google.com/console): create app → **Data Safety form** (collects: email/phone for auth, analytics, ads; no financial data unless subscriptions live) → **Privacy policy URL** (host anywhere) → store listing (icon 512×512, feature graphic, screenshots, short/full description EN + ID) → content rating questionnaire → set pricing (free; IAP available).
5. **App signing in Play Console**: Play App Signing will be used — upload the AAB; Play generates/reuses the upload key. The app's signing key stays `release-keystore.jks` for the first upload; after that Play manages updates.
6. **Testing**: upload the AAB to the **Internal testing** track first → install via the opt-in link on the test device → run the priority scenarios from `QA_TEST_SCENARIOS.md` → then Closed → then Production (phased rollout 10-25-50-100%).

### C. Post-launch checks (agent + user)

1. Confirm **Crashlytics + Analytics** events arrive (launch the release build and check Firebase console live view).
2. Verify **Play Integrity App Check** passes (Firebase App Check console shows Play Integrity tokens).
3. Test **Google Sign-In on the release build** (fingerprint D3:A4… registered — Step B3).
4. Keep `CHANGELOG.md`, `CI_CD_SETUP.md`, and this file in sync for every subsequent release.
5. Monitor subscription/entitlement events in RevenueCat after any purchase flow is enabled.

---

## 11. CURRENT WORK — resume point (2026-08-07)

> If you are a fresh agent session, this is where work stands. Read this before anything else.

**Interactive spotlight tutorial — REDESIGNED, ENABLED, on-device-tested.**

- Design spec: `docs/superpowers/specs/2026-08-06-interactive-tutorial-design.md`
- Implementation plan: `docs/superpowers/plans/2026-08-06-interactive-tutorial.md`
- **How it works now (stable):** real target widgets are wrapped in `Showcase(key: ..., child: ...)` via `TourTarget` (`lib/widgets/tour/tour_overlay.dart`); `TourOverlay` hosts the controller + step logic around the HomeScreen Scaffold; `TourService.enabled = true`. Every step locks the screen (`disableBarrierInteraction: true` everywhere — the default barrier tap calls `next()` and used to advance the tour without doing the step's real action). Steps 1–8: practice → Questions tab → + FAB (tap-to-advance — fires no real action) → Analytics tab → Home tab → settings gear (sheet opens via `onOpenSettings` callback, only advances when it actually opened) → text overlay over the sheet → done overlay (button says **Finish**; step 7 keeps Skip). Placeholder showcases for steps 7/8 are `Showcase.withWidget(container: SizedBox.shrink())` + the global Skip action is hidden for them, so no stray white tooltip bubble can render.
- **CRITICAL Dart 3.11 gotcha (root of several "tour does nothing/double-advance" bugs): switch statement cases FALL THROUGH without `break`.** Every switch with non-empty cases must end each case with `break`/`return`. Verified empirically with a standalone snippet. All tour switches now have explicit breaks.
- **Do NOT reuse a target's GlobalKey on a showcase** — showcaseview attaches its key to an internal child; shared keys corrupt the element tree ("RenderBox was not laid out"). One key per showcase, created once in `TourService` (never `GlobalKey()` inline in a getter).
- Debug aids: `TourOverlay` logs every transition (`Target tapped —`, `tabSwitch … → index`, `runAction … fired=`, `onOpenSettings threw`). `TourService.resetCompleted()` re-enables auto-start.
- **Notifications exact-alarm fix (v0.13.20)** — `canScheduleExactNotifications()` check with `inexactAllowWhileIdle` fallback + per-alarm retry. **User still needs to confirm an organic (scheduled) notification actually fires** — pending on-device verification.

**Auth/session fixes (v0.13.20, all on local `develop`, NOT pushed):**
- `main.dart` no longer signs out on transient `currentUser.reload()` failures — only definitive account errors (`user-not-found`, `user-disabled`, `invalid-user-token`, `user-token-expired`).
- `_HomeGate._checkActiveDevice` no longer silently signs out on a cloud/local device-ID mismatch (fresh installs + failed claim writes caused a logout loop) — it re-claims the current device instead.
- `SyncService`: full score history is backed up (30-day window + cloud prune REMOVED — analytics data must survive logout/login); `performBackup` returns success/failure; sign-out backup budget is 20 s and local data is kept when it fails; initial-login restore uploads local data BEFORE the wipe (pre-wipe backup, gated by `SyncService.localDataOwnerKey` marker so accounts never mix).

**GitHub distribution (v0.13.20):** the workflow now builds a **release APK** signed with the release keystore and attaches `RandomRecall-vX.Y.Z.apk` to GitHub Releases (debug APK kept alongside for internal testing). This is what makes Google Sign-In work for downloaders (Credential Manager validates the signing-cert SHA-1; release fingerprint `D3:A4:…` is registered). **USER TODO (one-time):** add secrets — `base64 -i android/app/release-keystore.jks | gh secret set KEYSTORE_BASE64` and `gh secret set KEYSTORE_PROPERTIES < android/key.properties`. The build job fails loudly if they're missing. Release APK verified locally (R8 + signing) on 2026-08-07.

**NOT RELEASED YET:** everything above is on local `develop` only (CI outage from 2026-08-06 is over — the earlier `v0.13.19` tag was deleted; `v0.13.20` tag was pushed but its CI never ran). Next: user confirms the organic notification fires → push develop → merge to main → tag `v0.13.20` → CI runs (now also producing the distribution APK).

---

## 12. Full-version pivot (2026-11-13) — premium removed, ads switched on

> Read this before touching monetization, feature gating, or `ad_service.dart`.

**Decision.** Random Recall ships as **one full version**: every feature is
unlocked for every user, there is no subscription and no IAP. Ads are the only
revenue stream. This removed the need for a paid-product setup in the Play
Console (which matters because the app is published through a friend's Play
developer account while the AdMob account and its payouts stay with the owner).

**What was deleted**
- `lib/core/plan/plan_service.dart`, `lib/core/plan/subscription_service.dart`
  (the whole `lib/core/plan/` directory), `lib/screens/settings/subscription_screen.dart`,
  `lib/widgets/upgrade_bottom_sheet.dart`.
- Dependency `purchases_flutter` (RevenueCat), the `REVENUECAT_API_KEY`
  `--dart-define`, the CI secret reference, and the `.env.example` entry.
- 50 orphaned ARB strings per language (paywall, premium perks, plan-limit
  pills, subscription chip, analytics upsell) — including `premiumPerkUndo`,
  which claimed a "rewarded" undo that never existed.
- The unused plan-limit getters in `remote_config_service.dart`
  (`notifFrequencyFree` stays: `notification_service.dart` uses it).

**Behaviour changes**
- No question/category caps; the count pills show a plain count
  (`questionCountTotal` / `categoryCountTotal`, EN + ID).
- Undo is always available after a wrong answer — no premium gate, no
  once-per-day limit (`undoOncePerDay` string deleted, `undoButton` used).
- The notification question screen no longer auto-closes after a **wrong**
  answer (it stays open so Undo is reachable); it still auto-closes after a
  correct one.
- Challenge completion always awards badge + title. The bonus question/category
  bookkeeping inside `StreakService` was kept at first (the tests asserted it)
  but was removed in the simplification pass below — it gated nothing once the
  caps were gone.
- `is_premium` is no longer read, written, or restored. **It used to be
  restored from the user's own Firestore document, which the client can write**
  — i.e. a free-premium exploit. Do not reintroduce any entitlement that the
  client itself can set.

**Ads (`lib/core/ads/ad_service.dart`)**
- `kAdsEnabled = true`; the banner is shown to everyone, `AdService.initialize()`
  takes no arguments.
- Banner is unmounted while the keyboard is up, and `AddEditQuestionScreen`
  calls `enterExcludedScreen()` — this is what prevents the v0.13.20 typing lag
  from returning now that ads are always on.
- Banner reload failures back off 1 → 10 min (exponential) instead of a fixed
  60 s retry.
- Test-device IDs are `kDebugMode`-only.

**Simplification pass (paywall leftovers)**
- `StreakService.completeChallengeMode(int duration)` and
  `recordChallengeAnswer({required bool isCorrect})` no longer take
  `isPremiumUser`. Every completer gets the badge and a title; those are the
  only rewards left.
- Deleted the bonus-slot machinery: `questionsMax`, `categoriesMax`,
  `questionBase`, `categoryBase`, `_keyBonusQuestions`, `_keyBonusCategories`,
  the `bonusQuestions`/`bonusCategories` getters, the `dart:math` `min()`
  clamping, and the `rewards.bonus_questions` / `rewards.bonus_categories`
  Firestore keys (write **and** read). Old values in existing user docs are
  simply ignored.
- `ChallengeCompletion` lost `questionsEarned`/`categoriesEarned`, so
  `ChallengeCompleteScreen` shows badge + title only; the four reward-slot ARB
  strings per language went with them.
- Legacy preference keys (`timer_streak_bonus_questions`, `bonus_categories`,
  `is_premium`) are still purged in `auth_service`/`profile_service` on sign-out
  and account deletion — that cleanup is intentional and stays.

**UMP / GDPR consent (`AdService`)**
- `initialize()` now gathers consent **before** touching the Mobile Ads SDK:
  `requestConsentInfoUpdate` → `loadAndShowConsentFormIfRequired` →
  `canRequestAds()`. If consent is absent the SDK is never initialised and no
  ad is requested; the rest of the app works normally.
- The consent fetch is wrapped in a `Completer` with a 20 s timeout so a slow
  network can never block startup.
- Settings → **Ad privacy settings** calls `ConsentForm.showPrivacyOptionsForm()`.
  The row is rendered by a `FutureBuilder` on
  `getPrivacyOptionsRequirementStatus()` and only appears when the SDK reports
  `required` (Google's rule: the entry point must exist wherever the form is
  required, and need not appear elsewhere).
- If the user withdraws consent from that form, `_applyConsentChange()` disposes
  the banner/interstitial immediately and hides the banner via
  `bannerVisible`; if they grant it after startup, ads start loading.
- Ads that were already loaded keep the consent signal the SDK stored, so
  non-personalized selections are honoured without extra plumbing.
- Testing note: the form only appears after a message is published in the AdMob
  console (Privacy & messaging). With no message configured the flow completes
  silently and `canRequestAds` stays `true` outside consent-required regions.
- **Still required before upload:** the three real IDs in `ad_config.dart`
  (see below); plus a consent message published in the AdMob console
  (Privacy & messaging) — the code path exists, but until a message is
  published the form simply does not appear.

**AdMob IDs: one file (`lib/core/ads/ad_config.dart`)**
- `AdMobConfig` holds all three values — `appId`, `bannerAdUnitId`,
  `interstitialAdUnitId` — plus Google's sample IDs, the test-device list and
  the debug consent geography. Launch = edit those three lines.
- `android/app/build.gradle.kts` parses `appId` out of that file with
  `static const String appId = '([^']+)'` and injects it as the
  `${admobAppId}` manifest placeholder (`defaultConfig` = release value,
  `buildTypes.debug` = Google's sample App ID). The manifest no longer
  hard-codes an App ID, so the App ID and the ad units cannot drift apart —
  keep that Dart line on one line, in single quotes, or Gradle stops with a
  clear error.
- `AdMobConfig.resolvedBannerAdUnitId` / `resolvedInterstitialAdUnitId` return
  the sample units in debug and the real ones in release; `AdService` has no ID
  literals left. The App ID deliberately has no Dart getter — Gradle injects it
  into the manifest, so nothing reads it at runtime.
- **Debug UMP geography**: `AdMobConfig.debugConsentGeography` (defaults to
  `eea` in debug, `disabled` in release) is turned into a
  `ConsentDebugSettings(debugGeography:, testIdentifiers:)` by
  `AdService._consentDebugSettings()`. Release builds always pass `null`, so a
  `--dart-define` cannot leak into production. Override per run:
  `flutter run --dart-define=UMP_DEBUG_GEOGRAPHY=eea|us|disabled`.
- The override only applies on devices listed in `AdMobConfig.testDeviceIds`;
  add the hash the SDK prints to the console when using a new phone.

**Ad-blocker circumvention (deliberately not implemented).** The app does not
try to defeat DNS-level filtering (e.g. `dns.adguard.com`). It would require a
VpnService or a proxy to redirect the SDK's endpoints, which is an unauthorised
modification of ad delivery under AdMob/AdSense program policies and risks the
AdMob account (the only income). Instead the app degrades cleanly: no ads load,
nothing crashes, every feature keeps working, and requests back off.

**Environment note.** `flutter build apk` failed on this machine because
`flutter config --jdk-dir` pointed at a Homebrew JDK that had been replaced
(`openjdk@17/17.0.20` → `17.0.20.1`). Fixed with
`flutter config --jdk-dir=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`.
If the build dies with `JAVA_HOME is set to an invalid directory`, check
`flutter config --list` first.

**Validation after the pivot:** `flutter analyze` 0 issues ·
`dart format --set-exit-if-changed lib/ test/` clean · `flutter test` 105/105 ·
`flutter build apk --debug` OK.

