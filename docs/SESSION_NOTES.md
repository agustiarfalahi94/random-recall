# Session Notes — Random Recall (2026-08-06)

> Everything learned/done in the big release-readiness + bug-fixing session.
> Written so ANY new agent session (Zed, Claude Code, or other) can pick up
> where this one left off. Read this first.

---

## 1. Project at a glance

- **App:** Random Recall — Flutter quiz/notification app (questions + categories + score tracking, challenge mode, streak, subscriptions, ads).
- **Version:** `0.13.18+49` (pubspec.yaml).
- **Stack:** Flutter 3.41.6 / Dart 3.11.4 · Firebase (Auth, Firestore, Storage, Analytics, Crashlytics, Performance, Remote Config, App Check) · RevenueCat (`purchases_flutter`) · AdMob (`google_mobile_ads`) · sqflite local DB · `provider` state mgmt · l10n EN/ID.
- **Android:** package `com.inkpebble.randomrecall`, minSdk 21, R8 enabled, release keystore `android/app/release-keystore.jks` (gitignored), `key.properties` (gitignored).
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

Branches: `develop` & `main` in sync. Working tree should be clean after commits.

## 4. Google Sign-In (v7) — critical knowledge

- `google_sign_in` 7.x uses Android **Credential Manager** and **requires `serverClientId` passed to `GoogleSignIn.initialize()`** — it no longer reads it from google-services.json. Implemented in `AuthService._ensureGoogleInitialized()` (value mirrors oauth_client type 3 in `android/app/google-services.json`).
- **Silent `canceled` after picking an account = SHA-1 fingerprint not registered** in Firebase Console (Project settings → Your apps → Android → Add fingerprint). Registered fingerprints:
  - CI test APKs: `D8:3D:DF:7A:0C:69:B8:AC:46:C6:B2:5B:43:F1:E6:6B:56:BF:5C:91`
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

- **AdMob**: manifest + `lib/core/ads/ad_service.dart` still use Google **test IDs** (`ca-app-pub-3940256099942544...`). Replace with the real app ID + banner/interstitial unit IDs from apps.admob.com before Play Store. (Ads currently: test ads, no revenue.)
- **RevenueCat**: key is a placeholder; init is skipped until `--dart-define=REVENUECAT_API_KEY=...` is provided. Subscriptions not live yet.
- **iOS**: dependency upgrades changed iOS plugin versions — run `flutter build ios --no-codesign` to validate before any iOS release.
- **Play Store**: release signing exists locally; CI release signing + Play upload steps are commented out in the workflow ("FUTURE" section in `CI_CD_SETUP.md`). Data Safety form + privacy policy needed.
- Firestore rules: deployed ✅ (100 KB write cap live).

## 9. Files map (key ones)

- `lib/main.dart` — startup init order (device id → Firebase → AppCheck → crash/perf/remote config → root detection → streak → premium → ads deferred).
- `lib/core/auth/auth_service.dart` — AuthService, AccountExistsException, Google v7 flow.
- `lib/core/notifications/notification_service.dart` — scheduling (named-param API of v22), channel migration, mirror log, badge logic.
- `lib/core/notifications/notification_scheduler.dart` — pure slot computation (heavily unit-tested).
- `lib/core/sync/sync_service.dart` — Firestore backup/restore; device-claim write historically hit permission-denied when rules weren't deployed.
- `lib/core/ads/ad_service.dart` — premium gating, banner/interstitial, daily caps.
- `lib/core/utils/screen_security.dart` + `MainActivity.kt` — FLAG_SECURE channel.
- `lib/core/services/root_detection_service.dart` — jailbreak/root detection (informational).
- `android/build.gradle.kts` — plugin compat shims (namespace + JVM targets).
- `docs/SESSION_NOTES.md` — this file.
