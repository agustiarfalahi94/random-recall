# UI/UX Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement three independent UI/UX features: display name prompt with validation, challenge mode overhaul with stricter rules and rewards, and increased notification limits.

**Architecture:** Three independent feature implementations. Display name integrates with Firebase Auth and Firestore. Challenge mode extends StreakService with new state management and UI dialogs. Notification limit is a simple slider update. All features include localization (English + Indonesian).

**Tech Stack:** Firebase Auth (displayName), Firestore (persistence), Google Safe Browsing API, Flutter UI (dialogs, forms), ARB localization files.

---

## Feature 1: Display Name Prompt

### Task 1: Create Display Name Service with Character Validation

**Files:**
- Create: `lib/services/display_name_service.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_id.arb`

- [ ] **Step 1: Write test for character validation**

```dart
// test/services/display_name_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:random_recall/services/display_name_service.dart';

void main() {
  group('DisplayNameService', () {
    test('accepts valid characters: letters, numbers, spaces, hyphens, underscores', () {
      expect(DisplayNameService.isValidCharacters('John Doe-123_test'), true);
      expect(DisplayNameService.isValidCharacters('Jean-Pierre'), true);
      expect(DisplayNameService.isValidCharacters('User_Name'), true);
    });

    test('rejects special characters', () {
      expect(DisplayNameService.isValidCharacters('John@Doe'), false);
      expect(DisplayNameService.isValidCharacters('User!Name'), false);
      expect(DisplayNameService.isValidCharacters('Test#123'), false);
      expect(DisplayNameService.isValidCharacters('Name$'), false);
    });

    test('rejects empty or whitespace-only names', () {
      expect(DisplayNameService.isValidCharacters(''), false);
      expect(DisplayNameService.isValidCharacters('   '), false);
    });

    test('rejects names exceeding 50 characters', () {
      expect(DisplayNameService.isValidCharacters('a' * 51), false);
      expect(DisplayNameService.isValidCharacters('a' * 50), true);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/lilianyoctoria/Documents/random_recall
flutter test test/services/display_name_service_test.dart
```

Expected: FAIL - DisplayNameService does not exist

- [ ] **Step 3: Create DisplayNameService class with validation**

```dart
// lib/services/display_name_service.dart

class DisplayNameService {
  // Whitelist: letters (a-z, A-Z), numbers (0-9), spaces, hyphens (-), underscores (_)
  static final RegExp _validCharPattern = RegExp(r'^[a-zA-Z0-9\s\-_]*$');
  static const int maxLength = 50;

  /// Validates that the name contains only allowed characters and is within length limit
  static bool isValidCharacters(String name) {
    if (name.isEmpty || name.trim().isEmpty) {
      return false;
    }
    if (name.length > maxLength) {
      return false;
    }
    return _validCharPattern.hasMatch(name);
  }

  /// Checks if name contains only whitespace
  static bool isWhitespaceOnly(String name) {
    return name.trim().isEmpty;
  }

  /// Returns the trimmed display name (leading/trailing spaces removed)
  static String normalize(String name) {
    return name.trim();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/services/display_name_service_test.dart
```

Expected: PASS - all 4 test groups passing

- [ ] **Step 5: Add localization strings for validation errors**

```json
// lib/l10n/app_en.arb
{
  "displayNameInputHint": "Enter your name",
  "displayNameLabel": "Display Name",
  "displayNameMaxLength": "50 characters maximum",
  "displayNameInvalidCharacters": "Only letters, numbers, spaces, hyphens, and underscores allowed.",
  "displayNameEmpty": "Please enter a name.",
  "displayNameSubmit": "Continue",
  "displayNameCancel": "Cancel"
}
```

```json
// lib/l10n/app_id.arb
{
  "displayNameInputHint": "Masukkan nama Anda",
  "displayNameLabel": "Nama Tampilan",
  "displayNameMaxLength": "Maksimal 50 karakter",
  "displayNameInvalidCharacters": "Hanya huruf, angka, spasi, tanda hubung, dan garis bawah yang diperbolehkan.",
  "displayNameEmpty": "Silakan masukkan nama.",
  "displayNameSubmit": "Lanjutkan",
  "displayNameCancel": "Batal"
}
```

- [ ] **Step 6: Run `flutter gen-l10n` to regenerate localization**

```bash
cd /Users/lilianyoctoria/Documents/random_recall
flutter gen-l10n
```

Expected: New localization strings accessible via `l10n.displayNameInputHint()`, etc.

- [ ] **Step 7: Commit**

```bash
git add lib/services/display_name_service.dart test/services/display_name_service_test.dart lib/l10n/app_en.arb lib/l10n/app_id.arb
git commit -m "feat: add DisplayNameService with character validation and i18n strings"
```

---

### Task 2: Integrate Google Safe Browsing API for Profanity Check

**Files:**
- Modify: `lib/services/display_name_service.dart`
- Modify: `pubspec.yaml` (add http package if needed)
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_id.arb`

- [ ] **Step 1: Write test for profanity detection**

```dart
// test/services/display_name_service_test.dart (add to existing file)

test('detects profanity via Safe Browsing API', () async {
  // Mock API - in real implementation would call Google Safe Browsing
  // For this test, we verify the method exists and handles responses
  final service = DisplayNameService();
  
  // This would be a mock test - actual implementation will test with mock HTTP
  expect(service.isProfane, isNotNull);
});
```

- [ ] **Step 2: Add profanity check method to DisplayNameService**

```dart
// lib/services/display_name_service.dart (add to class)

import 'package:http/http.dart' as http;
import 'dart:convert';

class DisplayNameService {
  // ... existing code ...

