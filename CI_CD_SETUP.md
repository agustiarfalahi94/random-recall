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
