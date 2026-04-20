# Single Active Device Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace multi-device real-time sync with single active device model. Eliminate data loss bugs and simplify codebase.

**Architecture:** Generate unique device ID on first install, track active device in Firestore `last_active_device_id`, remove all real-time listeners, remove destructive reconciliation from backup, simplify login flow.

**Tech Stack:** Flutter, Firebase Auth, Cloud Firestore, SharedPreferences, SQLite

---

## Files Summary

**Create:**
- None (all changes are modifications or deletions)

**Modify:**
- `lib/main.dart` — add device ID generation, simplify `_HomeGate._initFlow()`, add device check
- `lib/core/sync/sync_service.dart` — remove listeners, remove reconciliation, add device ID write
- `lib/core/auth/auth_service.dart` — no changes (restore already called correctly)

**Delete:**
- Remove `SyncService.startRealtimeSync()` method entirely
- Remove `SyncService._applyRemoteChanges()` method entirely
- Remove `SyncService._subscriptions` list and `stopRealtimeSync()` method

---

## Task 1: Add Device ID Generation to main.dart

**Files:**
- Modify: `lib/main.dart` (around line 1, add import + function; modify main())

**Objective:** Generate and store a unique device ID on first app run.

- [ ] **Step 1: Add UUID dependency check**

Verify that `uuid` package is in pubspec.yaml. Run:
```bash
grep "uuid:" pubspec.yaml
```

Expected output: `uuid: ^4.0.0` (or similar version)

If not present, the user should add it. For now, assume it's there.

- [ ] **Step 2: Add import for UUID generation**

At the top of `lib/main.dart`, add:
```dart
import 'package:uuid/uuid.dart';
```

- [ ] **Step 3: Create helper function to initialize or retrieve device ID**

After the imports section in `lib/main.dart`, before the `main()` function (around line 30), add:

```dart
/// Initialize or retrieve the device ID. Called once on app startup.
Future<String> _getOrCreateDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  var deviceId = prefs.getString('device_id');
  
  if (deviceId == null) {
    // First run: generate and store
    deviceId = const Uuid().v4();
    await prefs.setString('device_id', deviceId);
    debugPrint('Main: Generated new device ID: $deviceId');
  }
  
  return deviceId;
}
```

- [ ] **Step 4: Call device ID init in main() function**

In `main()` function (around line 50), add a call to initialize device ID before Firebase:

Find the line that says `WidgetsFlutterBinding.ensureInitialized();` and add after it:

```dart
  WidgetsFlutterBinding.ensureInitialized();
  await _getOrCreateDeviceId(); // Initialize device ID before Firebase
  await Firebase.initializeApp(
```

- [ ] **Step 5: Verify no syntax errors**

Run:
```bash
cd /Users/lilianyoctoria/Documents/random_recall
flutter analyze lib/main.dart
```

Expected: No errors related to device ID code.

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart
git commit -m "feat: add device ID generation on first install"
```

---

## Task 2: Remove Real-Time Listeners from SyncService

**Files:**
- Modify: `lib/core/sync/sync_service.dart` (lines 28, 47-120, 123-130)

**Objective:** Delete `startRealtimeSync()`, `stopRealtimeSync()`, and `_subscriptions` list since we no longer support real-time sync.

- [ ] **Step 1: Delete the _subscriptions list**

In `lib/core/sync/sync_service.dart`, find line 28:
```dart
  final List<StreamSubscription> _subscriptions = [];
```

Delete this entire line.

- [ ] **Step 2: Delete stopRealtimeSync() method**

Find the `stopRealtimeSync()` method (lines 123–130). Delete the entire method:

```dart
  /// Stops all active Firestore listeners.
  void stopRealtimeSync() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    debugPrint('SyncService: Real-time listeners stopped.');
  }
```

- [ ] **Step 3: Delete startRealtimeSync() method**

Find the `startRealtimeSync()` method (lines 47–120). Delete the entire method (includes the comment "Starts listening to Firestore collections..." all the way through the closing brace).

- [ ] **Step 4: Verify file structure**

The file should now skip from line 44 (`_setupAutoSync()`) directly to `_applyRemoteChanges()` (now orphaned, but we'll delete it in the next task).

Check syntax:
```bash
flutter analyze lib/core/sync/sync_service.dart
```

Expected: May see `_applyRemoteChanges` as unused (that's OK, we delete it next).

- [ ] **Step 5: Commit**

```bash
git add lib/core/sync/sync_service.dart
git commit -m "feat: remove real-time Firestore listeners and stopRealtimeSync() method"
```

---

## Task 3: Remove _applyRemoteChanges() from SyncService

**Files:**
- Modify: `lib/core/sync/sync_service.dart` (lines 132–192)

**Objective:** Delete the `_applyRemoteChanges()` method since it's no longer needed without snapshot listeners.

- [ ] **Step 1: Delete _applyRemoteChanges() method**

Find the method (lines 132–192). Delete the entire method:

```dart
  /// Helper to process Firestore snapshots and merge them into SQLite
  Future<void> _applyRemoteChanges<T>(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    String tableName,
    T Function(Map<String, dynamic>) fromMap,
  ) async {
    // ... entire implementation ...
  }
