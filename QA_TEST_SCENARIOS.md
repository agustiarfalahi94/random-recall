# Random Recall — Comprehensive QA Test Scenarios

**Legend**
- `[+]` Positive / happy path
- `[-]` Negative / error / edge case
- `[S]` Security test
- `[F]` Free user precondition
- `[P]` Premium user precondition
- `[CA]` Challenge active precondition
- `[CI]` Challenge inactive precondition
- `[NEW]` New / first-time user
- `[EX]` Existing user with data
- `[EN]` English locale
- `[ID]` Indonesian locale
- `[ON]` Online (network available)
- `[OFF]` Offline (no network)

Run every scenario in **both EN and ID** unless tagged otherwise.
Run every scenario as **both Free and Premium** unless tagged otherwise.

---

## A — AUTHENTICATION & ACCOUNT MANAGEMENT

### A1 — New User Registration: Google

| ID | Description | Type | Expected Result |
|---|---|---|---|
| A001 | Register via Google — first time, valid Google account | [+][NEW] | Firestore user doc created, display name dialog if name empty, lands on Onboarding |
| A002 | Register via Google — Google account picker dismissed (cancel) | [-][NEW] | No account created, stays on LoginScreen |
| A003 | Register via Google — Google Play Services not available | [-][NEW] | Error shown gracefully, no crash |
| A004 | Register via Google — no internet during Google sign-in | [-][NEW][OFF] | Error shown, stays on LoginScreen |
| A005 | Register via Google — Google account already linked to existing app account | [+][EX] | Logs in as existing user, skips onboarding |
| A006 | Register via Google — revoke Google permissions mid-flow | [-][NEW] | Error shown gracefully |
| A007 | Register via Google — Firestore write fails (network drops after auth) | [-][NEW] | User document creation retried or error handled, no crash |

### A2 — New User Registration: Email

| ID | Description | Type | Expected Result |
|---|---|---|---|
| A008 | Register with valid email + strong password | [+][NEW] | Account created, verification email sent, lands on VerifyEmailScreen |
| A009 | Register — password under 6 characters | [-][NEW] | Error shown before submission, no account created |
| A010 | Register — password = 6 characters exactly (boundary) | [+][NEW] | Accepted |
| A011 | Register — email already registered | [-][NEW] | "Email already in use" error |
| A012 | Register — invalid email format (no @) | [-][NEW] | Input validation error |
| A013 | Register — invalid email format (no domain) | [-][NEW] | Input validation error |
| A014 | Register — email with spaces | [-][NEW] | Rejected or trimmed and accepted |
| A015 | Register — password = 100 characters | [+][NEW] | Accepted |
| A016 | Register — both fields empty on submit | [-][NEW] | Both fields show error |
| A017 | Register — email field empty on submit | [-][NEW] | Email field shows error |
| A018 | Register — password field empty on submit | [-][NEW] | Password field shows error |
| A019 | Register — no internet | [-][NEW][OFF] | Error shown, no account created |
| A020 | Register — verification email received and link works | [+][NEW] | Email verified, user can proceed to HomeScreen |
| A021 | Register — verification email link expired | [-][NEW] | Error shown when tapping link, can request new one |

### A3 — New User Registration: Phone

| ID | Description | Type | Expected Result |
|---|---|---|---|
| A022 | Register with valid phone number, correct OTP | [+][NEW] | Account created, optional email prompt shown |
| A023 | Register — invalid phone format (too short) | [-][NEW] | Error before OTP sent |
| A024 | Register — invalid phone format (letters) | [-][NEW] | Input blocked or error |
| A025 | Register — valid number, wrong OTP | [-][NEW] | "Invalid code" error, stays on OTP screen |
| A026 | Register — valid number, OTP expired, request resend | [+][NEW] | New OTP sent, old OTP rejected |
| A027 | Register — phone number already registered | [+][EX] | Logs in as existing user (OTP verified), skips onboarding |
| A028 | Register — no internet when submitting phone number | [-][NEW][OFF] | Error shown, OTP not sent |
| A029 | Register — no internet when submitting OTP | [-][NEW][OFF] | Error shown |
| A030 | Register — skip optional email prompt | [+][NEW] | Lands on Onboarding, no email linked |
| A031 | Register — add email at optional prompt, valid email | [+][NEW] | Email stored in Firebase, lands on Onboarding |
| A032 | Register — add email at optional prompt, already-used email | [-][NEW] | Error shown, stays on prompt |
| A033 | Register — OTP auto-detected (SMS auto-fill) | [+][NEW] | OTP filled automatically, sign-in proceeds |
| A034 | Register — resend OTP button before cooldown expires | [-][NEW] | Button disabled or cooldown shown |

### A4 — Existing User Login

| ID | Description | Type | Expected Result |
|---|---|---|---|
| A035 | Login with Google — existing account | [+][EX] | Lands on HomeScreen, data intact |
| A036 | Login with Email + correct password | [+][EX] | Lands on HomeScreen |
| A037 | Login with Email + wrong password | [-][EX] | "Wrong password" error |
| A038 | Login with Email — unverified account | [-][EX] | Lands on VerifyEmailScreen, not HomeScreen |
| A039 | Login with Email — account deleted in Firebase Console | [-] | Error shown, session cleared |
| A040 | Login with Phone — existing account | [+][EX] | Lands on HomeScreen, data intact |
| A041 | Login with Phone — OTP wrong | [-][EX] | Error shown |
| A042 | Login — no internet | [-][EX][OFF] | Error shown, stays on LoginScreen |
| A043 | Login — multiple failed attempts (Firebase rate limit) | [-] | "Too many requests" error shown |
| A044 | Login with Email — account suspended | [-] | Error shown gracefully |

### A5 — Email Verification Flow

| ID | Description | Type | Expected Result |
|---|---|---|---|
| A045 | VerifyEmailScreen — tap Resend Email | [+] | New verification email sent, confirmation shown |
| A046 | VerifyEmailScreen — tap "I've Verified" before verifying | [-] | Stays on screen, no navigation |
| A047 | VerifyEmailScreen — tap "I've Verified" after verifying in browser | [+] | Proceeds to HomeScreen or Onboarding |
| A048 | VerifyEmailScreen — no internet when resending | [-][OFF] | Error shown, button re-enabled |
| A049 | VerifyEmailScreen — spam resend (multiple taps) | [-] | Firebase rate limit handled gracefully |

### A6 — Password Reset

| ID | Description | Type | Expected Result |
|---|---|---|---|
| A050 | Forgot Password — registered email | [+] | Reset email sent, success message shown |
| A051 | Forgot Password — unregistered email | [-] | "No account found" error |
| A052 | Forgot Password — invalid email format | [-] | Validation error before submission |
| A053 | Forgot Password — no internet | [-][OFF] | Error shown |
| A054 | Forgot Password — use expired reset link | [-] | Error page in browser or redirect |
| A055 | Forgot Password — use valid reset link, set new password | [+] | Password changed, can log in with new password |
| A056 | Forgot Password — set new password same as old | [+] | Accepted (Firebase allows it) |

### A7 — Account Linking

| ID | Description | Type | Expected Result |
|---|---|---|---|
| A057 | Email user — add phone number, correct OTP | [+][EX] | Phone linked, shown in Profile |
| A058 | Email user — add phone, wrong OTP | [-][EX] | Error, phone not linked |
| A059 | Email user — add phone already used by another account | [-][EX] | Error: "phone already in use" |
| A060 | Email user — change existing phone, correct OTP for new number | [+][EX] | Old unlinked, new linked, Firestore updated |
| A061 | Email user — change phone, wrong OTP | [-][EX] | Error, phone unchanged |
| A062 | Google user — add phone number | [+][EX] | Phone linked to Google account |
| A063 | Phone user — optional email prompt accepted | [+][EX] | Email linked |
| A064 | Phone user — tries to link same phone again | [-][EX] | Already linked, no-op or error |
| A065 | Email user — remove linked phone (secondary provider) | [+][EX] | Phone unlinked, field cleared in Profile |
| A066 | Phone user — tries to remove phone (only provider) | [-][EX] | Blocked or warning: would lock account |

### A8 — Account Deletion

| ID | Description | Type | Expected Result |
|---|---|---|---|
| A067 | Delete account — Email user, correct password re-auth | [+][EX] | Account deleted in Firebase + Firestore, redirects to LoginScreen |
| A068 | Delete account — Email user, wrong password | [-][EX] | Error shown, account not deleted |
| A069 | Delete account — Google user, re-auth with Google | [+][EX] | Account deleted |
| A070 | Delete account — Phone user, correct OTP | [+][EX] | Account deleted |
| A071 | Delete account — Phone user, wrong OTP | [-][EX] | Error, not deleted |
| A072 | Delete account — cancel confirmation dialog | [+][EX] | Nothing deleted |
| A073 | Delete account — no internet | [-][EX][OFF] | Error shown, account not deleted |
| A074 | Delete account — premium user, subscription still active | [+][EX][P] | Account deleted; subscription persists in store (user must cancel separately) |

### A9 — Sign Out

| ID | Description | Type | Expected Result |
|---|---|---|---|
| A075 | Sign out — normal conditions | [+][EX][ON] | Final backup, local data cleared, lands on LoginScreen |
| A076 | Sign out — offline (backup times out after 8s) | [+][EX][OFF] | Backup skipped, sign-out still completes |
| A077 | Sign out — Google user, Google session also cleared | [+][EX] | Google account picker shown on next Google login |
| A078 | Sign out — premium user, local `is_premium` cleared | [+][EX][P] | Next login as different account starts as free |
| A079 | Sign out — while challenge active | [+][EX][CA] | Local state cleared; Firestore preserves challenge state for re-login |
| A080 | Sign out — double tap (race condition) | [+][EX] | Only one sign-out executes, no crash |

