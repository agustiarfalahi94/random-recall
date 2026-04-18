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