```

Delete from the `///` comment all the way to the closing `}`.

- [ ] **Step 2: Verify syntax**

```bash
flutter analyze lib/core/sync/sync_service.dart
```

Expected: No errors or unused method warnings for `_applyRemoteChanges`.

- [ ] **Step 3: Commit**

```bash
git add lib/core/sync/sync_service.dart
git commit -m "feat: remove _applyRemoteChanges() method (no longer needed without listeners)"
```

---

## Task 4: Update performBackup() to Remove Reconciliation and Add Device ID

**Files:**
- Modify: `lib/core/sync/sync_service.dart:performBackup()` (lines 198–297)

**Objective:** Remove the destructive reconciliation logic (lines 238–253) and add device ID write to the user document.

- [ ] **Step 1: Remove destructive reconciliation block**

In `performBackup()`, find the comment `// 3b. Reconcile: delete Firestore documents...` (around line 235) and the code block that follows it (lines 238–253):

```dart
      // 3b. Reconcile: delete Firestore documents that no longer exist locally.
      // Without this step, deleted questions/categories persist in Firestore and
      // get re-inserted into SQLite by the real-time listener or performRestore.
      final localQIds = questions
          .where((q) => q.id != null)
          .map((q) => q.id!.toString())
          .toSet();
      final localCatIds = categories
          .where((c) => c.id != null)
          .map((c) => c.id!.toString())
          .toSet();
      final remoteQSnap = await userDoc.collection('questions').get();
      final remoteCatSnap = await userDoc.collection('categories').get();
      for (final doc in remoteQSnap.docs) {
        if (!localQIds.contains(doc.id)) batch.delete(doc.reference);
      }
      for (final doc in remoteCatSnap.docs) {
        if (!localCatIds.contains(doc.id)) batch.delete(doc.reference);
      }
```

Delete this entire block (16 lines total).

- [ ] **Step 2: Add device ID write before batch.commit()**

After deleting the reconciliation block, find the line `await batch.commit();` (should now be around line 276). Just before this line, add:

```dart
      // Record which device performed this backup
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id') ?? 'unknown';
```

And then after the batch.set() calls (still before batch.commit()), add:

```dart
      // Update user doc with device tracking
      batch.set(
        userDoc,
        {'last_active_device_id': deviceId},
        SetOptions(merge: true),
      );
```

So the sequence in `performBackup()` should be:
1. Backup categories
2. Backup questions
3. Backup scores
4. (reconciliation block — DELETE THIS)
5. (new device ID write — ADD THIS)
6. batch.commit()

- [ ] **Step 3: Show complete updated section**

After these changes, the section from line 226 onwards should look like:

```dart
      // 3. Backup Score Records
      final scores = await _dbHelper.getAllScoreRecords();
      for (final s in scores) {
        if (s.id == null) continue;
        final docRef = userDoc.collection('score_records').doc(s.id.toString());
        batch.set(docRef, s.toMap(), SetOptions(merge: true));
      }

      // Record which device performed this backup
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id') ?? 'unknown';

      // Update user doc with device tracking
      batch.set(
        userDoc,
        {'last_active_device_id': deviceId},
        SetOptions(merge: true),
      );

      // 4. Commit all changes at once
      await batch.commit();
```

- [ ] **Step 4: Verify syntax**

```bash
flutter analyze lib/core/sync/sync_service.dart
```

Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/core/sync/sync_service.dart
git commit -m "feat: remove destructive reconciliation from performBackup(), add device ID tracking"
```

---

## Task 5: Simplify _HomeGate._initFlow() and Remove startRealtimeSync Call

**Files:**
- Modify: `lib/main.dart:_HomeGateState._initFlow()` (lines 379–399)

**Objective:** Remove the `while (isSyncing)` loop and the `startRealtimeSync()` call. Simplify to just check `onboarding_complete`.

- [ ] **Step 1: Find _initFlow() method**

In `lib/main.dart`, find the `_initFlow()` method in the `_HomeGateState` class (around line 379).

- [ ] **Step 2: Replace entire _initFlow() method**

Delete the current implementation and replace it with:

```dart
  Future<void> _initFlow() async {
    final prefs = await SharedPreferences.getInstance();
    bool complete = prefs.getBool('onboarding_complete') ?? false;

    if (!complete) {
      // No cloud data fetched yet. Restore will happen after login in initializeUserSession()
      // This path only happens if user somehow has cleardata without logging out first.
      // Just show onboarding.
      debugPrint('HomeGate: onboarding_complete not set, showing onboarding');
    } else {
      // Check if another device has logged in since this device was last active
      await _checkActiveDevice();
    }

    if (mounted) {
      setState(() {
        _onboardingComplete = complete;
        _isChecking = false;
      });
    }
  }