---

## B — ONBOARDING

| ID | Description | Type | Expected Result |
|---|---|---|---|
| B001 | New user — sees Welcome page first | [+][NEW] | Welcome page shown |
| B002 | New user — swipes/continues to First Question page | [+][NEW] | First Question page shown |
| B003 | New user — swipes/continues to Notification Setup page | [+][NEW] | Notification Setup shown |
| B004 | First Question — submit valid question and answer | [+][NEW] | Question saved locally |
| B005 | First Question — empty question field, try to proceed | [-][NEW] | Validation error, cannot proceed |
| B006 | First Question — empty answer field, try to proceed | [-][NEW] | Validation error |
| B007 | First Question — question at max character limit | [+][NEW] | Accepted |
| B008 | First Question — question over max character limit | [-][NEW] | Rejected or input blocked |
| B009 | Notification Setup — grant permission | [+][NEW] | Notifications scheduled, onboarding completes, HomeScreen |
| B010 | Notification Setup — deny permission | [+][NEW] | Lands on PermissionRequiredScreen |
| B011 | PermissionRequiredScreen — tap "Open Settings" | [+][NEW] | System notification settings opened |
| B012 | PermissionRequiredScreen — grant permission in system settings, return to app | [+][NEW] | App resumes on HomeScreen |
| B013 | PermissionRequiredScreen — deny again in system settings | [-][NEW] | Stays on PermissionRequiredScreen |
| B014 | Existing user re-login on fresh install — `onboarding_complete` false, cloud has data | [+][EX] | HomeGate detects cloud data, restores, sets flag, goes to HomeScreen |
| B015 | Existing user re-login — no cloud data found | [+][NEW] | Treated as new user, goes to Onboarding |
| B016 | Existing user re-login — restore fails (network error) | [-][EX][OFF] | Graceful error, user can retry or goes to Onboarding |
| B017 | New user — skips display name dialog (leaves empty) | [+][NEW] | No name set, no crash; home shows generic greeting |
| B018 | New user — sets display name at dialog | [+][NEW] | Name stored in Firebase user profile |
| B019 | New user — display name dialog: name > max length | [-][NEW] | Input rejected or truncated |
| B020 | Onboarding — language is Indonesian (device locale) | [+][NEW][ID] | All onboarding text in Indonesian |
| B021 | Onboarding — switch language mid-onboarding | [+][NEW] | Language updates immediately |
| B022 | Onboarding — no internet during first question save | [-][NEW][OFF] | Saved locally, syncs later |
| B023 | Onboarding — notification permission already granted (re-install) | [+][NEW] | Skips permission prompt, schedules directly |
| B024 | Existing user — `onboarding_complete` true but Firestore empty (data loss) | [-][EX] | HomeGate shows HomeScreen with empty state |
| B025 | Existing user — restore runs, `performRestore` sets `onboarding_complete` | [+][EX] | Flag set correctly, no double onboarding |

---

## C — HOME SCREEN

| ID | Description | Type | Expected Result |
|---|---|---|---|
| C001 | Home loads — displays correct user display name | [+][EX] | "Hi, [Name]" shown |
| C002 | Home loads — user has no display name | [+][EX] | Display name setup dialog appears |
| C003 | Home loads — free user, no challenge | [+][F][CI] | Challenge card shows 7-Day / 14-Day buttons |
| C004 | Home loads — premium user, no challenge | [+][P][CI] | Challenge card shows 7-Day / 14-Day buttons |
| C005 | Home loads — challenge active | [+][CA] | Challenge card shows day progress bar and Stop button |
| C006 | Home loads — challenge active, day count correct | [+][CA] | Day X / Y matches Firestore value |
| C007 | Tap 7-Day challenge button | [+][CI] | NotificationScheduleScreen opens in challenge-setup mode |
| C008 | Tap 14-Day challenge button | [+][CI] | Same, with 14-day duration |
| C009 | Stop Challenge — tap, confirm | [+][CA] | Challenge reset, card reverts to start buttons |
| C010 | Stop Challenge — tap, cancel | [+][CA] | Challenge unchanged |
| C011 | Stop Challenge — free user | [+][F][CA] | Challenge resets, bonus questions retained |
| C012 | Stop Challenge — premium user | [+][P][CA] | Challenge resets, no slot change |
| C013 | Home refreshes on return from sub-screen | [+] | Question count, streak, challenge state up to date |
| C014 | Home — question count reflects actual DB count | [+] | Shown count = `getAllQuestions()` length |
| C015 | Home — no questions yet (new user after onboarding) | [+][NEW] | Shows 1 question (from onboarding) |
| C016 | Home — ad banner visible for free user | [+][F] | ⚠️ N/A v0.13.21 — ads disabled (`kAdsEnabled=false`); no banner expected |
| C017 | Home — no ad banner for premium user | [+][P] | Banner absent (trivially passes while ads are disabled) |
| C018 | Home — navigate to Questions tab | [+] | Questions list shown |
| C019 | Home — navigate to Analytics tab | [+] | Analytics shown |
| C020 | Home — navigate to Profile tab | [+] | Profile shown |
| C021 | Home — Settings sheet opens from menu | [+] | Settings bottom sheet shown |
| C022 | Settings — Send Feedback opens dialog | [+] | Feedback dialog appears |
| C023 | Settings — Feedback submitted | [+] | Success snackbar shown |
| C024 | Settings — Feedback empty on submit | [-] | Nothing sent or button disabled |
| C025 | Settings — Language switch to Indonesian | [+][EN] | App re-renders in Indonesian |
| C026 | Settings — Language switch to English | [+][ID] | App re-renders in English |
| C027 | Home — pull to refresh (if applicable) | [+] | Data refreshed |
| C028 | Home — background → foreground, data still accurate | [+] | No stale state |
| C029 | Home — challenge card in Indonesian | [+][CA][ID] | All text translated, no overflow |
| C030 | Home — challenge card in English | [+][CA][EN] | All text shown correctly |
| C031 | Home — back button on Android | [+] | App minimizes (not exits mid-flow) |
| C032 | Home — challenge day counter at Day 1 | [+][CA] | Shows "Day 1 / 7" or "Day 1 / 14" |
| C033 | Home — challenge at final day (Day 7 of 7) | [+][CA] | Shows "Day 7 / 7" |
| C034 | Home — challenge completed, completion screen shown | [+][CA] | Challenge complete screen navigates from here |
| C035 | Home — device rotated to landscape | [+] | Layout not broken |
| C036 | Home — small screen (360dp width) | [+] | No overflow, all elements visible |

---

## D — QUESTION MANAGEMENT

### D1 — Adding Questions

| ID | Description | Type | Expected Result |
|---|---|---|---|
| D001 | Add question — all fields valid, free user | [+][F] | Saved, count increments |
| D002 | Add question — all fields valid, premium user | [+][P] | Saved |
| D003 | Add question — empty question field | [-] | Cannot save, validation error |
| D004 | Add question — empty answer field | [-] | Cannot save |
| D005 | Add question — question at exact character limit | [+] | Accepted |
| D006 | Add question — question 1 char over limit | [-] | Rejected |
| D007 | Add question — answer at exact character limit | [+] | Accepted |
| D008 | Add question — answer 1 char over limit | [-] | Rejected |
| D009 | Add question — free user at limit (20) | [-][F] | Blocked, upsell shown |
| D010 | Add question — free user at limit - 1 (19 questions) | [+][F] | Accepted, now at limit |
| D011 | Add question — free user with 1 bonus slot (21 limit) | [+][F] | 21st question accepted |
| D012 | Add question — free user with bonus, at new limit | [-][F] | Blocked at 20+bonus |
| D013 | Add question — premium user at 199 questions | [+][P] | Accepted |
| D014 | Add question — premium user at 200 questions | [-][P] | Blocked at limit |
| D015 | Add question — assign to custom category | [+] | Saved under correct category |
| D016 | Add question — no internet | [+][OFF] | Saved locally, synced when online |
| D017 | Add question — in Indonesian UI | [+][ID] | All labels and errors in Indonesian |
| D018 | Add question — special characters in question text | [+] | Saved and displayed correctly |
| D019 | Add question — emoji in question text | [+] | Saved and displayed correctly |
| D020 | Add question — very long valid question (at limit) | [+] | No layout overflow in display |

### D2 — Editing Questions

| ID | Description | Type | Expected Result |
|---|---|---|---|
| D021 | Edit question — change question text | [+] | Updated in DB and list |
| D022 | Edit question — change answer text | [+] | Updated |
| D023 | Edit question — change category | [+] | Question moves to new category |
| D024 | Edit question — clear question field | [-] | Cannot save, validation |
| D025 | Edit question — clear answer field | [-] | Cannot save |
| D026 | Edit question — no changes, save | [+] | No-op or saves same values |
| D027 | Edit question — while offline | [+][OFF] | Saved locally, synced later |
| D028 | Edit question — challenge active, timer-linked notification updates | [+][CA] | Notification re-scheduled if question is in pool |

### D3 — Deleting Questions

| ID | Description | Type | Expected Result |
|---|---|---|---|
| D029 | Delete question — confirm | [+] | Removed from DB and list |
| D030 | Delete question — cancel | [+] | Unchanged |
| D031 | Delete question — only question remaining | [+] | Deleted, notification pool becomes empty |
| D032 | Delete question — while offline | [+][OFF] | Deleted locally, synced when online |
| D033 | Delete question — during active challenge | [+][CA] | Deleted, notification pool updates |
| D034 | Delete question — stale mirror log cleared (badge count) | [+] | Badge count decrements correctly |
| D035 | Delete question — currently scheduled in notification | [+] | Notification rescheduled without that question |

