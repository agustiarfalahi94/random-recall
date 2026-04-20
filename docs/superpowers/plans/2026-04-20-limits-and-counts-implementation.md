# Limits & Counts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enforce category and question caps for free (1/20) and premium (20/200) users, display live counts in UI, add character limits to questions/answers, and add show/hide password toggles to auth screens.

**Architecture:** Remote Config provides all limits + thresholds for server-side tunability; PlanService reads RC values; UI screens display counts with color transitions (neutral → amber → red) and check limits before allowing adds.

**Tech Stack:** Firebase Remote Config, Flutter TextFormField (maxLength, suffixIcon), ARB localization.

---

## Task 1: Remote Config Getters + main.dart Defaults

**Files:**
- Modify: `lib/core/config/remote_config_service.dart` (add 4 getters after line 22)
- Modify: `lib/main.dart` (add 4 keys to setDefaults map around line 113)

### Step 1: Add getters to RemoteConfigService

Open `lib/core/config/remote_config_service.dart` and add these 4 new getters after the existing `freeMaxCustomCategories` getter (around line 23):

```dart
  int get premiumMaxCustomCategories =>
      _rc.getInt('premium_max_custom_categories');
  int get premiumQuestionLimit => _rc.getInt('premium_question_limit');
  int get categoryWarningThreshold =>
      _rc.getInt('category_warning_threshold');
  int get questionWarningThreshold =>
      _rc.getInt('question_warning_threshold');
```

### Step 2: Run flutter analyze to verify syntax

```bash
flutter analyze lib/core/config/remote_config_service.dart
```

Expected: no errors or warnings in this file.

### Step 3: Add defaults to main.dart

Open `lib/main.dart` and find the `setDefaults()` call around line 113. The existing map has:
```dart
await rc.setDefaults(const {
  'free_question_base': 20,
  'free_max_custom_categories': 1,
  ...
```

Add these 4 new entries to that same map:

```dart
'premium_max_custom_categories': 20,
'premium_question_limit': 200,
'category_warning_threshold': 18,
'question_warning_threshold': 195,
```

Complete example (partial, showing the additions in context):
```dart
await rc.setDefaults(const {
  'notif_frequency_free': 5,
  'notif_frequency_premium': 1,
  'notif_start_hour': 8,
  'notif_end_hour': 22,
  'free_question_base': 20,
  'free_max_custom_categories': 1,
  'premium_max_custom_categories': 20,
  'premium_question_limit': 200,
  'category_warning_threshold': 18,
  'question_warning_threshold': 195,
});
```

### Step 4: Verify main.dart compiles

```bash
flutter analyze lib/main.dart
```

Expected: no new errors.

### Step 5: Commit

```bash
git add lib/core/config/remote_config_service.dart lib/main.dart
git commit -m "feat: add remote config getters for premium limits and warning thresholds"
```

---

## Task 2: Update PlanService Logic

**Files:**
- Modify: `lib/core/plan/plan_service.dart` (lines 18–35)

### Step 1: Update getQuestionLimit() for premium

Open `lib/core/plan/plan_service.dart` and locate `getQuestionLimit()` (around line 18). Replace the existing method:

```dart
static Future<int> getQuestionLimit() async {
  if (await isPremium()) return 9999;

  final prefs = await SharedPreferences.getInstance();
  final bonus = prefs.getInt('timer_streak_bonus_questions') ?? 0;
  return freeQuestionBase + bonus;
}
```

With this updated version:

```dart
static Future<int> getQuestionLimit() async {
  if (await isPremium()) {
    return RemoteConfigService.instance.premiumQuestionLimit;
  }

  final prefs = await SharedPreferences.getInstance();
  final bonus = prefs.getInt('timer_streak_bonus_questions') ?? 0;
  return freeQuestionBase + bonus;
}
```

### Step 2: Update canAddCategory() for premium

Locate `canAddCategory()` (around line 32). Replace:

```dart
static Future<bool> canAddCategory(int currentCustomCount) async {
  if (await isPremium()) return true;
  return currentCustomCount < freeMaxCustomCategories;
}
```

With:

```dart
static Future<bool> canAddCategory(int currentCustomCount) async {
  if (await isPremium()) {
    return currentCustomCount <
        RemoteConfigService.instance.premiumMaxCustomCategories;
  }
  return currentCustomCount < freeMaxCustomCategories;
}
```

### Step 3: Verify syntax

```bash
flutter analyze lib/core/plan/plan_service.dart
```

Expected: no errors.

### Step 4: Commit

```bash
git add lib/core/plan/plan_service.dart
git commit -m "fix: update PlanService to use remote config for premium question and category limits"
```

---

## Task 3: Add Character Limits to Add/Edit Question Screen

**Files:**
- Modify: `lib/screens/question/add_edit_question_screen.dart` (lines ~131 and ~158)

