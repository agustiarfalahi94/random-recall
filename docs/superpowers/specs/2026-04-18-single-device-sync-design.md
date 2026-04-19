# Single Active Device Sync Model — Design Specification

**Date:** 2026-04-18  
**Author:** Claude Code  
**Status:** Design Phase  
**Priority:** Critical (fixes data loss bugs)

---

## Executive Summary

Replace the complex multi-device real-time sync system with a simpler **single active device** model. Only one device per user can be authenticated at a time. Cloud Firestore acts as a backup store for device migration, not as a real-time sync target.

**Impact:**
- Eliminates data loss bugs (items #7, #8 from brainstorming)
- Prevents account sharing abuse (one premium account, two devices)
- Simplifies codebase — removes 150+ lines of complex sync logic
- No more race conditions, conflict resolution, or destructive reconciliation

---

## Problem Statement

The current sync system has three critical issues:

1. **Destructive reconciliation** — `performBackup()` compares local IDs vs Firestore IDs and deletes cloud documents not found locally. When a device is cleared or has stale data, this wipes the entire cloud backup.
2. **Race condition on login** — `_HomeGate._initFlow()` can race past the sync check and show onboarding for existing users, triggering the creation of their "first question" which then triggers a backup that deletes all 170+ questions from the cloud.
3. **Soft-delete gaps** — Hard deletes mean deletion propagation is unreliable across devices. No way to distinguish "user deleted this" from "this device doesn't have this yet."

All three trace back to supporting simultaneous multi-device use, which is not a core value proposition for a quiz app.

---

## Design

### A. Device Identity & Active Session Tracking

#### Implementation

1. **Generate device ID on first install**
   - Create a UUID on app first run
   - Store in SharedPreferences as `device_id` (permanent)
   - Use this same ID throughout app lifetime

2. **Track active device in Firestore**
   - Add field to user document: `last_active_device_id` (string)
   - On successful login, write the current device ID here
   - Update this field on every backup

3. **Detect logout on app resume**
   - On `_HomeGate.initState()` or periodic background check
   - Read user doc's `last_active_device_id` from Firestore
   - If it differs from local `device_id` → another device has logged in
   - Call `AuthService.signOut()` and return to login screen (no dialog)

#### Code locations
- **device_id generation:** `lib/main.dart`, `_initDeviceId()` on first run
- **device_id storage:** SharedPreferences key `device_id`
- **logout detection:** `lib/screens/home/home_screen.dart` or `lib/main.dart` in the gate
- **Firestore writes:** `lib/core/sync/sync_service.dart:performBackup()` (update user doc)
- **Firestore reads:** `lib/main.dart:_HomeGate._initFlow()` (listen to user doc)

---

### B. Backup (One-Way Upload)

#### Current behavior to preserve

- `performBackup()` uploads all local questions, categories, score records
- Sets `last_sync_at` timestamp on user document
- Stores settings and streak data as nested fields

#### Behavior to change

1. **Remove destructive reconciliation**
   - Delete lines 238–253 in `sync_service.dart` (the "reconcile: delete Firestore documents" section)
   - Stop deleting remote docs that don't exist locally
   - Just upload what's local; cloud keeps whatever it has

2. **Soft-delete support (optional for v1, required for v2)**
   - If a question is deleted locally, upload it with `is_deleted = 1`
   - Cloud document remains but marked as deleted
   - On restore, skip documents with `is_deleted = 1`

3. **Update `last_active_device_id` on every backup**
   - Ensure user doc always reflects the most recently active device

#### Call sites
- `performBackup()` is called from:
  - `AuthService.signOut()` (line 167) — swallow errors
  - Auto-sync timer in `_setupAutoSync()` (line 37) — keep this, but ensure device ID is updated
  - Manual refresh in UI — TBD (add button if needed)

---

### C. Restore (One-Way Download)

#### Current behavior to preserve

- `performRestore(force: true, isInitialLogin: true)` on first login
- Downloads all Firestore documents and inserts locally
- Restores SharedPreferences (settings, streak, premium status)

#### Behavior to change

1. **Always clear on initial login (unchanged)**
   - Still delete local questions/categories/score records
   - This is safe now because we're not racy — restore awaits completion before UI builds

2. **Skip soft-deleted documents**
   - When restoring, check `is_deleted` flag
   - If `is_deleted = 1`, skip insert (or mark locally as deleted if we add soft-delete columns)

3. **Remove the `_applyRemoteChanges()` method entirely**
   - This method handles Firestore snapshot listeners (real-time sync)
   - No longer needed in single-device model

---

### D. Real-Time Listeners (REMOVED)

#### Remove `startRealtimeSync()`

The entire method (lines 47–120) is removed:
- No listening to `userDoc.collection('categories').snapshots()`
- No listening to `userDoc.collection('questions').snapshots()`
- No listening to `userDoc.collection('score_records').snapshots()`
- No listening to `userDoc.snapshots()` for settings updates (use explicit restore instead)

#### Where was this called?

- `lib/main.dart:_HomeGate._initFlow()` (line 398) — **delete this line**
- Settings and streak sync now happen only during backup/restore, not real-time

#### Side effect

Premium status no longer syncs in real-time. On login, it's restored from cloud. If user buys premium on the web, they see it on mobile after next login. This is acceptable.

---

### E. Login Flow (Simplified)

Current: `AuthService.signInWithEmail()` → `initializeUserSession()` → `performRestore(force: true, isInitialLogin: true)` → race with `_HomeGate._initFlow()`

New:
1. User logs in via email/Google
2. `initializeUserSession()` awaits `performRestore(force: true, isInitialLogin: true)`
3. Restore clears local DB, downloads from cloud, sets `onboarding_complete` based on cloud data
4. `_auth.userChanges()` emits → `_HomeGate` builds
5. `_HomeGate._initFlow()` reads `onboarding_complete` from SharedPreferences (already set by restore)
6. No race condition — everything is sequential

#### Code

- `lib/core/auth/auth_service.dart:initializeUserSession()` (line 108) — unchanged, awaits restore
- `lib/main.dart:_HomeGate._initFlow()` (line 379) — **simplify**: remove `while (isSyncing)` loop, remove `performRestore()` call, just read prefs

---

### F. Logout Detection (Active)

When user opens app on Device A after logging in on Device B:

1. `_HomeGate._initFlow()` reads Firestore user doc's `last_active_device_id`
2. Compares to local device ID
3. If mismatch → call `AuthService.signOut()` → return to login
4. Next time user opens Device A, they're logged out (silent, no dialog)

#### Implementation options

**Option 1 (Recommended):** One-time check on app resume
```dart
Future<void> _checkActiveDevice() async {
  final user = AuthService.instance.currentUser;
  if (user == null) return;
  
  final prefs = await SharedPreferences.getInstance();
  final localDeviceId = prefs.getString('device_id');
  
  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();
  
  final remoteDeviceId = userDoc['last_active_device_id'];
  
  if (localDeviceId != remoteDeviceId) {
    // Silent logout
    await AuthService.instance.signOut();
    // UI will rebuild to login screen via authStateChanges stream
  }
}
```

**Option 2 (More responsive):** Listen to user doc changes
- Subscribe to user doc snapshots
- Detect device ID change immediately
- More complex, overkill for this use case

**Recommendation:** Option 1, called from `_HomeGate._initFlow()` after checking `onboarding_complete`

---

### G. Database Schema (No Changes)

The local SQLite schema remains **unchanged**:
- `categories`, `questions`, `score_records` tables
- No `is_deleted` column needed for v1 (optional for v2)
- Firestore schema also unchanged

**Future (v2):** Add `is_deleted INTEGER DEFAULT 0` column if we want soft-delete support. For v1, hard delete is fine since there's no multi-device conflict.

---

### H. Auto-Sync Timer

The current auto-sync debounce (line 36 in `sync_service.dart`) **stays**:
- Still debounce backup calls on local DB changes
- Ensures we don't hammer Firestore on rapid edits
- Now safe because there's no destructive reconciliation

**Change:** After backup, ensure `last_active_device_id` is written (already done in updated `performBackup()`)

---

## Removed Code

### Full deletions

1. **`SyncService.startRealtimeSync()`** (lines 47–120)
   - All Firestore snapshot listeners
   - User doc listener for real-time settings sync
   - The `_subscriptions` list and `stopRealtimeSync()` method become no-op or deleted

2. **`SyncService._applyRemoteChanges()`** (lines 133–192)
   - Handles Firestore snapshot documents
   - No longer needed without listeners

3. **Destructive reconciliation in `performBackup()`** (lines 238–253)
   - The logic that deletes Firestore docs not found locally
   - Keep only the forward upload

4. **Race condition workaround in `_HomeGate._initFlow()`** (lines 383–385)
   - The `while (isSyncing)` loop
   - No longer needed because restore is awaited before UI builds

### Partial changes

- `performRestore()` — add check for `is_deleted` flag if soft-delete is added
- `performBackup()` — remove reconciliation, add device ID write
- `_HomeGate._initFlow()` — simplify to just check prefs, call device check function

---

## Error Handling

### Network failures during backup
- Current: swallow in auto-sync (line 37–40)
- New: same — backup is fire-and-forget on local changes
- If manual backup fails, show snackbar (app already does this for logout)

### Network failures during restore
- Current: swallow, return null (line 292)
- New: same — restore failure is non-fatal, user just keeps local data
- On next login attempt, retry restore

### User's cloud data is corrupted or missing
- Current: restore downloads whatever is there
- New: same — no change in behavior
- If all cloud data is gone, user gets empty DB after restore (rare edge case)

---

## Testing

### Unit tests
- `test/models_test.dart` — unchanged, no new models
- Could add test for `getDeviceId()` helper

### Integration tests
- Simulate device A login, then device B login → device A should logout on next resume
- Simulate backup on device A, restore on device B (new phone scenario)
- Verify `last_active_device_id` updates after backup

### Manual testing
- Two physical devices, same Google account
- Login on Device A
- Open Device B, login → Device A should logout next time opened
- On Device A, create question, backup runs → verify on Device B (after manual restore)

---

## Migration Path

### Users currently logged in on multiple devices

After deploying this change:
- Each device will detect it's not the active device
- They'll be logged out silently on next app open
- They can log back in on one device

No data loss — all data is in Firestore, restoration is available.

### Existing cloud data

- All questions, categories, score records in Firestore are preserved
- First restore after update will pull everything down
- No migration script needed

---

## Success Criteria

1. ✅ No data loss in any scenario (clear data, device switch, etc.)
2. ✅ Only one device per user can be logged in at a time
3. ✅ Users see their data when logging in on a new device
4. ✅ Code is simpler (fewer Firestore listeners, no conflict resolution)
5. ✅ All brainstorming items #7 and #8 resolved

---

## Files Modified

- `lib/core/sync/sync_service.dart` — remove listeners, remove reconciliation, add device ID update
- `lib/core/auth/auth_service.dart` — unchanged (restore already called)
- `lib/main.dart` — add device ID generation, simplify `_HomeGate._initFlow()`, add device check
- `lib/models/question.dart`, `category.dart`, `score_record.dart` — unchanged

---

## Open Questions / Deferred

- Should we warn users that this is a logout? (Decided: silent)
- Should we add soft-delete columns later for better deletion UX? (Deferred to v2)
- Should premium sync in real-time or only on login? (Deferred — on login is fine for now)