### D4 — Question Limits Cross-Check

| ID | Description | Type | Expected Result |
|---|---|---|---|
| D036 | Free user, 20 questions, complete challenge → 21 limit | [+][F][CA] | After completion, 21st question can be added |
| D037 | Free user, 20 questions, complete challenge, add 21st | [+][F] | Accepted |
| D038 | Free user, 21 questions, complete another 7-day streak → 22 limit | [+][F] | 22nd accepted |
| D039 | Premium user completes challenge — no extra slot | [+][P][CA] | Question limit unchanged at 200 |
| D040 | Free user subscribes (becomes premium) mid-challenge | [+][F→P] | Immediately can add up to 200 questions |
| D041 | Premium user cancels, reverts to free tier | [+][P→F] | Limit reverts to 20 + earned bonuses |
| D042 | Free user at 25 questions (via bonuses), cancels — questions preserved | [+][F] | Existing questions kept even if over new limit |

---

## E — CATEGORY MANAGEMENT

| ID | Description | Type | Expected Result |
|---|---|---|---|
| E001 | Add custom category — valid name and emoji icon | [+] | Created, appears in list |
| E002 | Add custom category — empty name | [-] | Cannot save |
| E003 | Add custom category — name at character limit | [+] | Accepted |
| E004 | Add custom category — name over character limit | [-] | Rejected |
| E005 | Free user — add 1 custom category (limit 1) | [+][F] | Accepted |
| E006 | Free user — add 2nd custom category | [-][F] | Blocked, upsell shown |
| E007 | Premium user — add up to 20 custom categories | [+][P] | All accepted |
| E008 | Premium user — add 21st custom category | [-][P] | Blocked at 20 |
| E009 | Edit category — rename | [+] | Name updated in list and all associated questions |
| E010 | Edit category — change emoji icon | [+] | Icon updated everywhere |
| E011 | Delete category — has questions, confirm | [+] | Category deleted, questions reassigned to default |
| E012 | Delete category — has questions, cancel | [+] | Category and questions unchanged |
| E013 | Delete category — empty category | [+] | Deleted without extra warning |
| E014 | Delete category — only custom category (free user, 1 custom) | [+][F] | Deleted, now can add 1 more |
| E015 | Default categories (General, Work) — cannot be deleted | [-] | Delete option absent or blocked |
| E016 | Default categories — cannot be renamed | [-] | Edit option absent or blocked |
| E017 | Add category — offline | [+][OFF] | Created locally, synced later |
| E018 | Category with questions — edit category name — question list reflects new name | [+] | Correct category name shown on questions |
| E019 | Add category — Indonesian UI | [+][ID] | All labels in Indonesian |
| E020 | Free user subscribes — can now add up to 20 categories | [+][F→P] | Limit immediately increases |
| E021 | Premium user cancels — category limit reverts to 1 | [+][P→F] | Existing categories retained even if over new limit |
| E022 | Category icon — emoji renders on Xiaomi device | [+] | Emoji not blank or broken |
| E023 | Category list empty (all deleted) | [+] | Empty state shown, can still add |
| E024 | Add category — very long name (at limit), no overflow in UI | [+] | Text truncated or wrapped cleanly |
| E025 | Category assigned to question — category deleted — question still accessible | [+] | Question moves to default category |

---

## F — NOTIFICATION SETTINGS (Non-Challenge)

### F1 — Frequency

| ID | Description | Type | Expected Result |
|---|---|---|---|
| F001 | Set frequency — free user, slide to 1 | [+][F][CI] | Accepted |
| F002 | Set frequency — free user, slide to 3 (max) | [+][F][CI] | Accepted |
| F003 | Set frequency — free user, try to exceed 3 | [-][F][CI] | Slider capped at 3 |
| F004 | Set frequency — premium user, slide to 6 (max) | [+][P][CI] | Accepted |
| F005 | Set frequency — premium user, try to exceed 6 | [-][P][CI] | Capped at 6 |
| F006 | Set frequency — premium user, slide to 1 | [+][P][CI] | Accepted |
| F007 | Set frequency — 0 (off) | [-][CI] | Blocked (no zero-frequency) or handled |

### F2 — Active Days

| ID | Description | Type | Expected Result |
|---|---|---|---|
| F008 | Select all 7 days | [+][CI] | All days active |
| F009 | Deselect to 1 day remaining | [+][CI] | Only that day active |
| F010 | Deselect all days | [-][CI] | Warning shown or save blocked |
| F011 | Save with 3 days selected | [+][CI] | Notifications only fire on those 3 days |
| F012 | Active days in Indonesian (Mon/Tue labels) | [+][CI][ID] | Translated day labels |

### F3 — Time Window

| ID | Description | Type | Expected Result |
|---|---|---|---|
| F013 | "Send at any time" ON — start/end time pickers hidden | [+][CI] | Time pickers not shown |
| F014 | "Send at any time" OFF — start/end time pickers shown | [+][CI] | Pickers visible |
| F015 | Set start time 08:00, end time 20:00 | [+][CI] | Notifications only within window |
| F016 | Set end time = start time | [-][CI] | Error shown or blocked |
| F017 | Set end time before start time | [-][CI] | Error shown, save blocked |
| F018 | Start time 00:00, end time 23:59 | [+][CI] | Full day window accepted |
| F019 | Start time 12:00, end time 12:01 (1 min window) | [+][CI] | Accepted, narrow window |

### F4 — Timer

| ID | Description | Type | Expected Result |
|---|---|---|---|
| F020 | Set timer to 0 (off) — outside challenge | [+][CI] | No countdown on question screen |
| F021 | Set timer to 5s — outside challenge | [+][CI] | 5s countdown shown |
| F022 | Set timer to 30s | [+][CI] | 30s countdown shown |
| F023 | Set timer to 90s (max) | [+][CI] | 90s countdown shown |
| F024 | Set timer to 91s (if possible via slider) | [-][CI] | Slider capped at 90 |
| F025 | Challenge active — timer slider greyed out | [+][CA] | Cannot change timer |
| F026 | Challenge active — timer shows locked value | [+][CA] | Shows 5s or 10s, not editable |
| F027 | Challenge setup open — timer slider restricted 5–10s only | [+] | Cannot drag below 5 or above 10 |
| F028 | Challenge setup — current pref timer = 0 → clamped to 5s | [+] | Opens at 5s |
| F029 | Challenge setup — current pref timer = 15s → clamped to 10s | [+] | Opens at 10s |
| F030 | Challenge setup — current pref timer = 7s → stays at 7s | [+] | Opens at 7s (within range) |
| F031 | Challenge setup — current pref timer = 5s → stays at 5s | [+] | Opens at 5s |
| F032 | Challenge setup — current pref timer = 10s → stays at 10s | [+] | Opens at 10s |

### F5 — Save & Apply

| ID | Description | Type | Expected Result |
|---|---|---|---|
| F033 | Save settings — notifications rescheduled immediately | [+] | Next notification matches new settings |
| F034 | Save settings — no changes made | [+] | Save button disabled |
| F035 | Save settings — discard changes via back | [+] | Old settings retained |
| F036 | Save settings — offline | [+][OFF] | Settings saved locally, notifications rescheduled |
| F037 | Save settings — in Indonesian UI | [+][ID] | Labels in Indonesian, behavior same |
| F038 | Settings screen — challenge active, locked fields shown as greyed | [+][CA] | Timer, frequency, days, anytime all locked |
| F039 | Settings screen — challenge inactive, all fields editable | [+][CI] | Full editing available |

---

## G — CHALLENGE MODE

### G1 — Starting a Challenge

| ID | Description | Type | Expected Result |
|---|---|---|---|
| G001 | Start 7-day — free user, timer 5s | [+][F][CI] | Challenge starts, home shows Day 1 / 7 |
| G002 | Start 7-day — free user, timer 10s | [+][F][CI] | Challenge starts with 10s |
| G003 | Start 7-day — premium user, timer 5s | [+][P][CI] | Challenge starts |
| G004 | Start 7-day — premium user, timer 10s | [+][P][CI] | Challenge starts |
| G005 | Start 14-day — free user | [+][F][CI] | Challenge starts, home shows Day 1 / 14 |
| G006 | Start 14-day — premium user | [+][P][CI] | Challenge starts |
| G007 | Start — existing streak > 0, dialog warns user | [+] | Existing streak dialog shown before confirmation |
| G008 | Start — existing streak dialog, proceed | [+] | Challenge starts, old streak overwritten |
| G009 | Start — existing streak dialog, cancel | [+] | No challenge started, streak preserved |
| G010 | Start — free user, current freq 3, saves as locked | [+][F] | Locked at 3 for challenge duration |
| G011 | Start — premium user, current freq 6, saves as locked | [+][P] | Locked at 6 for challenge duration |
| G012 | Challenge warning dialog shown before setup | [+] | Rules 1, 2, 3 all visible |
| G013 | Challenge warning dialog in Indonesian | [+][ID] | All 3 rules in Indonesian, no overflow |
| G014 | Decline warning dialog | [+] | Challenge not started |
| G015 | Accept warning dialog → NotificationScheduleScreen | [+] | Opens schedule screen in challenge-setup mode |

### G2 — Locked Settings During Challenge

