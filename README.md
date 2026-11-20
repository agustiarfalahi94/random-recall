# Random Recall

Random Recall is a Flutter study app that turns a personal question bank into
small, recurring retrieval-practice sessions. It supports local question
storage, scheduled notifications, optional accounts and cross-device backup,
with English and Bahasa Indonesia localization.

## What it does

- Create and manage question categories.
- Receive configurable daily recall notifications.
- Answer questions from a focused notification flow.
- Track streaks, challenges and progress.
- Add an optional profile and sync data across devices.
- Use the full feature set — no question or category caps, unlimited undo, the
  complete analytics breakdown — without making the core local experience
  dependent on a network connection.

Every feature is unlocked for every user. Random Recall has no subscription and
no in-app purchases; it is funded by ads alone.

The app is designed so a temporary Firebase outage does not erase local data
or prevent the user from continuing to study.

## Run locally

Prerequisites: Flutter (stable channel), Android Studio or an Android device,
and a Firebase project for authenticated/sync flows.

```sh
flutter pub get
flutter gen-l10n
flutter run
```

Useful checks:

```sh
flutter analyze
dart format --set-exit-if-changed lib/
flutter test
```

The Firebase Android configuration is intentionally not committed. For local
Firebase development, place the configuration file supplied by Firebase at
`android/app/google-services.json` and keep it out of version control.

## Architecture & Security

The app uses a local-first Flutter architecture:

```text
Flutter UI → providers/services → SQLite + SharedPreferences
                              ↘ Firebase Auth / Firestore sync
                              ↘ notifications / ads / telemetry
```

SQLite is the working source for question data and study state. Firestore is
an authenticated backup/synchronization layer. Authentication, sync,
notifications, ads, Remote Config, Crashlytics, Performance and App Check are
isolated behind services so the UI does not own backend policy.

### Firebase rules and access control

[`firestore.rules`](firestore.rules) denies access by default. A signed-in
user can read or write only the `/users/{userId}` tree where the path user ID
matches `request.auth.uid`; writes are capped at 100 KB per document. New
collections are closed until an explicit rule is added. Firebase App Check is
enabled in production to reduce unauthorized use of Firebase resources.

### Environment variables and secrets

Firebase configuration and release signing material are supplied locally or
through GitHub Actions secrets. The release workflow injects
`GOOGLE_SERVICES_JSON` and the keystore files only at build time (no build-time
API keys are needed — the ad unit IDs live in source, as Google intends).
These values must never be committed. Public build configuration
may be passed with `--dart-define`; it is not a safe place for secrets because
compiled values can be extracted from an APK.

### Privacy and resilience

The app keeps study data locally and syncs only after authentication. Users can
delete their profile and associated cloud data through the account flow. Error
and performance reporting are disabled in debug builds and handled through
Firebase services in release builds. Network failures are treated as
recoverable so local study and notification flows continue.

The public privacy policy and the account-deletion page live in
`docs/privacy/` and are served by GitHub Pages at
`https://agustiarfalahi94.github.io/random-recall/privacy/`. They are the URLs
AdMob and the Play Console point at, so they change only through a PR to
`main`.

### CI/CD

GitHub Actions runs dependency installation, localization generation, static
analysis, formatting and tests on pull requests. Both `develop` and `main` are
protected, so every change lands through a pull request; CI triggers on PRs and
on `v*` tags, never on a plain branch push.

A `v*` tag builds the release APK **and** the release AAB after the checks pass
and attaches both to a GitHub Release. The AAB is what the Play Console accepts;
the APK is for testers. Release signing secrets are injected only for tag builds,
and debug APKs are compile checks that are never published.

Uploading to Play is a human step by default: Google Play has no "pull from
GitHub" option, and only the Play Developer API can push a bundle. See
[`CI_CD_SETUP.md`](CI_CD_SETUP.md) for the service-account path.

## Project areas

- `lib/screens/` — user-facing flows and study sessions.
- `lib/core/auth/` — authentication and account lifecycle.
- `lib/core/sync/` — local/Firestore synchronization.
- `lib/core/notifications/` — scheduled and interactive reminders.
- `lib/core/ads/` — AdMob banner/interstitial serving, frequency caps and the
  keyboard/excluded-screen rules.
- `firestore.rules` — backend authorization boundary.
- `.github/workflows/flutter-build.yml` — CI and release pipeline.
- `store/` — Play Store listing copy, release notes, feature graphics and
  screenshots (`PLAY_STORE_LISTING.md`, `RELEASE_NOTES.md`, `assets/`, `raw/`).
- `docs/privacy/` — the public privacy policy and account-deletion pages
  (GitHub Pages source, English + Bahasa Indonesia).
- `tools/` — Pillow scripts that regenerate the store graphics and framed
  screenshots from the source icon and the raw device captures.

## License and status

This project is under active development. See the GitHub Actions workflow and
the source tree for the current supported build and test commands.
