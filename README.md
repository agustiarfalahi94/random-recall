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
- Use premium limits and purchases without making the core local experience
  dependent on a network connection.

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
                              ↘ notifications / RevenueCat / telemetry
```

SQLite is the working source for question data and study state. Firestore is
an authenticated backup/synchronization layer. Authentication, sync,
notifications, subscriptions, Remote Config, Crashlytics, Performance and
App Check are isolated behind services so the UI does not own backend policy.

### Firebase rules and access control

[`firestore.rules`](firestore.rules) denies access by default. A signed-in
user can read or write only the `/users/{userId}` tree where the path user ID
matches `request.auth.uid`; writes are capped at 100 KB per document. New
collections are closed until an explicit rule is added. Firebase App Check is
enabled in production to reduce unauthorized use of Firebase resources.

### Environment variables and secrets

Firebase configuration, release signing material and subscription credentials
are supplied locally or through GitHub Actions secrets. The release workflow
injects `GOOGLE_SERVICES_JSON`, keystore files and `REVENUECAT_API_KEY` only at
build time. These values must never be committed. Public build configuration
may be passed with `--dart-define`; it is not a safe place for secrets because
compiled values can be extracted from an APK.

### Privacy and resilience

The app keeps study data locally and syncs only after authentication. Users can
delete their profile and associated cloud data through the account flow. Error
and performance reporting are disabled in debug builds and handled through
Firebase services in release builds. Network failures are treated as
recoverable so local study and notification flows continue.

### CI/CD

GitHub Actions runs dependency installation, localization generation, static
analysis, formatting and tests on pull requests. Tagged builds produce the
release APK only after those checks pass; release signing secrets are injected
only for tag builds. Debug APKs are used as compile checks and are not
published as release artifacts.

## Project areas

- `lib/screens/` — user-facing flows and study sessions.
- `lib/core/auth/` — authentication and account lifecycle.
- `lib/core/sync/` — local/Firestore synchronization.
- `lib/core/notifications/` — scheduled and interactive reminders.
- `lib/core/plan/` — limits, premium state and purchases.
- `firestore.rules` — backend authorization boundary.
- `.github/workflows/flutter-build.yml` — CI and release pipeline.

## License and status

This project is under active development. See the GitHub Actions workflow and
the source tree for the current supported build and test commands.