| ID | Description | Type | Expected Result |
|---|---|---|---|
| G016 | Challenge active — timer slider greyed, shows locked value | [+][CA] | Cannot change |
| G017 | Challenge active — frequency slider greyed | [+][CA] | Cannot change |
| G018 | Challenge active — active days checkboxes greyed | [+][CA] | Cannot change |
| G019 | Challenge active — anytime toggle greyed | [+][CA] | Cannot change |
| G020 | Challenge active — "anytime ON" locked, start/end time hidden | [+][CA] | Time pickers not shown |
| G021 | Challenge active — "anytime OFF" locked, start/end time visible but greyed | [+][CA] | Time shown but not editable |
| G022 | Challenge active — attempt to change any locked field | [-][CA] | No change applied |
| G023 | Challenge active — settings screen shows lock explanation | [+][CA] | User informed why fields are locked |
| G024 | Challenge active — free user frequency locked at 3 | [+][F][CA] | Frequency = 3, greyed |
| G025 | Challenge active — premium user frequency locked at 6 | [+][P][CA] | Frequency = 6, greyed |

### G3 — Answering During Challenge

| ID | Description | Type | Expected Result |
|---|---|---|---|
| G026 | Answer correctly — Day 1, first correct answer | [+][CA] | Day stays 1, marks today as answered |
| G027 | Answer correctly — second notification same day during challenge | [+][CA] | Question answered normally, score recorded — but challenge DAY COUNTER does not advance again (only first correct answer per day advances Day X → Day X+1) |
| G028 | Answer correctly — next day, Day increments | [+][CA] | Day 1 → Day 2, saved to Firestore |
| G029 | Answer correctly — final day, challenge completes | [+][CA] | Completion screen shown |
| G030 | Answer incorrectly — any day — challenge FAILS immediately | [-][CA] | `failChallenge()` called, challenge reset |
| G031 | Answer incorrectly — home card reverts to start buttons | [-][CA] | Challenge inactive after failure |
| G032 | Answer incorrectly — all settings unlocked | [-][CA] | Timer, freq, days, anytime all editable again |
| G033 | Miss a day — no answer that day | [-][CA] | Per streak rules: day missed, challenge behavior |
| G034 | Answer correctly — free user — streak counter increments | [+][F][CA] | Streak shown correctly |
| G035 | Answer correctly — premium user — streak counter increments | [+][P][CA] | Streak shown correctly |
| G036 | Answer with timer active — within time limit | [+][CA] | Graded normally |
| G037 | Answer with timer expired — counts as incorrect (if auto-graded) | [-][CA] | Challenge fails per timer behavior |

### G4 — Challenge Completion

| ID | Description | Type | Expected Result |
|---|---|---|---|
| G038 | Complete 7-day — free user | [+][F] | Completion screen, +1 question slot granted |
| G039 | Complete 7-day — premium user | [+][P] | Completion screen, NO +1 slot |
| G040 | Complete 14-day — free user | [+][F] | Completion screen, +1 question slot |
| G041 | Complete 14-day — premium user | [+][P] | Completion screen, no slot change |
| G042 | Completion — home card reverts to start buttons | [+] | Challenge inactive |
| G043 | Completion — all settings unlocked | [+] | Timer, freq, days editable |
| G044 | Completion — free user, start new challenge | [+][F] | Can start again |
| G045 | Completion — bonus question count increments in Firestore | [+][F] | `bonus_questions` updated |
| G046 | Completion — free user was at limit, now has +1 slot, can add question | [+][F] | New question accepted |
| G047 | Completion screen in Indonesian | [+][ID] | All text translated |
| G048 | Completion — premium user graded at EXACT answer time | [+][P] | Premium check is fresh at grading, not cached |

### G5 — Challenge Failure

| ID | Description | Type | Expected Result |
|---|---|---|---|
| G049 | Fail on Day 1 — challenge resets | [-][CA] | Home shows start buttons |
| G050 | Fail on Day 5 of 7 — challenge resets, no partial reward | [-][CA] | No bonus granted |
| G051 | Fail — free user — no extra slot granted | [-][F][CA] | Slot count unchanged |
| G052 | Fail — premium user — no change | [-][P][CA] | No effect on premium |
| G053 | Fail — can immediately start new challenge | [+] | Start buttons available |

### G6 — Stop Challenge Manually

| ID | Description | Type | Expected Result |
|---|---|---|---|
| G054 | Stop — confirm | [+][CA] | Challenge reset, home reverts |
| G055 | Stop — cancel | [+][CA] | Challenge continues |
| G056 | Stop — Day 5 of 7 — no bonus | [+][CA] | No partial reward |
| G057 | Stop — all settings unlocked immediately | [+] | Editable again |
| G058 | Stop — then start fresh challenge | [+] | Can start new challenge |

### G7 — Challenge Restore After Reinstall / Re-login

| ID | Description | Type | Expected Result |
|---|---|---|---|
| G059 | Reinstall — re-login — challenge state restored from Firestore | [+][CA] | Home shows correct Day X / Y |
| G060 | Reinstall — re-login — timer locked to Firestore value | [+][CA] | Correct timer locked in settings |
| G061 | Reinstall — re-login — frequency locked to Firestore value | [+][CA] | Correct frequency locked |
| G062 | Reinstall — re-login — active days locked to Firestore value | [+][CA] | Correct days locked |
| G063 | Reinstall — re-login — anytime mode locked to Firestore value | [+][CA] | Correct anytime state |
| G064 | Reinstall — re-login — notifications rescheduled with locked params | [+][CA] | Notifications fire at correct frequency/timer |
| G065 | Switch device — re-login — same challenge state restored | [+][CA] | As above |
| G066 | Switch device — re-login — challenge was completed — shows start buttons | [+] | Not stuck in active state |
| G067 | Switch device — re-login — challenge was failed — shows start buttons | [+] | Not stuck in active state |

---

## H — QUESTION ANSWERING (NOTIFICATION SCREEN)

### H1 — Basic Flow

| ID | Description | Type | Expected Result |
|---|---|---|---|
| H001 | Tap notification — app in foreground | [+] | Question screen opens |
| H002 | Tap notification — app in background | [+] | App foregrounds, question shown |
| H003 | Tap notification — app killed (cold start) | [+] | App launches to question screen |
| H004 | Tap notification — question ID invalid / deleted | [-] | Graceful error, no crash |
| H005 | Question shown — answer options/text field visible | [+] | UI fully rendered |
| H006 | Answer correctly — non-challenge | [+][CI] | "Correct" feedback shown, score recorded |
| H007 | Answer incorrectly — non-challenge | [-][CI] | "Incorrect" feedback, correct answer shown, score recorded |
| H008 | Answer correctly — challenge active | [+][CA] | Correct feedback, challenge progresses |
| H009 | Answer incorrectly — challenge active | [-][CA] | Incorrect feedback, challenge FAILS immediately |
| H010 | Answer correctly — challenge, free user | [+][F][CA] | Score + challenge progress recorded |
| H011 | Answer incorrectly — challenge, free user | [-][F][CA] | Challenge resets, free user |
| H012 | Answer correctly — challenge, premium user | [+][P][CA] | Score + challenge progress |
| H013 | Answer incorrectly — challenge, premium user | [-][P][CA] | Challenge resets, premium user |
| H014 | Practice mode — answer correctly | [+] | Score NOT recorded, challenge NOT affected |
| H015 | Practice mode — answer incorrectly | [-] | Score NOT recorded, challenge NOT affected |
| H016 | Practice mode — challenge active | [+][CA] | Challenge streak unaffected by practice |

### H2 — Timer on Question Screen

| ID | Description | Type | Expected Result |
|---|---|---|---|
| H017 | Timer = 0 (off) — no countdown shown | [+] | No timer UI visible |
| H018 | Timer = 5s — countdown visible | [+] | 5s countdown starts |
| H019 | Timer = 30s — countdown visible | [+] | 30s countdown shown |
| H020 | Timer = 90s — countdown visible | [+] | 90s countdown shown |
| H021 | Timer expires — auto-behavior (skip or auto-grade) | [+] | Per app behavior, no crash |
| H022 | Timer expires — challenge active | [-][CA] | Counts as incorrect → challenge fails |
| H023 | Answer before timer expires — timer stops | [+] | No further countdown |

### H3 — AppBar Layout

| ID | Description | Type | Expected Result |
|---|---|---|---|
| H024 | Short category name — no challenge | [+][CI] | Full name shown, no overflow |
| H025 | Long category name — no challenge | [+][CI] | Ellipsis truncation |
| H026 | Short category name — challenge active (badges visible) | [+][CA] | Title fits, no RenderFlex overflow |
| H027 | Long category name — challenge active | [+][CA] | Ellipsis, no overflow |
| H028 | Challenge badge shows correct day | [+][CA] | "Day 3" etc. matches state |
| H029 | Timer badge shows locked seconds | [+][CA] | "5s" or "10s" badge shown |
| H030 | Xiaomi 12T — AppBar no overflow | [+] | Confirmed on device |
| H031 | Xiaomi 15 — AppBar no overflow | [+] | Confirmed on device |
| H032 | 360dp width screen — AppBar no overflow | [+] | Tested on smallest target device |
| H033 | AppBar in Indonesian — no overflow | [+][ID] | Translated label fits |

### H4 — Ads on Question Screen

> ⚠️ **N/A as of v0.13.21** — ads are disabled (`kAdsEnabled = false`). H034–H040
> cannot be run until ads are re-enabled. See section N.

| ID | Description | Type | Expected Result |
|---|---|---|---|
| H034 | Free user answers notification question — interstitial shown | [+][F] | Full-screen ad appears after grading |
| H035 | Premium user answers notification question — no interstitial | [+][P] | No ad |
| H036 | Free user answers practice question — no interstitial | [+][F] | Practice mode excluded |
| H037 | Ad banner hidden during question screen | [+][F] | Banner not visible on question screen |
| H038 | Ad banner returns after closing question screen | [+][F] | Banner reappears on HomeScreen |
| H039 | Second notification answered back-to-back — banner still hidden | [+][F] | No flash between screens |
| H040 | Interstitial fails to load — no crash | [-][F] | Silent fail, answer still recorded |