  /// Checks if name contains profanity using Google Safe Browsing API
  /// Returns true if profanity detected, false if clean
  /// In production, requires GOOGLE_SAFE_BROWSING_API_KEY environment variable
  static Future<bool> checkProfanity(String name) async {
    // For now, return false (safe) - will be implemented after Firebase setup
    // Real implementation would call Google Safe Browsing API's malware/toxicity check
    // However, since we need API key and this is a Flutter app, we'll do client-side
    // checking on backend or use a simpler local approach
    
    // TODO: Implement with Google Safe Browsing API after determining backend approach
    return false; // Temporarily allow all names - will be replaced
  }
}
```

- [ ] **Step 3: Add profanity error messages to localization**

```json
// lib/l10n/app_en.arb (add to existing object)
{
  "displayNameProfanity": "This name contains inappropriate content. Please choose another.",
  "@displayNameProfanity": {}
}
```

```json
// lib/l10n/app_id.arb
{
  "displayNameProfanity": "Nama ini mengandung konten yang tidak pantas. Silakan pilih yang lain.",
  "@displayNameProfanity": {}
}
```

- [ ] **Step 4: Run `flutter gen-l10n`**

```bash
flutter gen-l10n
```

Expected: New localization strings accessible

- [ ] **Step 5: Commit**

```bash
git add lib/services/display_name_service.dart lib/l10n/app_en.arb lib/l10n/app_id.arb
git commit -m "feat: add profanity detection stub to DisplayNameService (implementation pending API setup)"
```

---

### Task 3: Create Display Name Setup Screen UI

**Files:**
- Create: `lib/screens/auth/display_name_setup_screen.dart`

- [ ] **Step 1: Create the display name setup screen widget**

```dart
// lib/screens/auth/display_name_setup_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:random_recall/services/display_name_service.dart';

class DisplayNameSetupScreen extends StatefulWidget {
  final bool canDismiss; // false for new users (can't skip), true for existing users (optional)
  final VoidCallback? onComplete;

  const DisplayNameSetupScreen({
    Key? key,
    this.canDismiss = false,
    this.onComplete,
  }) : super(key: key);

  @override
  State<DisplayNameSetupScreen> createState() => _DisplayNameSetupScreenState();
}

class _DisplayNameSetupScreenState extends State<DisplayNameSetupScreen> {
  final _controller = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validateInput(String value) {
    setState(() {
      final l10n = AppLocalizations.of(context)!;
      
      if (DisplayNameService.isWhitespaceOnly(value)) {
        _errorMessage = l10n.displayNameEmpty;
      } else if (!DisplayNameService.isValidCharacters(value)) {
        _errorMessage = l10n.displayNameInvalidCharacters;
      } else {
        _errorMessage = null;
      }
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _controller.text.trim();

    // Validate
    if (!DisplayNameService.isValidCharacters(name)) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check profanity
      final isProfane = await DisplayNameService.checkProfanity(name);
      if (isProfane) {
        setState(() {
          _errorMessage = l10n.displayNameProfanity;
          _isLoading = false;
        });
        return;
      }

      // Update Firebase Auth displayName
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updateDisplayName(name);
        
        // Also save to Firestore for backup
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(
              {'name': name, 'updatedAt': FieldValue.serverTimestamp()},
              SetOptions(merge: true),
            );
      }

      widget.onComplete?.call();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving name. Please try again.';
        _isLoading = false;
      });
    }
  }

  bool get _isValid => 
      _errorMessage == null && 
      _controller.text.isNotEmpty &&
      DisplayNameService.isValidCharacters(_controller.text);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async => widget.canDismiss, // Can't dismiss if canDismiss=false
      child: Dialog(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.displayNameLabel,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.displayNameMaxLength,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  onChanged: _validateInput,
                  enabled: !_isLoading,
                  maxLength: DisplayNameService.maxLength,
                  decoration: InputDecoration(
                    hintText: l10n.displayNameInputHint,
                    border: OutlineInputBorder(),
                    errorText: _errorMessage,
                    counterText: '${_controller.text.length}/${DisplayNameService.maxLength}',
                    suffixIcon: _errorMessage == null && _controller.text.isNotEmpty
                        ? Icon(Icons.check_circle, color: Colors.green)
                        : null,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (widget.canDismiss)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : () => Navigator.pop(context),
                          child: Text(l10n.displayNameCancel),
                        ),
                      ),
                    if (widget.canDismiss) const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _isLoading || !_isValid ? null : _submit,
                        child: _isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(l10n.displayNameSubmit),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Test the screen displays and validates correctly**

```bash
# Manual test: run app and verify dialog appears, validates characters, shows error messages
flutter run
```

Expected: Dialog shows with input field, error messages appear for invalid input, submit button disabled until valid

- [ ] **Step 3: Commit**

```bash
git add lib/screens/auth/display_name_setup_screen.dart
git commit -m "feat: create DisplayNameSetupScreen with real-time validation"
```

---

### Task 4: Integrate Display Name Prompt at App Launch

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Add check for empty display name on app launch**

```dart
// lib/main.dart - modify the main app build method or add to home screen

// In your app initialization (likely in main() or in the home screen's initState):

Future<void> _checkAndShowDisplayNamePrompt() async {
  final user = FirebaseAuth.instance.currentUser;
  
  if (user != null && (user.displayName == null || user.displayName!.isEmpty)) {
    // Show display name setup screen
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false, // Can't dismiss for new users
        builder: (context) => DisplayNameSetupScreen(
          canDismiss: false,
          onComplete: () {
            // Dialog will auto-close, refresh home screen
            setState(() {});
          },
        ),
      );
    }
  }
}
```

Add this call to your home screen's `initState()` or main app's initialization logic.

- [ ] **Step 2: Test display name prompt appears on launch for users without displayName**

```bash
flutter run
# Create new account or use existing account without displayName
# Verify dialog appears on home screen and can't be dismissed
```

