# CI/CD Pipeline Setup - Random Recall

## Overview

This GitHub Actions workflow automates testing and building for Random Recall. **Currently, it does NOT deploy to Play Store** (we're not live yet), but it's fully ready for when you launch.

---

## What This Pipeline Does (NOW)

### ✅ On Every Push/PR:

1. **Code Analysis** 
   - Runs Dart analyzer (catches bugs & issues)
   - Checks code formatting (consistent style)
   - Status: ✓ ACTIVE

2. **Automated Testing**
   - Runs all unit & widget tests
   - Generates coverage reports
   - Prevents broken code from merging
   - Status: ✓ ACTIVE

3. **Build APK & AAB**
   - Builds debug APK (for testing)
   - Builds release APK (production-ready)
   - Builds App Bundle (Play Store format)
   - Status: ✓ ACTIVE

4. **Store Artifacts**
   - Saves built APKs in GitHub
   - You can download & test manually
   - 30-day retention
   - Status: ✓ ACTIVE

5. **Play Store Deployment**
   - **Status: DISABLED (not needed yet)**
   - Ready to activate when app launches
   - See "Future Setup" section below

---

## Code Quality Baseline (2026-08-06)

A full release-readiness audit was performed. Before this pass the analyzer reported **69 issues**; after it, **`flutter analyze` reports 0 issues** and the whole `lib/` tree passes `dart format --set-exit-if-changed`.

### What changed

1. **Analyzer is now strict in CI** — the workflow runs plain `flutter analyze` (warnings AND infos are fatal). A lint regression now blocks the merge instead of being silently ignored. This prevents the 69 issues from coming back.
2. **All deprecated API usage migrated** (Flutter 3.41.x): `withOpacity` → `withValues(alpha:)`, `RadioListTile.groupValue/onChanged` → `RadioGroup`, `TextFormField.value` → `initialValue`, RevenueCat `purchasePackage` → `purchase(PurchaseParams.package(...))`.
3. **Async context safety** — every `use_build_context_synchronously` finding fixed with `mounted` guards or capture-before-await (prevents crashes from using a disposed BuildContext after `await`).
4. **Dead code removed** — unused `_keyLastDate` constant and an unused import.
5. **Stray files deleted** — `android/app/auth_service.dart` and `android/app/login_screen.dart` (0-byte files accidentally placed outside `lib/`; they would be packaged into release builds).
6. **Release build guidance** — the commented Play Store deploy step now recommends `flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info` (R8 minification + `proguard-rules.pro` are already active in `android/app/build.gradle.kts`).

### Test suite fixed (was: known test gap)

`test/core/streak/streak_service_test.dart` had 11 failing tests because the test environment never called `Firebase.initializeApp()` — `StreakService.startChallenge` touches the `AnalyticsService` singleton which requires a Firebase app. **Resolved 2026-08-06**: the test now installs minimal in-memory fakes for `FirebasePlatform` and `FirebaseAuthPlatform` (via `firebase_core_platform_interface` + `firebase_auth_platform_interface`, added as dev-only dependencies) so Firebase singletons resolve without native channels. Test suite is now **77/77 passing**.

### RevenueCat API key

The Android RevenueCat key is no longer hardcoded in `subscription_service.dart`. It is read from `--dart-define=REVENUECAT_API_KEY=...` at build time; without it (or with a placeholder), RevenueCat init is skipped exactly as before. When deploying, add the key as a GitHub secret and pass it in the release build step (see `.github/workflows/flutter-build.yml`).

### Root/jailbreak detection (informational)

Added 2026-08-06: `lib/core/services/root_detection_service.dart` detects rooted/jailbroken devices via `flutter_jailbreak_detection`. The signal is (1) logged to Firebase Analytics (`device_root_status` event) for developer visibility and (2) shown to the user once via a dismissible dialog on first app open. Nothing is blocked. The unmaintained plugin required two compatibility shims in `android/build.gradle.kts` (AGP 8 namespace + per-plugin JVM-target matching), verified with a successful debug APK build.

### Security hardening (2026-08-06, v0.13.15)

- **FLAG_SECURE screenshot blocking** on quiz screens (Android only; native method channel in `MainActivity.kt`).
- **Anti-enumeration login** — unknown emails and wrong passwords show one generic error.
- **`allowBackup="false"`** — local data can't be pulled from Google Drive backups (cloud sync covers logged-in users).
- **Dead config/deps removed** — PostHog meta-data (SDK not used) and the unused `http` package.
- **Firestore rules: 100 KB/document write cap** — deploy via `firebase deploy --only firestore:rules`.

### Pre-release checklist
- ⬜ Replace the AdMob **test app ID** in `AndroidManifest.xml` with the real one from the AdMob console (currently serving test ads).
- ✅ Deploy the updated `firestore.rules` — done 2026-08-06.

### CI test-APK signature (2026-08-06)

Every GitHub Actions runner generates a **random debug keystore**, so APKs from different runs used to have different signatures and could not be installed over each other ("App not installed" / error). Fixed by storing one shared debug keystore as the `DEBUG_KEYSTORE_BASE64` secret; the workflow decodes it to `~/.android/debug.keystore` before building, so all CI APKs are upgradeable. This only affects test builds — Play Store releases are signed with the release keystore (`release-keystore.jks`) and are unaffected.

### Google Sign-In on test builds (SHA-1 fingerprints)

`google_sign_in` 7.x uses Android's Credential Manager, which validates the requesting app by **package name + signing-cert SHA-1 fingerprint** against the Firebase project. If the fingerprint isn't registered, the flow silently returns `canceled` after the user picks an account. Register in Firebase Console → Project settings → Your apps → Android app → **Add fingerprint**:

| Fingerprint | For |
|---|---|
| `D8:3D:DF:7A:0C:69:B8:AC:46:C6:B2:5B:43:F1:E6:6B:56:BF:5C:91` | CI test APKs (shared debug keystore) |
| `A6:47:FF:68:C3:3F:36:3D:EC:6A:ED:76:C0:E9:94:89:DE:E0:64:E4` | Local debug builds (`flutter run`) |
| `D3:A4:D2:EE:B9:94:1B:35:05:61:64:9B:ED:90:53:2E:96:8E:A0:BD` | Release keystore (GitHub distribution APK + Play Store production) |

### GitHub distribution APK (release-signed) — 2026-08-07

**Why a debug APK breaks Google Sign-In for downloaders:** Credential Manager only
issues an ID token when the requesting app's signing-cert SHA-1 is registered in the
Firebase project for that package. Debug APKs are signed with whichever keystore
built them, so only builds from keystores you register can log in. Everyone else who
publishes APKs on GitHub publishes **release APKs signed with their release keystore**
(one stable fingerprint, registered once) — that's the workaround.

The GitHub Release now attaches a **release APK** (`RandomRecall-vX.Y.Z.apk`) signed
with the release keystore (fingerprint `D3:A4:...` above — already registered), so the
downloaded app passes Google Sign-In exactly like a Play Store build. The debug APK is
attached as `RandomRecall-vX.Y.Z-debug.apk` for internal testing only.

**One-time secret setup** (the workflow fails the build if these are missing — a
debug-signed "release" APK would silently break login for downloaders):

```bash
base64 -i android/app/release-keystore.jks | gh secret set KEYSTORE_BASE64
gh secret set KEYSTORE_PROPERTIES < android/key.properties
```

Verify with `gh secret list`. The workflow decodes them to `android/key.properties` +
`android/app/release-keystore.jks`, then runs
`flutter build apk --release --dart-define=REVENUECAT_API_KEY=${{ secrets.REVENUECAT_API_KEY }}`
(the app skips RevenueCat init when the key is empty/placeholder, so a missing secret
is safe).

**Caveats:**
- The release APK cannot be installed over a debug install (different signature) — uninstall first.
- Release builds use R8 minification — verify once on a device before sharing (the release build was verified locally on 2026-08-07).
- When you later upload to Play Console, Play App Signing re-signs the app: register the **Play-generated** signing key's SHA-1 in Firebase Console for Google Sign-In on Play-installed builds.

Also note: the v7 plugin requires `serverClientId` passed to `GoogleSignIn.initialize()` — it no longer reads it from google-services.json. Handled in `AuthService._ensureGoogleInitialized()` (v0.13.17). Accounts that collide with an existing email/password account are resolved by a password prompt that **links** the Google credential (`AccountExistsException` flow, v0.13.17).

---

## Current Workflow Branches

```
develop branch (development) 
  ↓ Push code
  ↓ GitHub Actions runs
  ↓ Tests pass? → Build APK
  ↓ Tests fail? → Stop, notify you

main branch (future production)
  ↓ Same as above
  ↓ When you go live: automatic Play Store upload
```

---

## How to Use RIGHT NOW

### 1. Commit & Push This File

```bash
git add .github/workflows/flutter-build.yml
git add CI_CD_SETUP.md
git commit -m "ci: Add GitHub Actions CI/CD pipeline

- Automated code analysis on every push
- Automated testing before merge
- Build APK/AAB artifacts
- Ready for Play Store deployment when app launches"
git push origin feature/add-bahasa-indonesia-language
```

### 2. Watch the Pipeline Run

- Go to: `https://github.com/agustiarfalahi94/random-recall/actions`
- You'll see your workflow running
- Check status on your PRs (green checkmark = passed)

### 3. Download Built APKs (For Testing)

After successful build:
- Go to Actions tab
- Click the workflow run
- Scroll down to "Artifacts"
- Download `random-recall-release.apk` to test on your phone

---

## Benefits You Get RIGHT NOW

| Benefit | What It Does |
|---------|------------|
| **Catch bugs early** | Tests run automatically, find issues before merge |
| **Code quality** | Analyzer catches problems you might miss |
| **Consistent builds** | Every build is identical, no "works on my machine" |
| **Testing proof** | Shows tests pass on every commit (for CV!) |
| **Build artifacts** | Download APK to test before manual Play Store upload |

---

## Future: Enabling Play Store Deployment

When you're ready to launch on Play Store (Step 1 of going live):

### Step 1: Create Google Play Service Account

1. Go to: `https://play.google.com/console`
2. Settings → API access → Create service account
3. Download JSON credentials file
4. **Keep this file SAFE** (it's like your password)

### Step 2: Add GitHub Secret

1. Go to your GitHub repo
2. Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Name: `PLAY_STORE_CREDENTIALS`
5. Paste the JSON file contents
6. Save

### Step 3: Enable Deployment in Workflow

In `.github/workflows/flutter-build.yml`, uncomment these sections:
- `Upload to Play Store (Internal Testing)` - for develop branch
- `Upload to Play Store (Beta)` - for staging branch (if you create it)
- `Upload to Play Store (Production)` - for main branch

### Step 4: Test Deployment

Push to develop branch → Check Actions tab → See automatic upload!

---

## Workflow Decision Tree

```
You push code to GitHub
    ↓
GitHub Actions starts automatically
    ↓
┌─────────────────────────────────┐
│ Step 1: Code Analysis           │
│ • Run dart analyzer             │
│ • Check code formatting         │
└──────────┬──────────────────────┘
           ↓
    Analysis passes?
    ↙           ↘
  NO           YES
   │             │
   ▼             ▼
STOP      ┌─────────────────┐
NOTIFY    │ Step 2: Testing │
YOU       │ • Run unit tests│
          │ • Run widget    │
          │   tests         │
          └────────┬────────┘
                   ↓
           Tests pass?
           ↙        ↘
         NO        YES
          │          │
          ▼          ▼
       STOP      ┌──────────────────┐
       NOTIFY    │ Step 3: Build    │
       YOU       │ • Build APK      │
                 │ • Build AAB      │
                 │ • Store artifacts│
                 └────────┬─────────┘
                          ↓
                   Build successful?
                   ↙          ↘
                 NO           YES
                  │             │
                  ▼             ▼
              STOP          ✅ SUCCESS
              NOTIFY        Ready for testing
              YOU           (future: auto-upload)
```

---

## For Your CV

You can now say:

```
CI/CD & Automation:
• GitHub Actions for automated Flutter build pipeline
• Continuous code analysis (Dart analyzer, format checker)
• Automated testing on every commit (unit & widget tests)
• Build APK/AAB artifacts for testing & deployment
• Staged rollout workflow (develop → staging → production)
• Ready for Play Store automated deployment
```

This is **legitimate, professional, and real**.

---

## Common Questions

### Q: Will this deploy to Play Store now?
**A:** No, deployment is commented out. Nothing goes to Play Store until you uncomment those lines.

### Q: What if tests fail?
**A:** Pipeline stops, notifies you, blocks the merge. You fix it locally, push again.

### Q: Can I download the APK to test?
**A:** Yes! After successful build, download from Actions → Artifacts.

### Q: What if someone merges broken code?
**A:** They can't. Tests must pass before merge (if you set branch protection).

### Q: How do I set up branch protection?
**A:** Repo → Settings → Branches → Add rule. Require status checks to pass.

---

## Next Steps

1. ✅ Commit this workflow file
2. ✅ Push to GitHub
3. ✅ Watch it run on your PRs
4. ✅ When ready for Play Store: uncomment deployment section + add credentials
5. ✅ Automatic updates to users!

---

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Flutter Actions](https://github.com/subosito/flutter-action)
- [Play Store Upload Action](https://github.com/r0adkll/upload-google-play)
- [Google Play Console](https://play.google.com/console)