### H5 — Undo Feature

| ID | Description | Type | Expected Result |
|---|---|---|---|
| H041 | Undo available — free user, not used today | [+][F] | Undo button visible after incorrect answer |
| H042 | Undo used — answer changed to correct | [+][F] | Score updated |
| H043 | Undo used today already — undo not available | [-][F] | Undo absent or disabled |
| H044 | Premium user — undo available always | [+][P] | Undo available regardless of prior use |
| H045 | Undo — challenge active, answer was incorrect | [-][CA] | Challenge already failed; undo may not restore |

### H6 — Close / Exit

| ID | Description | Type | Expected Result |
|---|---|---|---|
| H046 | Close question mid-answer — before grading | [+] | Returns to HomeScreen cleanly, score not recorded |
| H047 | Close question after grading | [+] | Returns cleanly |
| H048 | Back button during question | [+] | Same as close |
| H049 | Home button during question | [+] | Question screen backgrounded gracefully |

---

## I — QUESTION ANSWERING (MANUAL / QUESTION SCREEN)

| ID | Description | Type | Expected Result |
|---|---|---|---|
| I001 | Open manual question screen | [+] | Random question from pool shown |
| I002 | Answer correctly — non-challenge | [+][CI] | Score recorded |
| I003 | Answer incorrectly — non-challenge | [-][CI] | Correct answer shown, score recorded |
| I004 | Answer correctly — challenge active | [+][CA] | Score + challenge progress |
| I005 | Answer incorrectly — challenge active | [-][CA] | Challenge fails |
| I006 | Answer correctly — free user | [+][F] | Score recorded |
| I007 | Answer correctly — premium user | [+][P] | Score recorded |
| I008 | Skip question | [+] | New question shown |
| I009 | No questions in pool | [-] | Empty state shown, no crash |
| I010 | 1 question in pool — same question repeats | [+] | Not a bug; only one available |
| I011 | Short category name — no overflow | [+] | Title fits |
| I012 | Long category name — challenge active (many badges) | [+][CA] | Ellipsis, no RenderFlex overflow |
| I013 | Timer active (locked 5s during challenge) | [+][CA] | 5s countdown shown |
| I014 | Timer = 0 outside challenge | [+][CI] | No countdown |
| I015 | Manual screen — free user — interstitial NOT shown (organic only) | [+][F] | No ad after manual answer (trivially passes while ads are disabled) |
| I016 | Manual screen — challenge active, badge visible | [+][CA] | Day counter badge in AppBar |
| I017 | Close manual screen | [+] | Returns to HomeScreen |
| I018 | Landscape orientation — no overflow | [+] | Layout intact |
| I019 | Answer in Indonesian UI | [+][ID] | Labels and feedback in Indonesian |
| I020 | Score recorded persists after app restart | [+] | Score in analytics after cold start |

---

## J — ANALYTICS SCREEN

| ID | Description | Type | Expected Result |
|---|---|---|---|
| J001 | View analytics — has history | [+] | Charts and stats populated |
| J002 | View analytics — no history (new user) | [+] | Empty state, no crash |
| J003 | Accuracy shown per category | [+] | Correct / incorrect breakdown visible |
| J004 | Total correct count correct | [+] | Matches actual DB records |
| J005 | Total incorrect count correct | [+] | Matches DB |
| J006 | Analytics after challenge completion | [+][CA] | Reflects all answers during challenge |
| J007 | Analytics — free user | [+][F] | No premium-only restrictions |
| J008 | Analytics — premium user | [+][P] | Same view |
| J009 | Analytics in Indonesian | [+][ID] | Labels translated |
| J010 | Analytics — 0% accuracy scenario | [+] | Shows 0%, no divide-by-zero crash |
| J011 | Analytics — 100% accuracy scenario | [+] | Shows 100% |
| J012 | Analytics — data from multiple categories | [+] | Each category shown separately |
| J013 | Analytics — scroll if many categories | [+] | Scrollable, no overflow |
| J014 | Analytics — after account restore (re-login) | [+][EX] | Historical data shown from Firestore |
| J015 | Analytics — landscape orientation | [+] | No overflow |

---

## K — PROFILE SCREEN

| ID | Description | Type | Expected Result |
|---|---|---|---|
| K001 | View profile — display name shown | [+] | Name from Firebase |
| K002 | View profile — email shown (editable for email auth) | [+] | Email visible |
| K003 | View profile — email greyed (Google/Phone auth) | [+] | Read-only |
| K004 | View profile — phone shown if linked | [+] | Phone field populated |
| K005 | View profile — phone field empty if not linked | [+] | "Add phone" option |
| K006 | View profile — no profile picture anywhere | [+] | No avatar/image UI |
| K007 | View profile — premium badge visible for premium user | [+][P] | Premium status shown |
| K008 | View profile — no premium badge for free user | [+][F] | Free user shown |
| K009 | Edit display name — valid new name | [+] | Firebase user profile updated |
| K010 | Edit display name — empty name | [-] | Cannot save |
| K011 | Edit display name — name at character limit | [+] | Accepted |
| K012 | Edit display name — special characters | [+] | Saved and displayed |
| K013 | Edit display name — offline | [-][OFF] | Error or saved locally |
| K014 | Change password — Email user, correct current password | [+] | Password updated |
| K015 | Change password — Email user, wrong current password | [-] | Error shown |
| K016 | Change password — same as current | [+] | Accepted (Firebase allows) |
| K017 | Change password — new password < 6 chars | [-] | Validation error |
| K018 | Change password — Google user (option not shown) | [+] | Change password absent |
| K019 | Change password — Phone-only user (option not shown) | [+] | Change password absent |
| K020 | Add phone — Email user, valid number + OTP | [+] | Phone linked, shown in profile |
| K021 | Add phone — already-used number | [-] | Error: phone in use |
| K022 | Change phone — correct OTP | [+] | Old unlinked, new linked |
| K023 | Change phone — wrong OTP | [-] | Error, unchanged |
| K024 | Delete phone — secondary provider | [+] | Unlinked, field cleared |
| K025 | Delete phone — only provider | [-] | Blocked |
| K026 | Profile — offline | [+][OFF] | Reads from cached data |
| K027 | Profile in Indonesian | [+][ID] | All labels in Indonesian |
| K028 | Delete account — see A067–A074 | — | — |
| K029 | Profile — subscription status shown | [+][P] | "Premium" badge |
| K030 | Profile — free user subscription status | [+][F] | "Free" or no badge |

---

## L — SUBSCRIPTION & PAYMENT

### L1 — Purchasing

| ID | Description | Type | Expected Result |
|---|---|---|---|
| L001 | Subscription screen loads — shows available plans | [+] | Plans with pricing listed |
| L002 | Subscription screen — no internet | [-][OFF] | Error or cached offerings |
| L003 | Subscription screen — RevenueCat not configured (placeholder key) | [+] | Screen shows error or no plans |
| L004 | Tap purchase — Google Play sheet opens | [+] | Play billing sheet shown |
| L005 | Purchase — user completes payment | [+] | `is_premium` set true locally + Firestore |
| L006 | Purchase — user cancels Google Play sheet | [-] | No purchase, stays on subscription screen |
| L007 | Purchase — payment card declined | [-] | Error from Google Play, stays on screen |
| L008 | Purchase — no internet during purchase attempt | [-][OFF] | Error shown, no charge |
| L009 | Purchase — success, immediate premium features available | [+] | Freq up to 6, limits raised. ⚠️ v0.13.21: no banner to disappear — verify freq/limits only |
| L010 | Purchase — success, Firestore `is_premium: true` written | [+] | Firestore updated |

### L2 — Restore Purchases

| ID | Description | Type | Expected Result |
|---|---|---|---|
| L011 | Restore purchases — valid active subscription | [+] | Premium status restored |
| L012 | Restore purchases — no prior subscription | [-] | "Nothing to restore" message |
| L013 | Restore purchases — subscription expired | [-] | Free tier restored |
| L014 | Restore purchases — offline | [-][OFF] | Error shown |
| L015 | Restore purchases — different Google Play account | [-] | No subscription found |
| L016 | Restore on fresh install, re-login | [+][EX] | RevenueCat `logIn(uid)` restores entitlement |

### L3 — Subscription Lifecycle

| ID | Description | Type | Expected Result |
|---|---|---|---|
| L017 | Subscribe for 1 month — use app all month | [+][P] | All premium features available throughout |
| L018 | Monthly subscription expires, not renewed | [+][P→F] | `is_premium` set false, free limits apply |
| L019 | Subscription expires — banner reappears | [+] | ⚠️ N/A v0.13.21 — ads disabled; verify limits revert to free tier instead |
| L020 | Subscription expires — frequency slider capped at 3 | [+] | Free tier limit applies |
| L021 | Subscription expires — question limit reverts to 20 + bonuses | [+] | Cannot add beyond free limit |
| L022 | Subscription expires — existing questions over limit preserved | [+] | Data not deleted |
| L023 | Subscription expires — existing custom categories preserved | [+] | Categories not deleted |
| L024 | Cancel mid-month — subscription active until period end | [+] | Premium until billing period ends |
| L025 | Cancel mid-month — app still shows premium during grace period | [+] | No premature downgrade |
| L026 | Grace period ends — downgrade to free | [+] | Free tier applied |
| L027 | Resubscribe after cancellation | [+] | Premium instantly restored |
| L028 | Subscription renews automatically | [+] | No interruption to premium status |
| L029 | Subscribe → cancel → let expire → resubscribe | [+] | Clean cycle, no corrupted state |