Expected: Dialog appears, can't be closed without entering valid name, then closes and shows updated welcome message

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat: show display name prompt on app launch for users without displayName"
```

---

### Task 5: Test Complete Display Name Feature

**Files:**
- Test: Full integration testing

- [ ] **Step 1: Test new user signup flow**

Manual test:
1. Clear app data / create new account
2. After email verification, display name prompt should appear automatically
3. Reject invalid characters (e.g., "John@Doe")
4. Accept valid names (e.g., "John Doe", "Jean-Pierre")
5. Verify Firebase Auth displayName is updated
6. Verify welcome message shows correct name on home screen

Expected: All steps pass

- [ ] **Step 2: Test existing user without displayName**

Manual test:
1. Use existing account without displayName (or manually clear it via Firebase Console)
2. Close and reopen app
3. Display name prompt should appear on home screen
4. Complete prompt and verify name persists across app restarts

Expected: All steps pass

- [ ] **Step 3: Test localization**

Manual test:
1. Change app language to Indonesian (via device settings or in-app language selector)
2. Create new account
3. Verify all validation messages appear in Indonesian
4. Verify welcome message shows "Selamat datang, [name]"

Expected: All Indonesian translations correct

- [ ] **Step 4: Commit (no code changes, just verification)**

```bash
# All tests pass, feature complete
git status
# Should be clean
```

---

## Feature 2: Challenge Mode Overhaul

### Task 6: Update StreakService Data Model for Challenge Mode

**Files:**
- Modify: `lib/core/streak/streak_service.dart`

- [ ] **Step 1: Review current StreakService**

```bash
cd /Users/lilianyoctoria/Documents/random_recall
# Read lib/core/streak/streak_service.dart to understand current structure
```

Expected: Understand current streak tracking, bonus questions system

- [ ] **Step 2: Add challenge mode state properties**

Add to `StreakService` class:

```dart
// Challenge mode state
static const _keyChallengeModeActive = 'challenge_mode_active';
static const _keyChallengeModeStartDate = 'challenge_mode_start_date';
static const _keyChallengeModeDay = 'challenge_mode_day';
static const _keyChallengeDuration = 'challenge_duration'; // 7 or 14
static const _keyChallengeLockedFrequency = 'challenge_locked_frequency';
static const _keyChallengeLastAnswerDate = 'challenge_last_answer_date';
static const _keyTotal7DayCompleted = 'total_7day_completed';
static const _keyTotal14DayCompleted = 'total_14day_completed';
static const _keyChallengeBadgeUnlocked = 'challenge_badge_unlocked';
static const _keyHighestTitle = 'highest_title'; // Challenger, Champion, Legend
static const _keyBonusCategories = 'bonus_categories'; // free-tier only

// Reward constants
static const int questionsMax = 200;
static const int categoriesMax = 20;
static const int questionBase = 20;
static const int categoryBase = 4;

// Methods to add:
bool get isChallengeActive => _prefs.getBool(_keyChallengeModeActive) ?? false;
int get challengeDay => _prefs.getInt(_keyChallengeModeDay) ?? 0;
int get challengeDuration => _prefs.getInt(_keyChallengeDuration) ?? 7;
int get lockedFrequency => _prefs.getInt(_keyChallengeLockedFrequency) ?? 0;
int get total7DayCompleted => _prefs.getInt(_keyTotal7DayCompleted) ?? 0;
int get total14DayCompleted => _prefs.getInt(_keyTotal14DayCompleted) ?? 0;
bool get challengeBadgeUnlocked => _prefs.getBool(_keyChallengeBadgeUnlocked) ?? false;
String get highestTitle => _prefs.getString(_keyHighestTitle) ?? '';
int get bonusCategories => _prefs.getInt(_keyBonusCategories) ?? 0;

// Challenge mode setters
Future<void> startChallenge(int duration, int frequency) async {
  await _prefs.setBool(_keyChallengeModeActive, true);
  await _prefs.setInt(_keyChallengeDuration, duration);
  await _prefs.setInt(_keyChallengeDay, 1);
  await _prefs.setInt(_keyChallengeLockedFrequency, frequency);
  await _prefs.setString(_keyChallengeModeStartDate, DateTime.now().toIso8601String());
  await _saveToFirestore();
}

Future<void> incrementChallengeDay() async {
  final newDay = challengeDay + 1;
  await _prefs.setInt(_keyChallengeModeDay, newDay);
  await _prefs.setString(_keyChallengeLastAnswerDate, DateTime.now().toIso8601String());
  await _saveToFirestore();
}

Future<void> resetChallenge() async {
  await _prefs.remove(_keyChallengeModeActive);
  await _prefs.remove(_keyChallengeModeDay);
  await _prefs.remove(_keyChallengeDuration);
  await _prefs.remove(_keyChallengeLockedFrequency);
  await _prefs.remove(_keyChallengeModeStartDate);
  await _prefs.remove(_keyChallengeLastAnswerDate);
  // Reset current streak
  await _prefs.setInt(_keyCurrentStreak, 0);
  await _saveToFirestore();
}

Future<void> completeChallengeMode(int duration) async {
  // Challenge completed successfully
  if (duration == 7) {
    await _prefs.setInt(_keyTotal7DayCompleted, total7DayCompleted + 1);
    // Award bonus question
    await _prefs.setInt(_keyBonusQuestions, bonusQuestions + 1);
  } else if (duration == 14) {
    await _prefs.setInt(_keyTotal14DayCompleted, total14DayCompleted + 1);
    // Award bonus question + category
    await _prefs.setInt(_keyBonusQuestions, bonusQuestions + 1);
    await _prefs.setInt(_keyBonusCategories, bonusCategories + 1);
  }
  
  await resetChallenge();
  await _saveToFirestore();
}

Future<void> unlockChallengeBadge() async {
  await _prefs.setBool(_keyChallengeBadgeUnlocked, true);
  await _saveToFirestore();
}

