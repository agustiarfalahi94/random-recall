# Sync & Stability Improvements Design

## Goal

Fix the three latent bugs in cloud sync (500-op batch cap, resurrected deletes, unbounded restore), make deletes propagate across devices, bound cloud score history, and consolidate the duplicated `isVerified` check — plus two cheap perf wins (random-question offset, root detection off the first frame).

All work is pure code — no RevenueCat, AdMob, or Google Developer accounts required. Product decisions confirmed with the user:

- **Deletes should propagate** to Firestore (chosen over backup-only).
- **Scores:** full history stays in local SQLite; a bounded window syncs to Firestore.
- **Approach for deletes:** local tombstone journal (Approach A).

## Architecture

### New table: `sync_deletions` (schema v5)

A SQLite journal of documents deleted locally but not yet pushed to Firestore.

```sql
CREATE TABLE sync_deletions (
  collection TEXT NOT NULL,   -- 'categories' | 'questions'
  doc_id     INTEGER NOT NULL,
  deleted_at TEXT NOT NULL,
  PRIMARY KEY (collection, doc_id)
)
```

Only `categories` and `questions` are tombstoned. **Score records are never deleted in the UI** (verified: `deleteScoreRecord` has no UI caller), so no score tombstones are needed.

`DatabaseHelper` schema version bumps `4 → 5`; `_onUpgrade` adds the table. It is **never wiped** by `clearAllData()` or the restore's initial-login wipe.

### `isVerified` consolidation

Add a single static helper on `AuthService` and replace the five identical copies:

```dart
static bool isVerifiedUser(User? user) =>
    user != null && (user.emailVerified || user.phoneNumber != null);
```

| Call site | File |
|---|---|
| `initializeUserSession` guard | `auth_service.dart:271` |
| startup `isVerified` (post-frame) | `main.dart:182` |
| `_HomeGate._initFlow` `isVerified` | `main.dart:425` |
| backup guard | `sync_service.dart:50` |
| restore guard | `sync_service.dart:138` |

The `_HomeGate` login-gate at `main.dart:292-302` (which also treats Google/anonymous as verified) is a **different, intentionally more permissive** check and is left unchanged.

## Backup flow (chunked + tombstone-aware)

Runs on the existing triggers (5s debounce after DB update, manual, sign-out). New ordering:

1. **Push tombstones first.** For each `sync_deletions` row, issue a cloud delete on that doc. A row is removed from the journal only after its containing batch commits. Deletes are idempotent, so a partial failure simply retries the remaining rows next run.
2. **Upsert live data** — categories, questions, and scores where `answered_at ≥ now − 30 days`, all chunked at **450 ops per batch** (headroom under Firestore's 500-op cap).
3. **Prune cloud scores** older than 30 days — a query on `answered_at < cutoff`, deleted in chunks. This also trims the legacy full-history data already in Firestore.
4. User-doc metadata (`last_active_device_id`, `settings`, `onboarding_complete`) as today.

A `_runBatched(List<void Function(WriteBatch)>)` helper chunks the ops and commits sequentially.

The 30-day window is a **hardcoded constant** (`_scoreSyncWindowDays = 30`) — deliberately not a Remote Config key yet (no RC coupling this plan; easy to promote later).

## Restore flow (paginated + batched + tombstone-aware)

1. **Paginated reads** — `orderBy(FieldPath.documentId)` with `limit: 500` + `startAfter`, per collection.
2. **Skip tombstoned ids** — a cloud doc whose id is in `sync_deletions` is dropped (an offline delete doesn't resurrect on restore).
3. On `isInitialLogin`, wipe local tables as today, **but never wipe `sync_deletions`**.
4. Inserts via batched `txn.batch`, ordered categories → questions → scores (FK-safe).
5. **`dataFound` fix** — becomes `questions.isNotEmpty || scores.isNotEmpty` (categories excluded — default General/Work are always backed up and would be a false signal). Applied both in `sync_service.dart:192` and the direct check in `_HomeGate` (`main.dart:433`).

**Out of scope (future pass):** incremental sync (push only `updated_at > last_sync`). Full-upsert + windowed scores is enough at this scale.

## Cheap perf wins

### `getRandomQuestion` → random offset

Replace `ORDER BY RANDOM()` (full-table sort) with `LIMIT 1 OFFSET ?`, using `Random().nextInt(count)`, with a re-query fallback if the offset row is empty. Strictly better on large tables; removes the per-question sort.

### Root detection off the first frame

`main.dart:82` currently does `await detect()` + `trackStatus().ignore()` before `runApp`. Root status is informational-only (nothing blocks or hides on it). Move both into the existing post-frame block, alongside the other non-blocking init. The one-time warning dialog already renders in `home_screen.dart:745`, which runs after the frame.

## Edge cases

| Scenario | Behaviour |
|---|---|
| Offline delete, then a restore runs | Restore reads the journal and skips the cloud doc — no resurrection |
| Delete fails to reach cloud (network) | Journal row stays; retried on next backup |
| Cascade delete of a category with questions | Tombstones written for the category AND each question before the local FK cascade |
| Crash mid-backup | Some chunks committed, some not; journal rows only cleared on success — next run resumes |
| Legacy full score history in Firestore | Pruned on the first backup after this ships |
| User with categories/scores but no questions | `dataFound` now true — no false onboarding |
| Two devices | Single-active-device model unchanged; tombstone journal is local and lost on reinstall, but the cloud is already consistent by then |

## Testing

- **Tombstones:** delete cat with questions → all tombstones written + cascade; backup commits cloud deletes and clears journal; restore skips tombstoned ids and survives initial-login wipe.
- **Chunking:** `_runBatched` unit test for >500 ops; backup test seeded with >450 docs verifies multiple commits.
- **Restore pagination:** seed >500 cloud docs → paginated fetch restores all without hitting the limit.
- **Windowed scores:** backup only writes recent scores; old ones pruned.
- **`isVerifiedUser`:** unit tests (email-verified, phone-only, anonymous, null).
- **Random question:** returns a valid row within the id set; handles empty + excluded cases.

Validation: `flutter analyze` (0 issues), format, `flutter test` (77/77 + new), `flutter build apk --debug`.

## Modified files

- `lib/core/database/database_helper.dart` — v5 + `sync_deletions` table; tombstone writes in `deleteCategory`/`deleteQuestion`; journal-clearing helpers; never wipe journal in `clearAllData()`; random-offset `getRandomQuestion`
- `lib/core/sync/sync_service.dart` — chunked/tombstone-aware backup; paginated/batched/tombstone-aware restore; `dataFound` fix; windowed score sync + prune
- `lib/core/auth/auth_service.dart` — `isVerifiedUser` helper; use it in `initializeUserSession`
- `lib/main.dart` — use `isVerifiedUser` (2 sites); move root detection off the first frame

## Out of scope

- RevenueCat / AdMob real IDs (accounts not created yet)
- Incremental sync (`updated_at > last_sync`)
- Remote Config key for the score window (hardcoded 30 days)
- SQL `WHERE answered_at >= ?` filter in backup reads (still filters in Dart)
- Prefs cleanup (no pref-key registry to drive it)