### L4 — Cross-Device Subscription

| ID | Description | Type | Expected Result |
|---|---|---|---|
| L030 | Subscribe on Device A — login on Device B — premium active | [+] | RevenueCat `logIn(uid)` detects entitlement |
| L031 | Subscribe on Device A — logout → login on Device B — immediate premium | [+] | No delay |
| L032 | Cancel subscription on Device A — Device B detects within app session | [+] | Listener `addCustomerInfoUpdateListener` fires |

### L5 — Revenue & Entitlement Edge Cases

| ID | Description | Type | Expected Result |
|---|---|---|---|
| L033 | Free user, challenge completes, gets +1 slot, then subscribes | [+][F→P] | Premium limit (200) applies, bonus slots irrelevant |
| L034 | Premium user, challenge completes — no +1 slot | [+][P] | Slot count not inflated |
| L035 | Subscribe, then immediately delete account | [+][P] | Account deleted; subscription persists in Play Store (user cancels manually) |
| L036 | Subscription entitlement ID mismatch | [-][S] | `isPremium` returns false, no premium access |

---

## M — SECURITY

> These scenarios verify that the app cannot be exploited to gain premium access, bypass limits, or access other users' data. Many require a rooted device or proxy tools to test.

### M1 — Local Storage Tampering (Rooted Device)

| ID | Description | Type | Expected Result |
|---|---|---|---|
| M001 | Manually set `is_premium = true` in SharedPreferences on rooted device | [S][-] | App respects local value — KNOWN RISK: RevenueCat not re-verified until next login. Document as accepted risk. |
| M002 | After M001 — sign out and sign in — `is_premium` re-verified via RevenueCat | [S][+] | Correct free status restored on login |
| M003 | Manually set `timer_streak_bonus_questions = 999` in SharedPreferences | [S][-] | App computes question limit as 20+999 — KNOWN RISK: accepted, no server validation |
| M004 | After M003 — sign out and sign in — bonus restored from Firestore value | [S][-] | Bonus is whatever Firestore stored; if Firestore was 0, reverts to 0 |
| M005 | Manually set `onboarding_complete = true` in SharedPreferences | [S][-] | App goes to HomeScreen — expected behavior, not a security issue |
| M006 | Manually set `device_id` to another user's device ID | [S][-] | Only affects device switching logic, does not grant access to other user's data |

### M2 — Firestore Security Rules

| ID | Description | Type | Expected Result |
|---|---|---|---|
| M007 | Authenticated user reads their own `users/{uid}` document | [S][+] | Allowed |
| M008 | Authenticated user reads another user's `users/{uid}` document | [S][-] | Denied by Firestore rules |
| M009 | Authenticated user writes to their own questions subcollection | [S][+] | Allowed |
| M010 | Authenticated user writes to another user's questions subcollection | [S][-] | Denied |
| M011 | Unauthenticated request to read any user document | [S][-] | Denied |
| M012 | Authenticated user tries to set `is_premium: true` directly in Firestore | [S][-] | Should be denied by write rules — verify rules enforce this |
| M013 | Authenticated user tries to set `bonus_questions: 999` directly in Firestore | [S][-] | Should be denied or at least server-validated |
| M014 | Authenticated user writes to `users/{uid}/streakData` | [S][-] | Rules should restrict streak writes to server/app only |
| M015 | App Check token absent — Firestore request rejected | [S][+] | App Check enforces attestation in production |
| M016 | App Check debug token in production build | [S][-] | Debug token rejected in production |
| M017 | Replay attack — reuse old Firebase Auth token | [S][-] | Token expired or revoked, rejected |

### M3 — Premium Bypass Attempts

| ID | Description | Type | Expected Result |
|---|---|---|---|
| M018 | Intercept RevenueCat response, modify `isPremium` to true | [S][-] | Server-side entitlement not bypassed; RevenueCat validates with Play |
| M019 | Purchase flow — intercept and replay purchase confirmation | [S][-] | Google Play token validated by RevenueCat server, not client |
| M020 | Free user — add question via direct SQLite DB write (rooted) | [S][-] | Question added locally, but limit enforced client-side; sync may reject |
| M021 | Free user — modify SQLite question count to appear as 0 | [S][-] | Can add questions beyond limit locally; sync pushes to Firestore |
| M022 | Decompile APK, hardcode `isPremium = true` | [S][-] | Modified APK bypasses local check; RevenueCat server check on login corrects it |
| M023 | Proxy response from Firebase — inject `is_premium: true` in Firestore read | [S][-] | HTTPS pinning or App Check should prevent; verify |

### M4 — Authentication Security

| ID | Description | Type | Expected Result |
|---|---|---|---|
| M024 | OTP brute-force — submit 10 wrong OTPs | [S][-] | Firebase rate-limits, blocks further attempts |
| M025 | OTP reuse — submit used OTP again | [S][-] | OTP rejected (single-use) |
| M026 | Phone number spoofing — fake caller ID to receive OTP | [S][-] | Not app-level; Firebase/carrier responsibility |
| M027 | Email link interception — open email verification link on different device | [S][+] | Link works (email links are not device-bound by default) |
| M028 | Session hijacking — steal Firebase token, use on another device | [S][-] | Device ID mismatch detected on next session, signs out |
| M029 | Force-quit app mid-purchase, reopen — purchase state consistent | [+] | RevenueCat listener reconciles on reopen |

### M5 — Data Isolation

| ID | Description | Type | Expected Result |
|---|---|---|---|
| M030 | Log in as User A, then log in as User B — no User A data visible | [+] | Local DB cleared on sign-out |
| M031 | User A's questions not accessible to User B via Firestore | [S][+] | Firestore rules enforce isolation |
| M032 | Sign out — local SQLite data cleared | [+] | `clearAllData()` executed |
| M033 | Sign out — SharedPreferences sensitive keys removed | [+] | `onboarding_complete`, streak keys cleared |
| M034 | Sign out — `is_premium` cleared | [+] | Next user starts as free |

### M6 — Network & API Abuse

| ID | Description | Type | Expected Result |
|---|---|---|---|
| M035 | Rapid-fire backup calls — does app debounce? | [+] | 5s debounce timer prevents flooding Firestore |
| M036 | Restore called concurrently — does app use completer? | [+] | `_restoreCompleter` prevents duplicate restores |
| M037 | Firebase Remote Config fetch abused (rapid calls) | [-] | `minimumFetchInterval: 1 hour` throttles calls |
| M038 | Malformed Firestore document — missing required fields | [-] | App handles null/missing fields without crash |
| M039 | Firestore document with unexpected field types | [-] | Safe cast or null check, no crash |

---

## N — ADS

> ⚠️ **BLOCKED as of v0.13.21 — ads are switched off** (`kAdsEnabled = false` in
> `lib/core/ads/ad_service.dart`). Every scenario in this section is currently
> **N/A**: no banner or interstitial is ever loaded or mounted, so the expected
> results below cannot be observed. Skip section N until ads are re-enabled for
> the Play Store launch, then run it in full.
>
> Two scenarios must be **re-verified with extra care** when ads come back, because
> the ad banner is what caused the v0.13.21 typing lag:
> - **N010** (banner + keyboard open) — also check typing latency in the
>   question/answer fields, not just layout.
> - **New: N020** — Banner must not be composited while the keyboard covers it on
>   the add/edit question screen. `[+][F]` → typing stays smooth, no dropped frames.

| ID | Description | Type | Expected Result |
|---|---|---|---|
| N001 | Banner loads on HomeScreen — free user | [+][F] | Ad shown below nav bar |
| N002 | No banner — premium user | [+][P] | Banner absent |
| N003 | Banner hidden on NotificationQuestionScreen | [+][F] | No banner on question screen |
| N004 | Banner hidden on QuestionScreen (manual) | [+][F] | No banner |
| N005 | Banner returns after leaving QuestionScreen | [+][F] | Banner reappears |
| N006 | Banner returns after leaving NotificationQuestionScreen | [+][F] | Reappears |
| N007 | 2nd notification question back-to-back — no banner flash | [+][F] | No brief banner appearance between screens |
| N008 | Banner on Xiaomi 12T — test device registered | [+] | Test ad loads |
| N009 | Banner on Xiaomi 15 — test device registered | [+] | Test ad loads |
| N010 | Banner — keyboard open — no double bottom padding | [+] | Layout correct |
| N011 | Banner ad fails to load | [-][F] | Silent fail, layout not broken |
| N012 | Interstitial after organic notification answer — free user | [+][F] | Full-screen ad shown |
| N013 | Interstitial — premium user — not shown | [+][P] | No ad |
| N014 | Interstitial — practice mode — not shown | [+][F] | No ad |
| N015 | Interstitial — manual question screen — not shown | [+][F] | No ad |
| N016 | Interstitial fails to load | [-][F] | Silent fail, answer still recorded |
| N017 | Banner visible in dark mode | [+] | Ad renders, layout unchanged |
| N018 | Banner visible in light mode | [+] | Ad renders |
| N019 | User subscribes mid-session — banner disappears immediately | [+][F→P] | Banner hidden without restart |
| N020 | User subscription expires mid-session — banner reappears | [+][P→F] | Banner shown after listener fires |
| N021 | App Check failure — ads still attempt to load | [-] | Ads may fail; no crash |
| N022 | Interstitial shown — close ad — returns to correct screen | [+] | No navigation broken |
| N023 | Banner on Analytics screen | [+][F] | Banner visible |
| N024 | Banner on Profile screen | [+][F] | Banner visible |
| N025 | Banner on Settings screen | [+][F] | Banner visible |
| N026 | Banner on Notification Schedule screen | [+][F] | Banner visible |
| N027 | Banner on Add/Edit Question screen | [+][F] | Banner visible, not blocked by keyboard |