```

- [ ] **Step 3: Remove the startRealtimeSync() call**

After the `setState()` in `_initFlow()`, find any line that says `SyncService.instance.startRealtimeSync();` and delete it if present.

Actually, check the current code first:
```bash
grep -n "startRealtimeSync" lib/main.dart
```

If it exists, delete that line.

- [ ] **Step 4: Verify syntax**

```bash
flutter analyze lib/main.dart
```

Expected: May see `_checkActiveDevice` as undefined (we add it in next task). That's OK for now.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "feat: simplify _HomeGate._initFlow(), remove startRealtimeSync() call and isSyncing wait"
```

---

## Task 6: Add _checkActiveDevice() Method to _HomeGate

**Files:**
- Modify: `lib/main.dart:_HomeGateState` (add new method)

**Objective:** Add the active device check method that detects if another device has logged in and silently logs out.

- [ ] **Step 1: Add _checkActiveDevice() method to _HomeGateState class**

In `lib/main.dart`, in the `_HomeGateState` class (after the `_initFlow()` method), add:

```dart
  /// Check if this device is still the active device.
  /// If another device has logged in, silently log out.
  Future<void> _checkActiveDevice() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final localDeviceId = prefs.getString('device_id');

      if (localDeviceId == null) {
        // Device ID wasn't generated yet (shouldn't happen, but be safe)
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return;

      final remoteDeviceId = userDoc['last_active_device_id'] as String?;

      if (remoteDeviceId != null && remoteDeviceId != localDeviceId) {
        // Another device is now active. Silent logout.
        debugPrint('HomeGate: Another device logged in. Signing out.');
        if (mounted) {
          await AuthService.instance.signOut();
        }
      }
    } catch (e) {
      debugPrint('HomeGate: Error checking active device: $e');
      // Don't fail the init flow if the check errors
    }
  }
```

- [ ] **Step 2: Add FirebaseFirestore import if missing**

At the top of `lib/main.dart`, verify that these imports exist:
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
```

If missing, add it.

- [ ] **Step 3: Verify syntax**

```bash
flutter analyze lib/main.dart
```

Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: add _checkActiveDevice() method to detect silent logout"
```

---

## Task 7: Remove startRealtimeSync Call from AuthService

**Files:**
- Modify: `lib/core/auth/auth_service.dart` (check for startRealtimeSync calls)

**Objective:** Ensure AuthService doesn't call `startRealtimeSync()` anywhere.

- [ ] **Step 1: Search for startRealtimeSync calls**

```bash
grep -n "startRealtimeSync" lib/core/auth/auth_service.dart
```

Expected: Should be no matches. If there are any, delete them.

- [ ] **Step 2: If any found, delete them**

If the grep found lines, delete them. Usually there would be none since `startRealtimeSync()` was called from `main.dart`.

- [ ] **Step 3: Verify no other files call it**

```bash
grep -r "startRealtimeSync" lib/
```

Expected: Only `sync_service.dart` (the definition, which is deleted in Task 2) and no calls elsewhere.

If other calls exist, delete them.

- [ ] **Step 4: Commit (if changes made)**

```bash
git add lib/core/auth/auth_service.dart
git commit -m "chore: remove any startRealtimeSync() calls from AuthService"
```

If no changes were needed, skip this commit.

---

## Task 8: Remove stopRealtimeSync Call from AuthService signOut

**Files:**
- Modify: `lib/core/auth/auth_service.dart:signOut()` (line 172)

**Objective:** Remove the `SyncService.instance.stopRealtimeSync()` call since we no longer have real-time listeners.

- [ ] **Step 1: Find stopRealtimeSync call in signOut()**

In `lib/core/auth/auth_service.dart`, find the `signOut()` method (around line 155) and look for:
```dart
      SyncService.instance.stopRealtimeSync();
```

- [ ] **Step 2: Delete the stopRealtimeSync() call**

Delete the line `SyncService.instance.stopRealtimeSync();` entirely.

The `signOut()` method should still have:
- Final backup call
- Google sign out
- Database clear
- Preferences clear
- Analytics
- Firebase signOut

But no `stopRealtimeSync()`.

- [ ] **Step 3: Verify syntax**