### Step 1: Add maxLength to question field

Open `lib/screens/question/add_edit_question_screen.dart` and find the first `TextFormField` for the question (around line 131). It should look like:

```dart
TextFormField(
  controller: _questionController,
  decoration: InputDecoration(
    labelText: 'Question',
    hintText: 'e.g., What is the capital of France?',
  ),
  maxLines: 4,
  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
),
```

Add `maxLength: 200,` after `maxLines: 4,`:

```dart
TextFormField(
  controller: _questionController,
  decoration: InputDecoration(
    labelText: 'Question',
    hintText: 'e.g., What is the capital of France?',
  ),
  maxLines: 4,
  maxLength: 200,
  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
),
```

### Step 2: Add maxLength to answer field

Find the second `TextFormField` for the answer (around line 158). Add `maxLength: 500,` after its `maxLines: 4,`:

```dart
TextFormField(
  controller: _answerController,
  decoration: InputDecoration(
    labelText: 'Answer',
    hintText: 'e.g., Paris',
  ),
  maxLines: 4,
  maxLength: 500,
  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
),
```

### Step 3: Verify the screen builds

```bash
flutter analyze lib/screens/question/add_edit_question_screen.dart
```

Expected: no new errors.

### Step 4: Test manually (optional for now)

Open the app, navigate to Add Question, type in the question field — you should see a character counter below the field.

### Step 5: Commit

```bash
git add lib/screens/question/add_edit_question_screen.dart
git commit -m "feat: add character limits to question (200) and answer (500) fields"
```

---

## Task 4: Add Password Visibility Toggle to Login Screen

**Files:**
- Modify: `lib/screens/auth/email_auth_screen.dart` (add state variable and modify password field)

### Step 1: Add state variable to _EmailAuthScreenState

Open `lib/screens/auth/email_auth_screen.dart` and find the `_EmailAuthScreenState` class. Add this boolean after other field declarations (around line ~30–40):

```dart
bool _obscurePassword = true;
```

### Step 2: Find and modify the password TextFormField

Locate the password field (should have a label like "Password" or similar). Add `suffixIcon` with an `IconButton`:

**Before:**
```dart
TextFormField(
  controller: _passwordController,
  decoration: InputDecoration(
    labelText: 'Password',
  ),
  obscureText: true,
  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
),
```

**After:**
```dart
TextFormField(
  controller: _passwordController,
  decoration: InputDecoration(
    labelText: 'Password',
    suffixIcon: IconButton(
      icon: Icon(
        _obscurePassword
            ? Icons.visibility_off_rounded
            : Icons.visibility_rounded,
      ),
      onPressed: () {
        setState(() {
          _obscurePassword = !_obscurePassword;
        });
      },
      tooltip: _obscurePassword
          ? l10n.showPassword
          : l10n.hidePassword,
    ),
  ),
  obscureText: _obscurePassword,
  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
),
```

### Step 3: Verify syntax

```bash
flutter analyze lib/screens/auth/email_auth_screen.dart
```

Expected: no new errors.

### Step 4: Commit

```bash
git add lib/screens/auth/email_auth_screen.dart
git commit -m "feat: add show/hide password toggle to login screen"
```

---

## Task 5: Add Password Visibility Toggle to Sign-Up Screen

**Files:**
- Modify: `lib/screens/auth/email_signup_screen.dart` (add state variable and modify password field)

### Step 1: Add state variable to _EmailSignupScreenState

Open `lib/screens/auth/email_signup_screen.dart` and find the `_EmailSignupScreenState` class. Add:

```dart
bool _obscurePassword = true;
```

### Step 2: Modify password TextFormField

Apply the same change as Task 4 Step 2: add the `suffixIcon` with the eye icon toggle to the password field.

**Before:**
```dart
TextFormField(
  controller: _passwordController,
  decoration: InputDecoration(
    labelText: 'Password',
  ),
  obscureText: true,
  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
),
```

**After:**
```dart
TextFormField(
  controller: _passwordController,
  decoration: InputDecoration(
    labelText: 'Password',
    suffixIcon: IconButton(
      icon: Icon(
        _obscurePassword
            ? Icons.visibility_off_rounded
            : Icons.visibility_rounded,
      ),
      onPressed: () {
        setState(() {
          _obscurePassword = !_obscurePassword;
        });
      },
      tooltip: _obscurePassword
          ? l10n.showPassword
          : l10n.hidePassword,
    ),
  ),
  obscureText: _obscurePassword,
  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
),
```

### Step 3: Verify syntax

```bash
flutter analyze lib/screens/auth/email_signup_screen.dart
```

Expected: no new errors.

### Step 4: Commit

```bash
git add lib/screens/auth/email_signup_screen.dart
git commit -m "feat: add show/hide password toggle to sign-up screen"
```

---