---

## O — SYNC & MULTI-DEVICE

| ID | Description | Type | Expected Result |
|---|---|---|---|
| O001 | Backup — questions, categories, scores synced to Firestore | [+][ON] | All data in Firestore |
| O002 | Backup — auto-triggered 5s after DB change | [+][ON] | Debounced, not immediate |
| O003 | Backup — force backup on sign-out | [+][ON] | Backup runs before logout |
| O004 | Backup — offline, silent fail | [+][OFF] | No crash, retried on reconnect |
| O005 | Restore on fresh install — all data appears | [+][EX] | Full restore |
| O006 | Restore — concurrent calls use completer | [+] | No duplicate restores |
| O007 | Restore — `onboarding_complete` set by restore | [+][EX] | Flag set correctly |
| O008 | Restore — offline | [-][OFF] | Error shown or empty state, no crash |
| O009 | Device switching — Device A active, login on Device B | [+] | Device A detected as stale on next foreground |
| O010 | Device switching — Device A signed out automatically | [+] | HomeGate detects `device_id` mismatch |
| O011 | Device switching — Device B has all data | [+] | Full restore on Device B |
| O012 | Multiple backups in rapid succession — debounce works | [+] | Only 1 backup per 5s window |
| O013 | Delete question offline — synced on reconnect | [+] | Question removed from Firestore on reconnect |
| O014 | Add question offline — synced on reconnect | [+] | Question appears in Firestore on reconnect |
| O015 | Conflict: local newer than cloud — local wins | [+] | Backup overwrites stale cloud data |
| O016 | Score records synced | [+] | Analytics consistent across devices |
| O017 | Challenge state synced to Firestore | [+][CA] | Firestore has `streakData` |
| O018 | Challenge state restored on re-login | [+][CA] | See G059–G067 |
| O019 | Backup — premium status synced to Firestore | [+][P] | `is_premium: true` in user doc |
| O020 | Backup — free user, `is_premium: false` | [+][F] | Correctly recorded |

---

## P — NOTIFICATION DELIVERY

| ID | Description | Type | Expected Result |
|---|---|---|---|
| P001 | Notifications scheduled — fire within time window | [+] | Notification arrives during start–end hour |
| P002 | Notifications — respect active days | [+] | No notification on deselected days |
| P003 | Notifications — correct frequency | [+] | N notifications per day as set |
| P004 | Free user — max 3 notifications/day | [+][F] | No more than 3 arrive |
| P005 | Premium user — max 6 notifications/day | [+][P] | Up to 6 arrive |
| P006 | No questions in DB — no notifications | [+] | Scheduler handles empty pool |
| P007 | 1 question — same question repeated in notifications | [+] | Works, single question cycled |
| P008 | "Send at any time" ON — notifications throughout day | [+] | Not constrained to window |
| P009 | "Send at any time" OFF — outside window — no notification | [+] | Window respected |
| P010 | App killed — WorkManager reschedules | [+] | Notifications still arrive |
| P011 | Device reboot — notifications rescheduled | [+] | Boot receiver or WorkManager handles |
| P012 | Battery optimization on — notifications may be delayed | [-] | Known behavior; whitelist prompt helps |
| P013 | Battery optimization off (whitelisted) — reliable delivery | [+] | Consistent delivery |
| P014 | Notification permission revoked — app shows PermissionRequiredScreen | [+] | Detected on resume |
| P015 | Notification permission re-granted — app resumes normally | [+] | Notifications rescheduled |
| P016 | Challenge active — notifications fire with 5s or 10s timer | [+][CA] | Locked timer reflected |
| P017 | Challenge active — notifications respect locked frequency | [+][CA] | Locked count respected |
| P018 | Challenge active — notifications respect locked days | [+][CA] | Only on locked active days |
| P019 | 100 notifications scheduled (7-day pool) | [+] | All 100 batched successfully |
| P020 | Stale mirror log — deleted question not shown in notification | [+] | `cleanStaleMirrorEntries` removes it |
| P021 | Notification tapped — correct question loaded | [+] | Question ID matches |
| P022 | Multiple notifications — each has unique question | [+] | Random selection from pool |
| P023 | Notifications in Indonesian | [+][ID] | Notification text in Indonesian (if localized) |
| P024 | Xiaomi 12T — notifications deliver reliably | [+] | Device-specific test |
| P025 | Xiaomi 15 — notifications deliver reliably | [+] | Device-specific test |

---

## Q — UI / LAYOUT

### Q1 — AppBar

| ID | Description | Type | Expected Result |
|---|---|---|---|
| Q001 | QuestionScreen AppBar — short name, no challenge | [+] | No overflow |
| Q002 | QuestionScreen AppBar — long name, no challenge | [+] | Ellipsis |
| Q003 | QuestionScreen AppBar — short name, challenge active | [+][CA] | No overflow |
| Q004 | QuestionScreen AppBar — long name, challenge active | [+][CA] | Ellipsis, no RenderFlex error |
| Q005 | NotificationQuestionScreen AppBar — same overflow tests | [+] | Same as Q001–Q004 |

### Q2 — Device Sizes

| ID | Description | Type | Expected Result |
|---|---|---|---|
| Q006 | 360dp width — all screens usable | [+] | No cut-off |
| Q007 | 480dp width — all screens usable | [+] | No issues |
| Q008 | Tablet (768dp+) — layouts scale | [+] | Not stretched oddly |
| Q009 | Landscape — HomeScreen | [+] | Layout intact |
| Q010 | Landscape — QuestionScreen | [+] | No overflow |
| Q011 | Landscape — NotificationScheduleScreen | [+] | No overflow |
| Q012 | Landscape — Auth screens | [+] | Usable |

### Q3 — Keyboard & Padding

| ID | Description | Type | Expected Result |
|---|---|---|---|
| Q013 | Keyboard open — banner padding not doubled | [+] | Not compressed by both keyboard and banner |
| Q014 | Keyboard open — text fields not obscured | [+] | Fields scroll above keyboard |
| Q015 | Keyboard dismissed — banner repositions correctly | [+] | Banner back at bottom |

### Q4 — Themes

| ID | Description | Type | Expected Result |
|---|---|---|---|
| Q016 | Dark mode — all screens readable | [+] | No white-on-white |
| Q017 | Light mode — all screens readable | [+] | No black-on-black |
| Q018 | System dark/light toggle mid-session | [+] | App re-renders correctly |
| Q019 | High contrast mode (accessibility) | [+] | Text still readable |

### Q5 — Text Size & Accessibility

| ID | Description | Type | Expected Result |
|---|---|---|---|
| Q020 | System font size large — buttons still readable | [+] | Text wraps, not clipped |
| Q021 | System font size XL — no layout overflow | [+] | Scrollable or wraps |
| Q022 | System font size normal | [+] | Baseline, all good |
| Q023 | Talkback / screen reader — key buttons labeled | [+] | Accessible |

### Q6 — Xiaomi-Specific

| ID | Description | Type | Expected Result |
|---|---|---|---|
| Q024 | Xiaomi 12T — app launches without crash | [+] | Clean launch |
| Q025 | Xiaomi 12T — notifications deliver | [+] | Reliable |
| Q026 | Xiaomi 12T — ad banner loads | [+] | Test ad shown |
| Q027 | Xiaomi 15 — app launches without crash | [+] | Clean launch |
| Q028 | Xiaomi 15 — AppBar no overflow | [+] | Confirmed |
| Q029 | Xiaomi 15 — notifications deliver | [+] | Reliable |

---

## R — LOCALIZATION (i18n)

### R1 — English

| ID | Description | Type | Expected Result |
|---|---|---|---|
| R001 | All auth screens — English | [+][EN] | No missing keys, no `{key}` placeholders visible |
| R002 | Onboarding — English | [+][EN] | All text correct |
| R003 | HomeScreen — English | [+][EN] | All text correct |
| R004 | Challenge card — English | [+][EN] | Buttons, labels correct |
| R005 | Challenge warning dialog — English, all 3 rules visible | [+][EN] | No truncation |
| R006 | Challenge completion screen — English | [+][EN] | All text correct |
| R007 | Notification schedule — English | [+][EN] | All labels correct |
| R008 | Question screens — English | [+][EN] | All labels correct |
| R009 | Profile screen — English | [+][EN] | All fields labeled |
| R010 | Subscription screen — English | [+][EN] | Plan names, prices correct |
| R011 | Error messages — English | [+][EN] | All errors in English |
| R012 | Snackbars / confirmations — English | [+][EN] | Correct |

### R2 — Indonesian