```bash
flutter analyze lib/core/auth/auth_service.dart
```

Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/core/auth/auth_service.dart
git commit -m "feat: remove stopRealtimeSync() call from signOut()"
```

---

## Task 9: Run All Tests

**Files:**
- Test: `test/models_test.dart`

**Objective:** Ensure no tests break from these changes.

- [ ] **Step 1: Run all unit tests**

```bash
cd /Users/lilianyoctoria/Documents/random_recall
flutter test
```

Expected: All tests pass (55 total from previous summary).

If tests fail, debug and fix before proceeding.

- [ ] **Step 2: Check for any Dart analyze errors**

```bash
flutter analyze lib/ --no-fatal-warnings
```

Expected: No errors (warnings are OK for now).

- [ ] **Step 3: Commit if all passing**

If tests pass, no new commit needed (no code changed in this step). If you fixed anything:

```bash
git add .
git commit -m "test: verify all tests pass after sync refactor"
```

---

## Task 10: Manual Testing Plan (Instructions for User)

**Objective:** Verify the single-device sync works end-to-end on real devices.

This task is instructions only — not executed by the implementing agent. User performs these.

- [ ] **Step 1: Build debug APK**

```bash
flutter build apk --debug
```

- [ ] **Step 2: Test on Device A (phone/emulator 1)**

- Install APK
- Login with email
- Create 3 questions in 2 categories
- Go home and verify questions appear
- Force close the app
- Reopen → should show home screen (not onboarding)

- [ ] **Step 3: Test on Device B (phone/emulator 2)**

- Install APK on Device B
- Login with same email as Device A
- Verify data from Device A is restored (3 questions)
- Create 1 new question on Device B
- Close app

- [ ] **Step 4: Return to Device A and verify silent logout**

- Reopen the app on Device A
- Should see login screen (silent logout because Device B is now active)
- Login again
- Should see all 4 questions (3 from before + 1 created on Device B)

- [ ] **Step 5: Verify backup on local DB changes**

- On Device A, create 1 new question
- Kill and restart app → question should still be there
- Device ID should be same as before (verify in SharedPreferences if possible)

- [ ] **Step 6: Verify Settings Dont Sync in Real-Time**

- On Device A, change notification frequency to 5 (from 3)
- On Device B, settings should NOT update immediately
- On Device B, close and reopen app
- Settings should still be old (3), because Device B is already logged in elsewhere
- Actually: Device A is now active, so Device B will be logged out next time opened

---

## Task 11: Update CHANGELOG (Documentation)

**Files:**
- Modify: Root `CHANGELOG.md` or create entry

**Objective:** Document this breaking change.

- [ ] **Step 1: Check if CHANGELOG.md exists**

```bash
ls -la /Users/lilianyoctoria/Documents/random_recall/CHANGELOG.md
```

If it doesn't exist, create it:

```bash
touch /Users/lilianyoctoria/Documents/random_recall/CHANGELOG.md
```

- [ ] **Step 2: Add entry to CHANGELOG**

At the top of `CHANGELOG.md`, add:

```markdown
## [Unreleased]

### Changed
- **BREAKING:** Replaced multi-device real-time sync with single active device model
  - Only one device per user can be logged in at a time
  - Users on multiple devices will be silently logged out on next app open
  - Cloud Firestore now acts as backup-only, not real-time sync
  - Eliminates data loss bugs from destructive reconciliation
  - Simplified codebase by removing ~150 lines of complex sync logic

### Removed
- `SyncService.startRealtimeSync()` method
- `SyncService._applyRemoteChanges()` method
- Firestore snapshot listeners for real-time category/question/score updates
- Auto-sync debounce timer (replaced with manual backup on logout/update)

### Fixed
- Fixes issue #7: Deleted questions no longer restored on sync
- Fixes issue #8: Data loss when clearing app data and logging in again
```

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: add CHANGELOG entry for single-device sync changes"
```

---

## Verification Checklist

After all tasks complete, verify:

- [ ] All Dart files analyze with no errors: `flutter analyze lib/`
- [ ] All tests pass: `flutter test`
- [ ] No calls to `startRealtimeSync()` or `stopRealtimeSync()` remain in codebase: `grep -r "startRealtimeSync\|stopRealtimeSync" lib/`
- [ ] Device ID is generated on first run and stored in SharedPreferences
- [ ] `performBackup()` writes `last_active_device_id` to user document
- [ ] `_HomeGate._initFlow()` calls `_checkActiveDevice()` after reading onboarding status
- [ ] No real-time listeners active (verified by absence of `snapshots().listen()` calls in sync_service.dart)
- [ ] Build succeeds: `flutter build apk --debug`
- [ ] Manual testing on two devices confirms single-device behavior

---

## Rollback Plan

If critical issues arise:

1. Revert all commits since start:
   ```bash
   git reset --hard <commit-before-this-branch>
   ```

2. Or revert individual commits in reverse order:
   ```bash
   git revert HEAD~10..HEAD
   ```

All data in Firestore is preserved. Users can log in normally after rollback.