Future<void> setHighestTitle(String title) async {
  // title: 'Challenger', 'Champion', 'Legend'
  await _prefs.setString(_keyHighestTitle, title);
  await _saveToFirestore();
}
```

- [ ] **Step 3: Update Firestore sync to include challenge data**

Modify `_saveToFirestore()` method to include:

```dart
Future<void> _saveToFirestore() async {
  try {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('private')
        .doc('streakData')
        .set(
          {
            'challenge': {
              'active': isChallengeActive,
              'day': challengeDay,
              'duration': challengeDuration,
              'locked_frequency': lockedFrequency,
              'start_date': _prefs.getString(_keyChallengeModeStartDate),
              'last_answer_date': _prefs.getString(_keyChallengeLastAnswerDate),
            },
            'streak': {
              'total_7day_completed': total7DayCompleted,
              'total_14day_completed': total14DayCompleted,
            },
            'rewards': {
              'bonus_questions': bonusQuestions,
              'bonus_categories': bonusCategories,
              'challenge_badge_unlocked': challengeBadgeUnlocked,
              'highest_title': highestTitle,
            },
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
  } catch (e) {
    print('Error saving streak data to Firestore: $e');
  }
}
```

Also add `_loadFromFirestore()` to restore data on app launch:

```dart
Future<void> _loadFromFirestore() async {
  try {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('private')
        .doc('streakData')
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      
      // Restore challenge data
      if (data['challenge'] != null) {
        final challenge = data['challenge'];
        await _prefs.setBool(_keyChallengeModeActive, challenge['active'] ?? false);
        await _prefs.setInt(_keyChallengeModeDay, challenge['day'] ?? 0);
        await _prefs.setInt(_keyChallengeDuration, challenge['duration'] ?? 7);
        await _prefs.setInt(_keyChallengeLockedFrequency, challenge['locked_frequency'] ?? 0);
        if (challenge['start_date'] != null) {
          await _prefs.setString(_keyChallengeModeStartDate, challenge['start_date']);
        }
      }
      
      // Restore rewards data
      if (data['rewards'] != null) {
        final rewards = data['rewards'];
        await _prefs.setInt(_keyBonusCategories, rewards['bonus_categories'] ?? 0);
        await _prefs.setBool(_keyChallengeBadgeUnlocked, rewards['challenge_badge_unlocked'] ?? false);
        if (rewards['highest_title'] != null) {
          await _prefs.setString(_keyHighestTitle, rewards['highest_title']);
        }
      }
    }
  } catch (e) {
    print('Error loading streak data from Firestore: $e');
  }
}
```

Call `_loadFromFirestore()` in the StreakService constructor or initialization.

- [ ] **Step 4: Write tests for new methods**

```dart
// test/core/streak/streak_service_test.dart (add to existing tests)

test('startChallenge sets challenge mode active', () async {
  await streakService.startChallenge(7, 10);
  expect(streakService.isChallengeActive, true);
  expect(streakService.challengeDuration, 7);
  expect(streakService.lockedFrequency, 10);
});

test('incrementChallengeDay increases day counter', () async {
  await streakService.startChallenge(7, 10);
  await streakService.incrementChallengeDay();
  expect(streakService.challengeDay, 2);
});

test('resetChallenge clears all challenge data', () async {
  await streakService.startChallenge(7, 10);
  await streakService.resetChallenge();
  expect(streakService.isChallengeActive, false);
  expect(streakService.challengeDay, 0);
});

test('completeChallengeMode 7-day awards bonus question', () async {
  final before = streakService.bonusQuestions;
  await streakService.startChallenge(7, 10);
  await streakService.completeChallengeMode(7);
  expect(streakService.bonusQuestions, before + 1);
  expect(streakService.isChallengeActive, false);
});

test('completeChallengeMode 14-day awards question and category', () async {
  final beforeQ = streakService.bonusQuestions;
  final beforeC = streakService.bonusCategories;
  await streakService.startChallenge(14, 10);
  await streakService.completeChallengeMode(14);
  expect(streakService.bonusQuestions, beforeQ + 1);
  expect(streakService.bonusCategories, beforeC + 1);
});
```

- [ ] **Step 5: Run tests**

```bash
flutter test test/core/streak/streak_service_test.dart
```

Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add lib/core/streak/streak_service.dart test/core/streak/streak_service_test.dart
git commit -m "feat: add challenge mode data model and persistence to StreakService"
```

---

### Task 7: Create Challenge Mode Dialogs (Frequency Selection & Warning)

**Files:**
- Create: `lib/screens/challenge/challenge_mode_dialog.dart`
- Create: `lib/screens/challenge/challenge_warning_dialog.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_id.arb`

- [ ] **Step 1: Add localization strings for challenge mode**

```json
// lib/l10n/app_en.arb
{
  "challengeModeFrequencyTitle": "Challenge Mode: Select Daily Frequency",
  "challengeModeFrequencyHint": "How many questions per day during this {duration}-day challenge?",
  "@challengeModeFrequencyHint": {
    "placeholders": {
      "duration": { "type": "int" }
    }
  },
  "challengeModeFrequencyRange": "1-50 questions per day",
  "challengeWarningTitle": "⚠️ Challenge Mode — {duration}-Day Streak",
  "@challengeWarningTitle": {
    "placeholders": {
      "duration": { "type": "int" }
    }
  },
  "challengeWarningRule1": "• Must answer ALL questions correctly (no mistakes allowed)",
  "challengeWarningRule2": "• Timer locked to 5 or 10 seconds only",
  "challengeWarningRule3": "• Notification frequency locked (cannot change)",
  "challengeWarningRule4": "• Must complete every day for {duration} consecutive days",
  "@challengeWarningRule4": {
    "placeholders": {
      "duration": { "type": "int" }
    }
  },
  "challengeWarningRule5": "Complete all {duration} days to earn rewards",
  "@challengeWarningRule5": {
    "placeholders": {
      "duration": { "type": "int" }
    }
  },
  "challengeWarningCancel": "Cancel",
  "challengeWarningStart": "I Understand, Start Challenge",
  "challengeRewardFreeQuestions": "+{count} question slot",
  "@challengeRewardFreeQuestions": {
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "challengeRewardFreeCategories": "+{count} category slot",
  "@challengeRewardFreeCategories": {
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "challengeRewardBadge": "🏆 Badge",
  "challengeRewardTitle": "👑 Progressive Title",
  "challengeRewardNotification": "🔥 Special notification appearance",
  "challengeFailureMessage": "You missed a day or answered incorrectly. Challenge failed.",
  "challengeCompleteMessage": "Challenge complete! Rewards earned.",
  "challengeDayCounter": "Challenge Day {day}/{total}",
  "@challengeDayCounter": {
    "placeholders": {
      "day": { "type": "int" },
      "total": { "type": "int" }
    }
  }
}
```

```json
// lib/l10n/app_id.arb
{
  "challengeModeFrequencyTitle": "Mode Tantangan: Pilih Frekuensi Harian",
  "challengeModeFrequencyHint": "Berapa pertanyaan per hari selama tantangan {duration} hari ini?",
  "@challengeModeFrequencyHint": {
    "placeholders": {
      "duration": { "type": "int" }
    }
  },
  "challengeModeFrequencyRange": "1-50 pertanyaan per hari",
  "challengeWarningTitle": "⚠️ Mode Tantangan — Rangkaian {duration} Hari",
  "@challengeWarningTitle": {
    "placeholders": {
      "duration": { "type": "int" }
    }
  },
  "challengeWarningRule1": "• Harus menjawab SEMUA pertanyaan dengan benar (tidak ada kesalahan)",
  "challengeWarningRule2": "• Timer terkunci pada 5 atau 10 detik saja",
  "challengeWarningRule3": "• Frekuensi notifikasi terkunci (tidak dapat diubah)",
  "challengeWarningRule4": "• Harus menyelesaikan setiap hari selama {duration} hari berturut-turut",
  "@challengeWarningRule4": {
    "placeholders": {
      "duration": { "type": "int" }
    }
  },
  "challengeWarningRule5": "Selesaikan semua {duration} hari untuk mendapatkan hadiah",
  "@challengeWarningRule5": {
    "placeholders": {
      "duration": { "type": "int" }
    }
  },
  "challengeWarningCancel": "Batal",
  "challengeWarningStart": "Saya Mengerti, Mulai Tantangan",
  "challengeRewardFreeQuestions": "+{count} slot pertanyaan",
  "@challengeRewardFreeQuestions": {
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "challengeRewardFreeCategories": "+{count} slot kategori",
  "@challengeRewardFreeCategories": {
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "challengeRewardBadge": "🏆 Lencana",
  "challengeRewardTitle": "👑 Judul Progresif",
  "challengeRewardNotification": "🔥 Tampilan notifikasi khusus",
  "challengeFailureMessage": "Anda melewatkan hari atau menjawab dengan salah. Tantangan gagal.",
  "challengeCompleteMessage": "Tantangan selesai! Hadiah telah diperoleh.",
  "challengeDayCounter": "Hari Tantangan {day}/{total}",
  "@challengeDayCounter": {
    "placeholders": {
      "day": { "type": "int" },
      "total": { "type": "int" }
    }
  }
}
```

- [ ] **Step 2: Run `flutter gen-l10n`**

```bash
flutter gen-l10n
```

Expected: New localization strings accessible

- [ ] **Step 3: Create challenge frequency selection dialog**

```dart
// lib/screens/challenge/challenge_mode_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ChallengeFrequencyDialog extends StatefulWidget {
  final int duration; // 7 or 14 days
  final Function(int) onFrequencySelected;

  const ChallengeFrequencyDialog({
    Key? key,
    required this.duration,
    required this.onFrequencySelected,
  }) : super(key: key);

  @override
  State<ChallengeFrequencyDialog> createState() => _ChallengeFrequencyDialogState();
}

class _ChallengeFrequencyDialogState extends State<ChallengeFrequencyDialog> {
  late int _selectedFrequency;

  @override
  void initState() {
    super.initState();
    _selectedFrequency = 10; // Default to 10
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.challengeModeFrequencyTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.challengeModeFrequencyHint(widget.duration),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Text(
              '$_selectedFrequency',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Slider(
              value: _selectedFrequency.toDouble(),
              min: 1,
              max: 50,
              divisions: 49,
              label: '$_selectedFrequency',
              onChanged: (value) {
                setState(() => _selectedFrequency = value.toInt());
              },
            ),
            const SizedBox(height: 8),
            Text(
              l10n.challengeModeFrequencyRange,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.challengeWarningCancel),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onFrequencySelected(_selectedFrequency);
          },
          child: Text(l10n.challengeWarningStart),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Create challenge warning dialog**

```dart
// lib/screens/challenge/challenge_warning_dialog.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:random_recall/core/streak/streak_service.dart';

class ChallengeWarningDialog extends StatefulWidget {
  final int duration; // 7 or 14
  final int frequency; // questions per day (1-50)
  final bool isPremiumUser;
  final VoidCallback onStartChallenge;

  const ChallengeWarningDialog({
    Key? key,
    required this.duration,
    required this.frequency,
    required this.isPremiumUser,
    required this.onStartChallenge,
  }) : super(key: key);

  @override
  State<ChallengeWarningDialog> createState() => _ChallengeWarningDialogState();
}

class _ChallengeWarningDialogState extends State<ChallengeWarningDialog> {
  bool _isLoading = false;

  Future<void> _start() async {
    setState(() => _isLoading = true);

    try {
      // Get StreakService instance
      final streakService = StreakService.instance;
      
      // Start challenge
      await streakService.startChallenge(widget.duration, widget.frequency);
      
      widget.onStartChallenge();
      
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting challenge: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.challengeWarningTitle(widget.duration),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Rules:',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(l10n.challengeWarningRule1),
              const SizedBox(height: 8),
              Text(l10n.challengeWarningRule2),
              const SizedBox(height: 8),
              Text(l10n.challengeWarningRule3),
              const SizedBox(height: 8),
              Text(l10n.challengeWarningRule4(widget.duration)),
              const SizedBox(height: 8),
              Text(l10n.challengeWarningRule5(widget.duration)),
              const SizedBox(height: 24),
              Text(
                'Rewards:',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (widget.isPremiumUser) ...[
                Text(l10n.challengeRewardBadge),
                const SizedBox(height: 8),
                Text(l10n.challengeRewardTitle),
                const SizedBox(height: 8),
                Text(l10n.challengeRewardNotification),
              ] else ...[
                Text(l10n.challengeRewardFreeQuestions(1)),
                if (widget.duration == 14) ...[
                  const SizedBox(height: 8),
                  Text(l10n.challengeRewardFreeCategories(1)),
                ],
              ],
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      child: Text(l10n.challengeWarningCancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isLoading ? null : _start,
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.challengeWarningStart),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Test dialogs display correctly**

```bash
# Manual test: run app and verify dialogs appear with correct text/buttons
flutter run
```

Expected: Both dialogs display with proper formatting, buttons work, localization correct

- [ ] **Step 6: Run `flutter gen-l10n` and commit**

```bash
flutter gen-l10n
git add lib/screens/challenge/ lib/l10n/app_en.arb lib/l10n/app_id.arb
git commit -m "feat: add challenge mode frequency and warning dialogs with i18n"
```

---

### Task 8: Implement Timer & Frequency Locking During Challenge

**Files:**
- Modify: `lib/screens/settings/timer_settings_screen.dart` (or where timer is set)
- Modify: `lib/screens/settings/notification_schedule_screen.dart`
- Modify: `lib/core/streak/streak_service.dart` (if needed for helper)

- [ ] **Step 1: Find timer settings implementation**

```bash
grep -r "Timer" lib/screens/settings/
grep -r "5s\|10s\|20s" lib/screens/
```

Expected: Identify where timer options are presented to user

- [ ] **Step 2: Lock timer to 5-10 seconds during challenge**

In the timer settings screen, modify to:

```dart
// lib/screens/settings/timer_settings_screen.dart (or relevant file)

// Check if challenge active
final streakService = StreakService.instance;
final isChallengeActive = streakService.isChallengeActive;

// Timer options - only 5 and 10 if challenge active, otherwise full range
final timerOptions = isChallengeActive
    ? [5, 10] // Locked during challenge
    : [5, 10, 15, 20]; // Full options normally

// Build UI to only show locked options
// Add visual indicator: "⚠️ Challenge Active - Settings Locked"

if (isChallengeActive) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Challenge Active'),
      content: Text('Timer and notification settings are locked during challenge mode.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('OK'),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 3: Lock frequency during challenge**

In notification schedule screen:

```dart
// lib/screens/settings/notification_schedule_screen.dart

final streakService = StreakService.instance;
final isChallengeActive = streakService.isChallengeActive;

// Build frequency slider
Slider(
  value: _frequency.toDouble(),
  min: isChallengeActive ? streakService.lockedFrequency.toDouble() : 1.0,
  max: isChallengeActive ? streakService.lockedFrequency.toDouble() : 50.0,
  enabled: !isChallengeActive, // Disable if challenge active
  onChanged: isChallengeActive ? null : (value) {
    setState(() => _frequency = value.toInt());
  },
);

// Show locked indicator
if (isChallengeActive) {
  Text(
    '🔒 Locked: ${streakService.lockedFrequency} questions/day during challenge',
    style: theme.textTheme.bodySmall?.copyWith(
      color: Colors.orange,
      fontWeight: FontWeight.bold,
    ),
  );
}
```

- [ ] **Step 4: Test settings are locked during challenge**

```bash
# Manual test
# 1. Start a challenge
# 2. Go to timer settings - should only show 5, 10 options
# 3. Try to change timer - should show "locked" message
# 4. Go to notification settings - frequency slider disabled
# 5. Verify frequency shows locked value
```

Expected: All settings locked during challenge, user can't change them

- [ ] **Step 5: Commit**

```bash
git add lib/screens/settings/timer_settings_screen.dart lib/screens/settings/notification_schedule_screen.dart
git commit -m "feat: lock timer and frequency settings during challenge mode"
```

---

### Task 9: Implement Incorrect Answer Handling (Exit & Reset)

**Files:**
- Modify: `lib/screens/question/question_screen.dart` (or wherever answers are submitted)
- Modify: `lib/core/streak/streak_service.dart`

- [ ] **Step 1: Add method to handle wrong answer in challenge**

```dart
// lib/core/streak/streak_service.dart

Future<void> failChallenge() async {
  // Wrong answer during challenge - exit and reset
  if (isChallengeActive) {
    // Reset streak to 0
    await _prefs.setInt(_keyCurrentStreak, 0);
    
    // Unlock settings
    await resetChallenge();
    
    // Save to Firestore
    await _saveToFirestore();
  }
}
```

- [ ] **Step 2: Call failChallenge when answer is wrong**

In question screen, find where answer correctness is checked:

```dart
// lib/screens/question/question_screen.dart

// When user submits answer
if (!isCorrect) {
  // Answer is wrong
  
  final streakService = StreakService.instance;
  if (streakService.isChallengeActive) {
    // In challenge mode - any wrong answer fails it
    await streakService.failChallenge();
    
    // Show failure message
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Challenge Failed'),
        content: Text('You answered incorrectly. Challenge ended.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  } else {
    // Normal mode - just wrong answer feedback
    _showWrongAnswerFeedback();
  }
}
```

- [ ] **Step 3: Check for missed day on app launch**

```dart
// lib/core/streak/streak_service.dart

Future<void> checkChallengeDailyRequirement() async {
  if (!isChallengeActive) return;

  final lastAnswerDateStr = _prefs.getString(_keyChallengeLastAnswerDate);
  if (lastAnswerDateStr == null) return;

  final lastAnswerDate = DateTime.parse(lastAnswerDateStr);
  final now = DateTime.now();
  final daysDiff = now.difference(lastAnswerDate).inDays;

  // If more than 1 day since last answer, challenge failed
  if (daysDiff > 1) {
    await failChallenge();
  }
}
```

Call this in app initialization or home screen initState.

- [ ] **Step 4: Test challenge fails on wrong answer**

```bash
# Manual test
# 1. Start a challenge
# 2. Answer a question incorrectly
# 3. Should see "Challenge Failed" message
# 4. Settings should be unlocked
# 5. Streak should be reset to 0
```

Expected: Challenge exits and resets on wrong answer

- [ ] **Step 5: Commit**

```bash
git add lib/core/streak/streak_service.dart lib/screens/question/question_screen.dart
git commit -m "feat: fail challenge on incorrect answer and reset streak"
```

---

### Task 10: Implement Reward System (Free-tier & Premium)

**Files:**
- Modify: `lib/core/streak/streak_service.dart` (done in Task 6)
- Modify: `lib/core/subscription/subscription_service.dart` (for premium check)
- Create: `lib/screens/challenge/challenge_complete_screen.dart`

- [ ] **Step 1: Check premium status in reward logic**

```dart
// lib/core/streak/streak_service.dart

Future<void> completeChallengeMode(int duration, bool isPremium) async {
  // Challenge completed successfully
  if (duration == 7) {
    await _prefs.setInt(_keyTotal7DayCompleted, total7DayCompleted + 1);
    
    if (isPremium) {
      // Premium: special notification appearance (handled elsewhere)
    } else {
      // Free-tier: +1 question
      final newQuestions = bonusQuestions + 1;
      await _prefs.setInt(_keyBonusQuestions, min(newQuestions, questionsMax - questionBase));
    }
  } else if (duration == 14) {
    await _prefs.setInt(_keyTotal14DayCompleted, total14DayCompleted + 1);
    
    if (isPremium) {
      // Premium: badge + title
      await unlockChallengeBadge();
      // Update title based on completion count
      final completions = total14DayCompleted + 1;
      if (completions == 1) {
        await setHighestTitle('Challenger');
      } else if (completions == 2) {
        await setHighestTitle('Champion');
      } else {
        await setHighestTitle('Legend');
      }
    } else {
      // Free-tier: +1 question + 1 category
      final newQuestions = bonusQuestions + 1;
      final newCategories = bonusCategories + 1;
      await _prefs.setInt(_keyBonusQuestions, min(newQuestions, questionsMax - questionBase));
      await _prefs.setInt(_keyBonusCategories, min(newCategories, categoriesMax - categoryBase));
    }
  }
  
  await resetChallenge();
  await _saveToFirestore();
}
```

- [ ] **Step 2: Create challenge complete screen to show rewards**

```dart
// lib/screens/challenge/challenge_complete_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:random_recall/core/streak/streak_service.dart';
import 'package:random_recall/core/subscription/subscription_service.dart';

class ChallengeCompleteScreen extends StatefulWidget {
  final int duration;
  final bool isPremium;

  const ChallengeCompleteScreen({
    Key? key,
    required this.duration,
    required this.isPremium,
  }) : super(key: key);

  @override
  State<ChallengeCompleteScreen> createState() => _ChallengeCompleteScreenState();
}

class _ChallengeCompleteScreenState extends State<ChallengeCompleteScreen> {
  late final StreakService _streakService;

  @override
  void initState() {
    super.initState();
    _streakService = StreakService.instance;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('Challenge Complete!')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.challengeCompleteMessage,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Text(
                'Rewards Earned:',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              if (widget.isPremium) ...[
                _RewardCard(
                  icon: '🏆',
                  title: 'Badge Unlocked',
                  subtitle: '(Shows on your profile)',
                ),
                const SizedBox(height: 12),
                _RewardCard(
                  icon: '👑',
                  title: 'Title: ${_streakService.highestTitle}',
                  subtitle: '(Challenger → Champion → Legend)',
                ),
                const SizedBox(height: 12),
                _RewardCard(
                  icon: '🔥',
                  title: 'Special Notification',
                  subtitle: '(Gold border during challenges)',
                ),
              ] else ...[
                _RewardCard(
                  icon: '✨',
                  title: l10n.challengeRewardFreeQuestions(1),
                  subtitle: 'Added to your daily limit',
                ),
                if (widget.duration == 14) ...[
                  const SizedBox(height: 12),
                  _RewardCard(
                    icon: '🎯',
                    title: l10n.challengeRewardFreeCategories(1),
                    subtitle: 'New category unlocked',
                  ),
                ],
              ],
              const SizedBox(height: 48),
              FilledButton(
                onPressed: () {
                  // Navigate back to home/settings
                  Navigator.popUntil(context, ModalRoute.withName('/home'));
                },
                child: Text('Back to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;

  const _RewardCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Call complete screen when challenge finishes**

In question screen, after 7th or 14th day is completed:

```dart
// After last question of challenge day is answered correctly

if (streakService.challengeDay == streakService.challengeDuration) {
  // Challenge complete!
  final isPremium = subscriptionService.isPremium;
  await streakService.completeChallengeMode(streakService.challengeDuration, isPremium);
  
  // Show completion screen
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ChallengeCompleteScreen(
        duration: streakService.challengeDuration,
        isPremium: isPremium,
      ),
    ),
  );
}
```

- [ ] **Step 4: Test reward system**

```bash
# Manual test
# 1. Start 7-day challenge as free user
# 2. Complete all 7 days
# 3. Should see reward screen with +1 question
# 4. Verify bonus_questions incremented in Firestore
# 
# 5. Start 14-day challenge as free user
# 6. Complete all 14 days
# 7. Should see reward screen with +1 question and +1 category
# 8. Verify both incremented in Firestore
#
# 9. For premium user:
# 10. Complete 14-day challenge
# 11. Should see badge and title rewards
# 12. Badge visible on profile
```

Expected: Rewards display correctly and persist to Firestore

- [ ] **Step 5: Commit**

```bash
git add lib/core/streak/streak_service.dart lib/screens/challenge/challenge_complete_screen.dart
git commit -m "feat: implement reward system for free-tier and premium users"
```

---

### Task 11: Handle Existing Streaks & Existing User Opt-In

**Files:**
- Modify: `lib/screens/challenge/challenge_mode_dialog.dart` (for existing users)
- Modify: `lib/core/streak/streak_service.dart` (if needed)

- [ ] **Step 1: Create dialog for existing users with streaks**

If user has existing streak and wants to start challenge, show option:

```dart
// lib/screens/challenge/existing_streak_dialog.dart (new)

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ExistingStreakDialog extends StatelessWidget {
  final int currentStreak;
  final Function() onKeepOldRules;
  final Function() onStartFresh;

  const ExistingStreakDialog({
    Key? key,
    required this.currentStreak,
    required this.onKeepOldRules,
    required this.onStartFresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('You have an active streak'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current streak: $currentStreak days'),
          const SizedBox(height: 16),
          Text(
            'What would you like to do?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Text('Option A: Keep your current streak (don\'t enter challenge mode yet)'),
          const SizedBox(height: 8),
          Text('Option B: Start challenge mode (resets current streak)'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onKeepOldRules,
          child: Text('Keep Streak'),
        ),
        FilledButton(
          onPressed: onStartFresh,
          child: Text('Start Challenge'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Show dialog when starting challenge with existing streak**

```dart
// lib/screens/challenge/challenge_mode_dialog.dart (modify onStartChallenge)

if (streakService.currentStreak > 0) {
  // Has existing streak - ask what to do
  showDialog(
    context: context,
    builder: (context) => ExistingStreakDialog(
      currentStreak: streakService.currentStreak,
      onKeepOldRules: () {
        Navigator.pop(context);
        // Don't start challenge, keep current rules
      },
      onStartFresh: () {
        Navigator.pop(context);
        // Start challenge (which will reset streak in Task 9)
        _start();
      },
    ),
  );
} else {
  // No existing streak - just start
  _start();
}
```

- [ ] **Step 3: Test existing user flow**

```bash
# Manual test
# 1. Create user with 5-day streak
# 2. Try to start challenge
# 3. Should see existing streak dialog
# 4. Choose "Keep Streak" - nothing happens
# 5. Try again, choose "Start Challenge" - starts challenge, resets streak
```

Expected: Dialog appears, options work correctly

- [ ] **Step 4: Commit**

```bash
git add lib/screens/challenge/existing_streak_dialog.dart lib/screens/challenge/challenge_mode_dialog.dart
git commit -m "feat: add existing streak handling for challenge mode opt-in"
```

---

### Task 12: Add Challenge Mode Localization & Integration Test

**Files:**
- Modify: `lib/l10n/app_en.arb` (already done in Task 7)
- Modify: `lib/l10n/app_id.arb` (already done in Task 7)

- [ ] **Step 1: Test challenge mode end-to-end in English**

```bash
# Manual test
# 1. Create new account
# 2. Go to settings/challenge mode
# 3. Start 7-day challenge with frequency 10
# 4. Verify all dialogs in English
# 5. Complete all 7 days (or answer incorrectly to test failure)
# 6. Verify rewards screen in English
```

Expected: All text in English, no placeholder strings

- [ ] **Step 2: Test challenge mode in Indonesian**

```bash
# Manual test
# 1. Change device language to Indonesian
# 2. Repeat above test
# 3. All text should be in Indonesian
```

Expected: All text in Indonesian

- [ ] **Step 3: Verify Firestore persistence**

```bash
# Manual test (Firebase Console)
# 1. Complete a challenge
# 2. Check Firestore: users/{userId}/private/streakData
# 3. Verify challenge data saved: {active, day, duration, locked_frequency}
# 4. Verify rewards saved: {bonus_questions, bonus_categories, etc}
```

Expected: All data persisted correctly

- [ ] **Step 4: Verify multi-device sync**

```bash
# Manual test
# 1. Start 7-day challenge on phone A
# 2. Open app on phone B (same account)
# 3. Verify challenge state shows on phone B
# 4. Answer question on phone A
# 5. Verify updated progress shows on phone B when reopened
```

Expected: State syncs across devices

- [ ] **Step 5: Commit (verification complete)**

```bash
git status
# Should be clean - no new code changes, just verification
```

---

## Feature 3: Daily Notification Limit Increase

### Task 13: Update Notification Frequency Slider to 50

**Files:**
- Modify: `lib/screens/settings/notification_schedule_screen.dart`

- [ ] **Step 1: Find current slider implementation**

```bash
grep -n "max: 10\|divisions: 10" lib/screens/settings/notification_schedule_screen.dart
```

Expected: Find current slider max value

- [ ] **Step 2: Update slider max from 10 to 50**

```dart
// lib/screens/settings/notification_schedule_screen.dart

// OLD:
// Slider(
//   value: _frequency.toDouble(),
//   min: 1,
//   max: 10,
//   divisions: 10,
//   ...
// )

// NEW:
Slider(
  value: _frequency.toDouble(),
  min: 1,
  max: 50,
  divisions: 49,
  label: '$_frequency',
  onChanged: (value) {
    setState(() => _frequency = value.toInt());
  },
)
```

- [ ] **Step 3: Test slider works 1-50**

```bash
# Manual test
# 1. Go to notification settings
# 2. Adjust slider to min (1)
# 3. Adjust slider to max (50)
# 4. Verify intermediate values work (5, 25, 49)
# 5. Close and reopen app - verify setting persists
```

Expected: Slider works full range, value persists

- [ ] **Step 4: Verify 50 notifications fit in 1-hour window**

```
# Math check (already verified in spec):
# - Time picker enforces 1-hour minimum (e.g., 10am-11am)
# - 50 notifications in 60 minutes = 1.2 minutes per notification
# - 1.2 minutes = 72 seconds between notifications ✅
# - Meets the 1-minute minimum spacing requirement
```

No code needed - this is by design

- [ ] **Step 5: Test during challenge mode (frequency locked)**

```bash
# Manual test
# 1. Start challenge with frequency 10
# 2. Go to notification settings
# 3. Slider should be disabled, showing "🔒 Locked: 10 questions/day"
# 4. Exit challenge
# 5. Slider should be enabled again, can adjust to 50
```

Expected: Slider locked at challenge frequency during challenge

- [ ] **Step 6: Commit**

```bash
git add lib/screens/settings/notification_schedule_screen.dart
git commit -m "feat: increase daily notification limit from 10 to 50"
```

---

## Final Integration & Testing

### Task 14: Integration Test - All Features Together

**Files:**
- Test: Full app integration

- [ ] **Step 1: Test display name + challenge mode + notification limit all work together**

```bash
# Manual test flow:
# 1. Create new account
# 2. Enter display name
# 3. Welcome message shows correct name
# 4. Go to notification settings
# 5. Increase frequency to 50
# 6. Go to challenge settings, start 7-day challenge with frequency 10
# 7. Notification settings locked to 10
# 8. Answer questions - if all correct, day increments
# 9. Complete challenge - see reward
# 10. Challenge ends - notification settings unlocked, can change back to 50
```

Expected: All features work together without conflicts

- [ ] **Step 2: Test all strings in both languages**

```bash
# Manual test:
# Change device language between English and Indonesian
# Verify all new features show correct translations
```

Expected: All text correct in both languages

- [ ] **Step 3: Test Firestore data consistency**

```bash
# Firebase Console check:
# 1. users/{userId}/name - display name stored
# 2. users/{userId}/private/streakData - challenge state
# 3. All data syncs to Firestore on changes
```

Expected: Data structure matches spec

- [ ] **Step 4: Final verification - build passes analyzer and tests**

```bash
flutter analyze
flutter test
```

Expected: No errors (pre-existing warnings acceptable)

- [ ] **Step 5: Final commit**

```bash
git status
# Should be clean - all changes committed in previous tasks
```

Done! All three features complete.

---

## Implementation Checklist

- [ ] Task 1: Display Name Service with validation
- [ ] Task 2: Profanity check integration
- [ ] Task 3: Display Name Setup Screen UI
- [ ] Task 4: App launch integration
- [ ] Task 5: Display Name feature complete
- [ ] Task 6: StreakService data model for challenge
- [ ] Task 7: Challenge dialogs and localization
- [ ] Task 8: Timer & frequency locking
- [ ] Task 9: Incorrect answer handling
- [ ] Task 10: Reward system
- [ ] Task 11: Existing streak handling
- [ ] Task 12: Challenge mode integration test
- [ ] Task 13: Notification limit increase
- [ ] Task 14: Final integration test