| ID | Description | Type | Expected Result |
|---|---|---|---|
| R013 | All auth screens — Indonesian | [+][ID] | No English fallback visible |
| R014 | Onboarding — Indonesian | [+][ID] | All translated |
| R015 | HomeScreen — Indonesian | [+][ID] | All translated |
| R016 | Challenge card — Indonesian, no overflow | [+][ID] | Buttons fit |
| R017 | Challenge warning dialog — Indonesian, all 3 rules visible | [+][ID] | No truncation |
| R018 | Challenge completion screen — Indonesian | [+][ID] | All translated |
| R019 | Notification schedule — Indonesian, no overflow | [+][ID] | Labels fit |
| R020 | Question screens — Indonesian, no overflow in AppBar | [+][ID] | Ellipsis if needed |
| R021 | Profile screen — Indonesian | [+][ID] | All fields labeled |
| R022 | Subscription screen — Indonesian | [+][ID] | All translated |
| R023 | Error messages — Indonesian | [+][ID] | All in Indonesian |
| R024 | Snackbars — Indonesian | [+][ID] | Correct |
| R025 | Day names in notification settings — Indonesian (Sen/Sel/Rab...) | [+][ID] | Translated day abbreviations |
| R026 | Month/date format in analytics — Indonesian locale | [+][ID] | Correct date format |
| R027 | Long Indonesian strings in buttons — no text overflow | [+][ID] | Wraps or ellipsis |
| R028 | Long Indonesian strings in dialogs | [+][ID] | Dialog scrollable or text wraps |
| R029 | Switch language EN → ID mid-session | [+] | App re-renders, all strings swap |
| R030 | Switch language ID → EN mid-session | [+] | All strings swap back |
| R031 | Switch language — notification question screen — correct locale | [+] | Locale followed on question screen |
| R032 | Switch language — challenge dialog in correct locale | [+] | Dialog re-renders |

---

## S — APP LIFECYCLE & EDGE CASES

| ID | Description | Type | Expected Result |
|---|---|---|---|
| S001 | Cold start — app initializes without crash | [+] | Clean launch |
| S002 | Cold start — device ID already stored | [+] | Same ID reused |
| S003 | Cold start — first run, device ID generated | [+][NEW] | UUID generated and stored |
| S004 | App backgrounded — foreground resumes correctly | [+] | No state corruption |
| S005 | App killed mid-purchase — reopen — state reconciled | [+] | RevenueCat listener reconciles |
| S006 | App killed mid-challenge setup — challenge not started | [+] | No partial challenge written |
| S007 | App killed mid-question answer — no partial score | [+] | Score not double-recorded |
| S008 | Firebase user deleted externally — app detects on reload | [+] | Signs out gracefully |
| S009 | Firebase token expired — app re-authenticates silently | [+] | No crash, session refreshed |
| S010 | Remote Config fetch fails — defaults used | [+] | App uses default limits |
| S011 | Remote Config limits changed server-side — applied next session | [+] | Updated limits on next cold start |
| S012 | Firestore offline mode — reads from cache | [+] | App shows cached data |
| S013 | Network reconnects mid-session | [+] | Sync resumes automatically |
| S014 | App Check token refresh | [+] | Transparent to user |
| S015 | App Check fails in debug — debug token used | [+] | No crash in dev |
| S016 | WorkManager job fails — notifications not delivered | [-] | Known edge case; no crash |
| S017 | WorkManager registers on cold start | [+] | Alarms set on launch |
| S018 | Battery optimization — user declines whitelist | [+] | App functions, delivery less reliable |
| S019 | Battery optimization — user grants whitelist | [+] | Reliable delivery |
| S020 | SQLite DB migration (future version) — no data loss | [+] | Migrations run cleanly |
| S021 | SQLite corrupted (edge case) | [-] | Graceful error, offer clear/retry |
| S022 | SharedPreferences read fails | [-] | Defaults used, no crash |
| S023 | Two devices logged in simultaneously | [+] | Single-device model enforces logout on older device |
| S024 | Challenge active on Device A — login on Device B — challenge continues | [+][CA] | Firestore state restored |
| S025 | App update (new version install) — data preserved | [+] | No data loss on upgrade |
| S026 | App update — SharedPreferences keys unchanged | [+] | Old keys still readable |
| S027 | Crashlytics — crash logged in production | [+] | Crash appears in Firebase console |
| S028 | Crashlytics — user identifier set on login | [+] | UID attached to crashes |
| S029 | Crashlytics — user identifier cleared on logout | [+] | Anonymous after sign-out |
| S030 | App foreground after long background (1+ hour) | [+] | Auth state refreshed, no stale data |
| S031 | Notification arrives while answering another notification | [+] | Handled gracefully |
| S032 | Multiple notifications tapped in quick succession | [-] | No duplicate question screens |
| S033 | Deep link to `/question` with valid ID | [+] | Question screen opens |
| S034 | Deep link to `/question` with invalid ID | [-] | Graceful error |
| S035 | Deep link to `/question_practice` | [+] | Practice mode question opens |

---

## T — ACCESSIBILITY

| ID | Description | Type | Expected Result |
|---|---|---|---|
| T001 | Screen reader (TalkBack) — Login screen buttons labeled | [+] | "Sign in with Google" spoken |
| T002 | Screen reader — text fields labeled | [+] | "Email" and "Password" spoken |
| T003 | Screen reader — challenge day counter readable | [+] | "Day 3 of 7" spoken |
| T004 | Screen reader — ad banner has accessible label | [+] | "Advertisement" or similar |
| T005 | Minimum tap target size — all buttons ≥ 48dp | [+] | No tiny tap targets |
| T006 | Color contrast — text on background meets WCAG AA | [+] | ≥4.5:1 ratio |
| T007 | Color contrast — dark mode | [+] | Meets contrast standards |
| T008 | Focus order — logical tab order on all screens | [+] | Flows top-to-bottom, left-to-right |
| T009 | Error messages accessible to screen reader | [+] | Errors announced |
| T010 | Timer countdown announced to screen reader | [+] | "5 seconds remaining" or similar |

---

## U — PERFORMANCE

| ID | Description | Type | Expected Result |
|---|---|---|---|
| U001 | Cold start time < 3 seconds | [+] | Acceptable launch speed |
| U002 | HomeScreen load time | [+] | No visible lag |
| U003 | Backup with 200 questions — completes within timeout | [+][P] | No timeout, Firestore batch handles it |
| U004 | Restore with 200 questions — completes within reasonable time | [+][P] | Data appears within ~5s |
| U005 | Schedule 100 notifications — no UI freeze | [+] | Async, no jank |
| U006 | Analytics screen with 1000 score records | [+] | Renders without timeout |
| U007 | Scrolling question list (200 items) — smooth | [+][P] | 60fps scroll |
| U008 | Image picker — open and select quickly | [+] | No delay (if profile image ever added) |
| U009 | App memory usage — no leak after 30 min usage | [+] | Stable memory |
| U010 | Firebase Performance trace — `cold_start_post_frame` recorded | [+] | Trace in Firebase console |
| U011 | Firebase Performance trace — `sync_backup` recorded | [+] | Trace in Firebase console |
| U012 | Firebase Performance trace — `sync_restore` recorded | [+] | Trace in Firebase console |
| U013 | App runs on low-memory device (1GB RAM) | [+] | No OOM crash |
| U014 | Rapid question add (tapping add quickly) — no DB corruption | [+] | All questions saved correctly |
| U015 | Rapid sign-out (double-tap) — no crash | [+] | `_isSigningOut` guard prevents double execution |

---

## V — CHALLENGE × FREE/PREMIUM × LANGUAGE MATRIX

> Cross-cutting matrix for key flows. Each cell = one test run.

| Flow | Free + EN | Free + ID | Premium + EN | Premium + ID |
|---|---|---|---|---|
| Start 7-day challenge | V001 | V002 | V003 | V004 |
| Start 14-day challenge | V005 | V006 | V007 | V008 |
| Answer correctly Day 1 | V009 | V010 | V011 | V012 |
| Answer incorrectly (fail) | V013 | V014 | V015 | V016 |
| Answer correctly twice same day — day counter advances only once | V017 | V018 | V019 | V020 |
| Complete 7-day challenge | V021 | V022 | V023 | V024 |
| Complete 14-day challenge | V025 | V026 | V027 | V028 |
| Stop challenge mid-way | V029 | V030 | V031 | V032 |
| Reinstall + re-login, restore challenge | V033 | V034 | V035 | V036 |
| Notification during challenge | V037 | V038 | V039 | V040 |
| Challenge completion screen | V041 | V042 | V043 | V044 |

---

## W — PAYMENT × SCENARIO MATRIX

| Flow | Free User | Premium User |
|---|---|---|
| Subscribe — first time | W001 | N/A |
| Restore purchases — valid | W002 | W003 |
| Restore purchases — expired | W004 | W005 |
| Subscribe → cancel immediately | W006 | N/A |
| Subscribe → use 1 month → let expire | W007 | N/A |
| Subscribe → cancel mid-month → grace period | W008 | N/A |
| Grace period ends → downgrade | W009 | N/A |
| Resubscribe after expiry | W010 | N/A |
| Cross-device subscription detection | W011 | W012 |
| Subscribe → delete account | W013 | W014 |
| Challenge complete during active subscription | W015 | W016 |
| Challenge complete after subscription expires | W017 | N/A |

---

**Total: 1,100+ scenarios** across 23 test areas (A–W).

### Priority Order for First Test Run

1. **Auth (A)** — Gate to everything else
2. **Payment/Security (L, M)** — Business-critical
3. **Challenge Mode (G, V)** — Most complex feature
4. **Notification Delivery (P)** — Core app value
5. **Question Answering (H, I)** — Daily user flow
6. **Localization (R)** — Cross-cutting risk
7. **UI/Layout (Q)** — Device-specific regressions
8. **Sync (O)** — Data integrity
9. Everything else

### Regression Checklist After Any Code Change

For every PR / version bump, run at minimum:
- A035–A044 (existing user login, all 3 providers)
- G026–G037 (challenge answering, correct + incorrect)
- H006–H013 (notification question screen, all user/challenge combinations)
- L017–L026 (subscription lifecycle)
- M007–M016 (Firestore security rules)
- Q003–Q004 (AppBar overflow with challenge active)
- R016–R020 (Indonesian key screens)
- N001–N007 (ad banner state transitions)