## Task 6: Add Category Count Display (Manage Categories Screen)

**Files:**
- Modify: `lib/screens/categories/manage_categories_screen.dart` (replace/update the FutureBuilder for category limits around line 152–175)

### Step 1: Review current structure

Open `lib/screens/categories/manage_categories_screen.dart`. Find the `FutureBuilder<bool>` that checks `PlanService.isPremium()` around line 152. Currently it returns:
- For premium: `SizedBox.shrink()` (nothing shown)
- For free: a colored Container with text about the limit

### Step 2: Replace the entire FutureBuilder

Replace the existing `FutureBuilder<bool>(future: PlanService.isPremium(), ...)` block with this new version that shows a count pill for BOTH tiers:

```dart
FutureBuilder<bool>(
  future: PlanService.isPremium(),
  builder: (_, snap) {
    if (snap.connectionState != ConnectionState.done) {
      return const SizedBox.shrink();
    }
    
    final isPremium = snap.data ?? false;
    final limit = isPremium
        ? RemoteConfigService.instance.premiumMaxCustomCategories
        : PlanService.freeMaxCustomCategories;
    final warningThreshold = isPremium
        ? RemoteConfigService.instance.categoryWarningThreshold
        : limit; // Free has no warning, goes straight to red at limit
    
    final current = _customCategories.length;
    final isAtLimit = current >= limit;
    final isWarning = current >= warningThreshold && !isAtLimit;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isAtLimit
              ? colorScheme.errorContainer
              : isWarning
                  ? Color.lerp(
                      colorScheme.surfaceContainerHigh,
                      colorScheme.error,
                      0.3,
                    ) // Amber-ish
                  : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAtLimit ? Icons.lock_rounded : Icons.category_rounded,
              size: 14,
              color: isAtLimit
                  ? colorScheme.onErrorContainer
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              isAtLimit
                  ? l10n.categoryLimitReached(current, limit)
                  : isWarning
                      ? l10n.categoryWarning(current, limit)
                      : l10n.categoryCount(current, limit),
              style: theme.textTheme.labelSmall?.copyWith(
                color: isAtLimit
                    ? colorScheme.onErrorContainer
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  },
),
```

### Step 3: Add RemoteConfigService import

At the top of `manage_categories_screen.dart`, add (if not already present):

```dart
import '../../core/config/remote_config_service.dart';
```

### Step 4: Verify syntax

```bash
flutter analyze lib/screens/categories/manage_categories_screen.dart
```

Expected: no new errors.

### Step 5: Commit

```bash
git add lib/screens/categories/manage_categories_screen.dart
git commit -m "feat: add category count pill for both free and premium users in manage categories screen"
```

---

## Task 7: Add Question Count Display for Premium Users

**Files:**
- Modify: `lib/screens/question/questions_list_screen.dart` (update the conditional around line 218)

### Step 1: Review current code

Open `lib/screens/question/questions_list_screen.dart` and find the question count pill. Currently it's guarded by:

```dart
if (!_isPremium && !_isLoading)
  Padding(...)
```

This means it only shows for free users.

### Step 2: Update the conditional

Change the condition from `if (!_isPremium && !_isLoading)` to `if (!_isLoading)` so it shows for both tiers.

### Step 3: Update the pill content logic

Inside the Padding, find where it builds the count text. Currently it uses hardcoded limit checking. Update it to use dynamic limits per tier:

**Before (partial):**
```dart
final atLimit = !_isPremium && _totalQuestionCount >= _questionLimit;
```

**After:**
```dart
final atLimit = _totalQuestionCount >= _questionLimit;
final warningThreshold = _isPremium
    ? RemoteConfigService.instance.questionWarningThreshold
    : _questionLimit; // Free has no warning threshold
final isWarning = _totalQuestionCount >= warningThreshold && !atLimit;
```

### Step 4: Update the pill color logic

Update the Container's background color to handle the warning state (amber):

**Before:**
```dart
decoration: BoxDecoration(
  color: atLimit
      ? colorScheme.errorContainer
      : colorScheme.surfaceContainerHigh,
  ...
),
```

**After:**
```dart
decoration: BoxDecoration(
  color: atLimit
      ? colorScheme.errorContainer
      : isWarning
          ? Color.lerp(
              colorScheme.surfaceContainerHigh,
              colorScheme.error,
              0.3,
            ) // Amber-ish
          : colorScheme.surfaceContainerHigh,
  ...
),
```

### Step 5: Update the text content

Replace the hardcoded `l10n.questionLimitReached` / `l10n.questionCount` calls to use the new warning strings:

**Before:**
```dart
Text(
  atLimit
      ? l10n.questionLimitReached(
          _totalQuestionCount,
          _questionLimit,
        )
      : l10n.questionCount(
          _totalQuestionCount,
          _questionLimit,
        ),
  ...
),
```

