# Limits & Counts Design

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:writing-plans (recommended) or superpowers:executing-plans to implement this spec task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enforce sensible category and question caps for free and premium users, display live counts prominently throughout the app, add character limits to question/answer fields, and implement show/hide password toggles on authentication screens.

**Architecture:** 
- All limits and warning thresholds live in Firebase Remote Config for server-side tunability without app updates
- Count displays use consistent pill/badge UI patterns (consistent with existing question count in questions_list_screen)
- Password visibility state is managed locally within each auth screen using a simple boolean flag
- Character limits are enforced by Flutter's `maxLength` TextField property (automatic live counter display)

**Tech Stack:** 
- Firebase Remote Config (limits/thresholds)
- Flutter TextFormField (`maxLength` for limits, `suffixIcon` for password toggle)
- ARB localization for all new strings

---

## Free & Premium Limits

### Categories

**Free tier:**
- Limit: 1 custom category (unchanged from v0.8.0)
- Remote Config key: `free_max_custom_categories` (default: 1)
- Display: compact count pill in Manage Categories screen, "0 / 1" or "1 / 1"
- At limit: pill turns red, message shows "limit reached"

**Premium tier:**
- Limit: 20 custom categories
- Remote Config key: `premium_max_custom_categories` (default: 20)
- Warning threshold: 18 categories (Remote Config: `category_warning_threshold`, default: 18)
- Display: compact count pill in Manage Categories screen
  - Below 18: neutral color, "X / 20"
  - 18–19: amber color, "X / 20 — approaching limit"
  - At 20: red color, "20 / 20 — limit reached" (FAB disabled with lock icon)

### Questions

**Free tier:**
- Limit: 20 questions
- Remote Config key: `free_question_base` (default: 20, already exists)
- Display: existing count pill in Questions List screen
- No changes to existing free user experience

**Premium tier:**
- Limit: 200 questions (changed from unlimited 9999)
- Remote Config key: `premium_question_limit` (default: 200)
- Warning threshold: 195 questions (Remote Config: `question_warning_threshold`, default: 195)
- Display: count pill in Questions List screen (added for premium; previously hidden)
  - Below 195: neutral color, "X / 200"
  - 195–199: amber color, "X / 200 — approaching limit"
  - At 200: red color, "200 / 200 — limit reached" (add button disabled with lock icon)

---

## Character Limits (All Users)

Same limits for free and premium users (app quality, not monetization):

**Question field (add/edit screen):**
- `maxLength: 200`
- Flutter auto-renders live character counter below field

**Answer field (add/edit screen):**
- `maxLength: 500`
- Flutter auto-renders live character counter below field

---

## Count Displays

### Manage Categories Screen
- **Before:** Free users see verbose text banner (unchanged), premium users see nothing (`SizedBox.shrink()`)
- **After:** Both tiers see compact count pill:
  - Located at top of screen, below AppBar, above category list
  - Same styling as question count pill (border container, icon + text, color changes with state)
  - Free: always shows (even if count is 0)
  - Premium: always shows
  - Icon: `Icons.category_rounded` (or `Icons.label_rounded`)

### Questions List Screen
- **Before:** Count pill shown only for free users (`if (!_isPremium && !_isLoading)`)
- **After:** Shown for both tiers (`if (!_isLoading)`)
  - Content unchanged for free tier
  - Added for premium tier with premium-specific limit/warning thresholds
  - Same pill styling and layout
  - Icon: existing `Icons.library_books_outlined`

---

## Show/Hide Password Toggle

Implemented on both **Login** (`email_auth_screen.dart`) and **Sign-up** (`email_signup_screen.dart`) screens.

**UX:**
- Each screen has a local `bool _obscurePassword = true` state variable
- Password `TextFormField` has `suffixIcon: IconButton(...)` 
- Icon: `Icons.visibility_off_rounded` when obscured, `Icons.visibility_rounded` when visible
- Button tap toggles `_obscurePassword` via `setState()`
- Field's `obscureText:` property binds to `_obscurePassword`

