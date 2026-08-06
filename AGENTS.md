# AGENTS.md — Instructions for AI Coding Agents (Zed)

> Read `docs/SESSION_NOTES.md` FIRST for the full session knowledge (release history, Google Sign-In v7 gotchas, signing/keystore notes, test-device quirks, open items).

## Project

Random Recall — Flutter quiz/notification app. v0.13.18+49 · Flutter 3.41.6 · Firebase (Auth, Firestore, Storage, Analytics, Crashlytics, Performance, Remote Config, App Check) · RevenueCat · AdMob · sqflite · provider · l10n EN/ID · Android-first (`com.inkpebble.randomrecall`).

## Git flow

- Work on **`develop`** (default branch).
- Release: merge `develop` → `main` locally → push main → annotated tag `vX.Y.Z` → push tag (CI triggers on tags `v*` and PRs; NOT on plain pushes).
- CI is strict: `flutter analyze` (0 issues required), format check, 77/77 tests, debug APK build, auto GitHub Release.

## Validation (run before finishing any task)

```bash
flutter analyze                 # must say "No issues found!"
dart format --output=none --set-exit-if-changed lib/ test/
flutter test                    # 77/77
flutter build apk --debug       # when native code or deps changed
```

## Constraints

- Do NOT weaken security: Firestore rules, App Check (Play Integrity in release), RevenueCat placeholder guard, keystore files.
- Do NOT change the shared CI debug keystore secret flow.
- `google_sign_in` 7.x: always pass `serverClientId`; never swallow non-cancel `GoogleSignInException`s; handle `account-exists-with-different-credential` via the linking flow.
- Localize new user-facing strings (en + id ARB, then `flutter gen-l10n`).
- Keep CHANGELOG.md + CI_CD_SETUP.md + docs/SESSION_NOTES.md in sync with real changes.

## Key files

See docs/SESSION_NOTES.md §9 for the file map.
