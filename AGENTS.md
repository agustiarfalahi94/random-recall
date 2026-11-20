# AGENTS.md — Instructions for AI Coding Agents (Zed)

> Read `docs/SESSION_NOTES.md` FIRST for the full session knowledge (release history, Google Sign-In v7 gotchas, signing/keystore notes, test-device quirks, open items).

## Project

- Random Recall — Flutter quiz/notification app. v0.14.2+55 · Flutter 3.41.6 · Firebase (Auth, Firestore, Storage, Analytics, Crashlytics, Performance, Remote Config, App Check) · AdMob (**enabled** — `kAdsEnabled = true`; ads are the only revenue) · sqflite · provider · l10n EN/ID · Android-first (`com.inkpebble.randomrecall`).
- **One full version, no subscription.** Every feature is unlocked for every user; there is no paywall, no entitlement, and no IAP SDK.

## Git flow

- Work on **`develop`** (default branch).
- Release: merge `develop` → `main` locally → push main → annotated tag `vX.Y.Z` → push tag (CI triggers on tags `v*` and PRs; NOT on plain pushes).
- CI is strict: `flutter analyze` (0 issues required), format check, 105/105 tests, debug APK build, auto GitHub Release.

## Validation (run before finishing any task)

```bash
flutter analyze                 # must say "No issues found!"
dart format --output=none --set-exit-if-changed lib/ test/
flutter test                    # 105/105
flutter build apk --debug       # when native code or deps changed
```

## Constraints

- Do NOT weaken security: Firestore rules, App Check (Play Integrity in release), keystore files.
- Do NOT reintroduce a client-trusted entitlement or gate features behind a paywall — the premium tier was removed deliberately.
- Do NOT change the shared CI debug keystore secret flow.
- `google_sign_in` 7.x: always pass `serverClientId`; never swallow non-cancel `GoogleSignInException`s; handle `account-exists-with-different-credential` via the linking flow.
- Localize new user-facing strings (en + id ARB, then `flutter gen-l10n`).
- Keep CHANGELOG.md + CI_CD_SETUP.md + docs/SESSION_NOTES.md in sync with real changes.

## How to report to the user (required)

The user is a solo mobile developer, not a release engineer. Long unfiltered status dumps,
re-listing the same open items, or narrating tool calls make it impossible for them to tell what
is done and what they must do. Every substantial answer must follow this shape:

1. **State first, three lines max.** What exists right now, what has already happened, what is
   still pending. Say explicitly when *nothing* external happened yet ("not uploaded", "not
   committed") — the user otherwise assumes the worst or the opposite.
2. **Split ownership with a table**, never a mixed list:
   - **Mine** — things the agent can do alone, *waiting only for a go-ahead*.
   - **Yours** — things only the user can do (accounts, credentials, legal details, uploads).
   - Each row gets a one-line **Why it matters** — the concrete consequence of getting it wrong,
     not a description of the step.
3. **Separate the finish lines.** Distinguish "uploadable today" from "live on Play". Most
   confusion came from mixing them.
4. **End with exactly one decision** the user can answer in a few words, with the literal reply
   options (e.g. `A, commit it` / `B`). No open-ended questions.
5. Prioritise: block-upload items first, then block-launch, then nice-to-have. Never present a
   flat 13-item checklist.
6. No hedging loops. If the same topic comes up twice, give the decision, not another survey.

Keep it short, decision-dense, and diffable against the previous answer so the user can see what
changed since they last read it.

## Key files

See docs/SESSION_NOTES.md §9 for the file map.
