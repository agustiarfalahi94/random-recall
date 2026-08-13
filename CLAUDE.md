# CLAUDE.md — Project Memory for AI Agents

> Read `docs/SESSION_NOTES.md` FIRST for the full session knowledge (release history, Google Sign-In v7 gotchas, signing/keystore notes, test-device quirks, open items).

## Quick facts

- **Random Recall**: Flutter quiz/notification app (`com.inkpebble.randomrecall`), v0.13.21+52, Flutter 3.41.6, Firebase stack + RevenueCat + AdMob (**ads disabled** — `kAdsEnabled = false` in `lib/core/ads/ad_service.dart`), sqflite, provider, l10n EN/ID.
- **Default branch is `develop`**; release = merge to `main` + tag `vX.Y.Z` (CI runs on tags/PRs only).
- **Validation before any commit:** `flutter analyze` (must be 0 issues — CI is strict), `dart format --set-exit-if-changed lib/ test/`, `flutter test` (107/107).
- **Don't touch**: Firestore rules security, App Check config, RevenueCat placeholder-guard, release keystore/key.properties.

## Commands

```bash
flutter analyze
dart format --set-exit-if-changed lib/ test/
flutter test
flutter build apk --debug          # verify native builds
adb logcat -s flutter -v time     # app logs on the test device
```

## Golden rules learned the hard way

1. `google_sign_in` 7.x needs `serverClientId` in `initialize()` — never drop it.
2. Google Sign-In "canceled" on device = SHA-1 fingerprint missing in Firebase console (see SESSION_NOTES §4).
3. Don't swallow `GoogleSignInException` silently — surface real errors.
4. **GitHub publishes the release-signed APK only.** Debug APKs are built locally (`flutter build apk --debug`) for device testing and never uploaded. CI's debug build is a compile check, so its signing key is irrelevant. (Previously CI published a debug APK signed with a per-run random key — that broke Google Sign-In for downloaders and forced an uninstall before every install.)
5. HyperOS refuses `adb install` → push APK to `/sdcard/Download/` and install manually.
6. After big dependency bumps: `flutter clean` if the build complains about stale plugin registrants.