**Behavior:**
- Default state on screen load: password hidden (obscured)
- Tapping eye icon: toggles visibility
- Form submission works regardless of visibility state
- No impact on password validation or submission logic

---

## Remote Config Keys & Defaults

All keys are new except `free_max_custom_categories` and `free_question_base` which already exist.

| Key | Type | Default | Purpose |
|---|---|---|---|
| `free_max_custom_categories` | int | 1 | ✓ Existing, unchanged |
| `free_question_base` | int | 20 | ✓ Existing, unchanged |
| `premium_max_custom_categories` | int | 20 | Max custom categories for premium |
| `premium_question_limit` | int | 200 | Max questions for premium (replaces hardcoded 9999) |
| `category_warning_threshold` | int | 18 | Show amber warning at this count (90% of 20) |
| `question_warning_threshold` | int | 195 | Show amber warning at this count (97.5% of 200) |

---

## Localization Strings

### English (`app_en.arb`)
```
"categoryCount": "{current, plural, =0{No categories} =1{1 / {max} category} other{{current} / {max} categories}}",
"categoryWarning": "Approaching category limit — {current} / {max}",
"categoryLimitReached": "Category limit reached — {max} / {max}",
"questionCount": "{current, plural, =0{No questions} =1{1 / {max} question} other{{current} / {max} questions}}",
"questionWarning": "Approaching question limit — {current} / {max}",
"questionLimitReached": "Question limit reached — {max} / {max}",
"showPassword": "Show password",
"hidePassword": "Hide password"
```

### Indonesian (`app_id.arb`)
```
"categoryCount": "{current, plural, =0{Tidak ada kategori} =1{1 / {max} kategori} other{{current} / {max} kategori}}",
"categoryWarning": "Mendekati batas kategori — {current} / {max}",
"categoryLimitReached": "Batas kategori tercapai — {max} / {max}",
"questionCount": "{current, plural, =0{Tidak ada pertanyaan} =1{1 / {max} pertanyaan} other{{current} / {max} pertanyaan}}",
"questionWarning": "Mendekati batas pertanyaan — {current} / {max}",
"questionLimitReached": "Batas pertanyaan tercapai — {max} / {max}",
"showPassword": "Tampilkan kata sandi",
"hidePassword": "Sembunyikan kata sandi"
```

(Note: Adjust plural forms per Indonesian grammar rules as needed during implementation.)

---

## Files Modified

1. **`lib/core/config/remote_config_service.dart`** — add 4 new getters
2. **`lib/main.dart`** — add 4 RC defaults in `setDefaults()`
3. **`lib/core/plan/plan_service.dart`** — update `getQuestionLimit()` and `canAddCategory()` to use RC values
4. **`lib/screens/categories/manage_categories_screen.dart`** — replace free-tier banner + add premium counter
5. **`lib/screens/question/questions_list_screen.dart`** — extend count pill to premium users
6. **`lib/screens/question/add_edit_question_screen.dart`** — add `maxLength` to question and answer fields
7. **`lib/screens/auth/email_auth_screen.dart`** — add password visibility toggle
8. **`lib/screens/auth/email_signup_screen.dart`** — add password visibility toggle
9. **`lib/l10n/app_en.arb`** — add 8 new strings
10. **`lib/l10n/app_id.arb`** — add 8 new strings (Indonesian)

---

## Testing Strategy

- **Unit:** Test `PlanService.getQuestionLimit()` and `canAddCategory()` with mocked Remote Config values
- **UI:** Manual testing on login/signup (password toggle), manage categories (count display), questions list (count display), add question (character limits)
- **Remote Config:** Override values in Firebase Console and verify app reads updated limits without recompile
- **Threshold behavior:** Create enough questions/categories to trigger warning colors and test state transitions (neutral → amber → red)

---

## Not in Scope

- Existing question count localization improvements (use current l10n structure as-is)
- Premium purchase flow changes or entitlement validation (limits assume user's `is_premium` flag is accurate)
- Migration of existing users' data if over new premium limits (assume none currently exceed 200 questions or 20 categories)