**After:**
```dart
Text(
  atLimit
      ? l10n.questionLimitReached(
          _totalQuestionCount,
          _questionLimit,
        )
      : isWarning
          ? l10n.questionWarning(
              _totalQuestionCount,
              _questionLimit,
            )
          : l10n.questionCount(
              _totalQuestionCount,
              _questionLimit,
            ),
  ...
),
```

### Step 6: Add RemoteConfigService import

At the top of `questions_list_screen.dart`, add:

```dart
import '../../core/config/remote_config_service.dart';
```

### Step 7: Verify syntax

```bash
flutter analyze lib/screens/question/questions_list_screen.dart
```

Expected: no new errors.

### Step 8: Commit

```bash
git add lib/screens/question/questions_list_screen.dart
git commit -m "feat: show question count pill for premium users with dynamic limit and warning thresholds"
```

---

## Task 8: Add Localization Strings

**Files:**
- Modify: `lib/l10n/app_en.arb` (add 8 entries)
- Modify: `lib/l10n/app_id.arb` (add 8 entries)

### Step 1: Add English strings to app_en.arb

Open `lib/l10n/app_en.arb` and add these 8 new entries. Find a good location (alphabetically or at the end before the closing brace):

```json
"categoryCount": "{current, plural, =0{No categories} =1{1 / {max} category} other{{current} / {max} categories}}",
"categoryWarning": "Approaching category limit — {current} / {max}",
"categoryLimitReached": "Category limit reached — {max} / {max}",
"questionCount": "{current, plural, =0{No questions} =1{1 / {max} question} other{{current} / {max} questions}}",
"questionWarning": "Approaching question limit — {current} / {max}",
"questionLimitReached": "Question limit reached — {max} / {max}",
"showPassword": "Show password",
"hidePassword": "Hide password"
```

Make sure to include proper commas between entries and no trailing comma after the last entry.

### Step 2: Add Indonesian strings to app_id.arb

Open `lib/l10n/app_id.arb` and add the Indonesian equivalents:

```json
"categoryCount": "{current, plural, =0{Tidak ada kategori} =1{1 / {max} kategori} other{{current} / {max} kategori}}",
"categoryWarning": "Mendekati batas kategori — {current} / {max}",
"categoryLimitReached": "Batas kategori tercapai — {max} / {max}",
"questionCount": "{current, plural, =0{Tidak ada pertanyaan} =1{1 / {max} pertanyaan} other{{current} / {max} pertanyaan}}",
"questionWarning": "Mendekati batas pertanyaan — {current} / {max}",
"questionLimitReached": "Batas pertanyaan tercapai — {max} / {max}",
"showPassword": "Tampilkan kata sandi",
"hidePassword": "Sembunyikan kata sandi"
```

### Step 3: Verify JSON syntax

Open both files in an editor and verify they're valid JSON (no syntax errors, proper commas).

### Step 4: Commit

```bash
git add lib/l10n/app_en.arb lib/l10n/app_id.arb
git commit -m "docs: add localization strings for limits, counts, and password visibility"
```

---

## Task 9: Generate Localizations & Verify Build

**Files:**
- Generated: `lib/l10n/app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_id.dart`

### Step 1: Run flutter gen-l10n

```bash
flutter gen-l10n
```

Expected output: "Generating localizations..." followed by confirmation that the .dart files were generated.

### Step 2: Run flutter analyze to check for errors

```bash
flutter analyze
```

Expected: no NEW errors introduced by this change. Note: the codebase may have pre-existing info/warnings that are expected.

### Step 3: Test that the app builds

```bash
flutter pub get && flutter build apk --debug 2>&1 | tail -50
```

Expected: successful build with no new errors. (May take 1–2 minutes.)

### Step 4: Commit the generated files

```bash
git add lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_id.dart
git commit -m "chore: regenerate localizations after adding new strings"
```

### Step 5: Final verification

Optionally, start the app in emulator/device and manually test:
1. Add a question — should see character counter at 200 chars
2. Add an answer — should see character counter at 500 chars
3. Manage categories (free user) — should see count pill "X / 1"
4. Manage categories (premium) — should see count pill "X / 20" with color change at 18+
5. Questions list (premium) — should see count pill "X / 200" with color change at 195+
6. Login/Signup screen — should see eye icon to toggle password visibility

If all manual checks pass, you're done with this feature.

---

## Summary

This plan implements:
- ✅ Premium/free limits for categories (20/1) and questions (200/20) via Remote Config
- ✅ Warning thresholds (18 for categories, 195 for questions) with amber color transitions
- ✅ Character limits for question (200) and answer (500) fields
- ✅ Show/hide password toggles on login and signup screens
- ✅ Count displays for both tiers in manage categories and questions list
- ✅ Full English and Indonesian localization

All values are tunable from Firebase Console without app updates.
