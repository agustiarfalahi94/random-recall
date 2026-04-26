# Phone Number Authentication Design

## Goal

Add phone number (SMS OTP) as a first-class login method alongside the existing Google and email/password options, and make the profile phone number field authoritative — driven by the verified Firebase Auth phone credential rather than free text.

## Architecture

Firebase Phone Auth is used for all OTP flows. It integrates natively with the existing `FirebaseAuth` instance — a phone-verified user has the same `currentUser`, same UID, and same Firestore document as any other auth method.

Three new methods are added to `AuthService`:

- `verifyPhoneNumber(phoneNumber, onCodeSent, onAutoVerified, onFailed)` — initiates the SMS send; hands back a `verificationId` via callback. On Android, Firebase may auto-retrieve the SMS code and call `onAutoVerified` directly.
- `signInWithPhone(verificationId, smsCode)` — completes OTP for a new or returning phone user.
- `linkPhoneNumber(verificationId, smsCode)` — links a phone credential to an already-signed-in account (for existing email/Google users).

`initializeUserSession()` currently gates on `user.emailVerified`. Phone-verified users are verified by definition (they proved ownership via OTP), so the gate becomes:

```dart
if (user == null || (!user.emailVerified && user.phoneNumber == null)) return;
```

`_ensureUserDocument()` is updated to write `phone_number` when present and `email` when present — either may be null for phone-only or email-only accounts respectively.

## New Files

- `lib/screens/auth/phone_auth_screen.dart` — two-stage OTP screen (phone entry → code entry), used for both sign-in and linking
- `lib/screens/auth/optional_email_prompt_screen.dart` — post-signup prompt for phone-only users to optionally add a recovery email

## Modified Files

- `lib/core/auth/auth_service.dart` — add `verifyPhoneNumber`, `signInWithPhone`, `linkPhoneNumber`; update `initializeUserSession` and `_ensureUserDocument`
- `lib/screens/auth/login_screen.dart` — add "Continue with Phone Number" button
- `lib/screens/profile/profile_screen.dart` — replace free-text phone field with auth-driven phone field
- `lib/core/services/profile_service.dart` — add `linkPhoneNumber`, `changePhoneNumber`, `deleteAccountPhoneAuth`

## Login Screen

The login screen gains a third button below the existing two:

```
[Continue with Google]
[Continue with Email]
[Continue with Phone Number]   ← new
```

Tapping "Continue with Phone Number" pushes `PhoneAuthScreen`.

## PhoneAuthScreen

A single screen with two in-place stages.

**Stage 1 — Phone entry**
- Country code picker (defaults to user's locale) + phone number text field
- "Send OTP" button → calls `AuthService.verifyPhoneNumber()`
- On Android, if Firebase auto-retrieves the SMS, Stage 2 is skipped and sign-in completes automatically

**Stage 2 — Code entry**
- 6-digit OTP input; auto-submits when all 6 digits are filled
- "Resend" link with a 60-second countdown cooldown (limits SMS cost)
- Submit → calls `AuthService.signInWithPhone(verificationId, smsCode)`

**Post sign-in routing:**
- New account (no prior Firebase user with that phone) → `DisplayNameSetupScreen` → `OptionalEmailPromptScreen` → home
- Returning phone user → home directly
- Phone already linked to existing account → signs into that existing account → home (Firebase handles this transparently)

**Collision error:** if the phone number belongs to a *different* Firebase account, Firebase throws `credential-already-in-use`. Show: "This phone number is already linked to another account."

## OptionalEmailPromptScreen

Shown once, immediately after `DisplayNameSetupScreen`, for new phone-only users.

- Explanation: "Add an email address so you can recover your account if you ever lose access to your phone number."
- Email field + "Add Email" button — on submit, Firebase sends a verification email and Firestore `email` is updated
- "Skip for now" text link

On skip:
- Increment `phone_only_prompted` in Firestore by 1 (starts at 0, becomes 1 after this screen)
- Route to home

The profile page shows a soft "Add recovery email" row for phone-only users where `phone_only_prompted < 2`. When the user dismisses that nudge, `phone_only_prompted` is incremented to 2 and the row is hidden permanently. Once they've been prompted twice total and still skipped, the nudge is never shown again.

## Profile Page — Phone Field

The free-text `TextField` for phone number is replaced with a read-only display that reflects the Firebase Auth phone credential.

**No phone linked:**
```
Phone number    [Link phone number →]
```
Tapping opens `PhoneAuthScreen` in linking mode. On success, `AuthService.linkPhoneNumber()` is called, and the Firestore `phone_number` field is updated to the verified number.

**Phone linked:**
```
Phone number    +62 812 3456 7890   [Change]
```
Tapping "Change" opens `PhoneAuthScreen` in change mode — phone entry is fresh (not pre-filled). On success, the old phone credential is unlinked and the new one is linked; Firestore `phone_number` updates.

**Collision error:** same message as above — "This phone number is already linked to another account."

**Sign-in provider detection** (extends existing `user.providerData` pattern):

| Provider present | Phone field behaviour | Other effects |
|---|---|---|
| `phone` only | Read-only + Change; show "Add recovery email" nudge if `phone_only_prompted < 2` | Hide change-password |
| `phone` + `password`/`google.com` | Read-only + Change | Normal |
| No `phone` | Show "Link phone number" button | — |

## Account Deletion — Phone Re-auth

`ProfileService.deleteAccountPhoneAuth()` is added alongside the existing email and Google variants.

Flow:
1. Trigger fresh OTP to the user's linked phone (pre-filled, read-only — they can't change it here)
2. User enters code → `AuthService.signInWithPhone()` re-authenticates
3. Delete Firestore data → delete Firebase Auth account → sign out

The delete account UI detects the user's provider(s) and routes accordingly:
- `password` → existing email/password re-auth
- `google.com` → existing Google re-auth
- `phone` only → new OTP re-auth
- Multiple providers linked → prefer email re-auth (simpler UX than OTP)

## Edge Cases

| Scenario | Behaviour |
|---|---|
| User tries phone OTP with a number already linked to their email account | Firebase signs them into their existing account transparently |
| User is on a new device | OTP sent to phone number — no dependency on old device |
| User changes their real phone number | "Change" flow in profile — old credential unlinked, new one linked, Firestore updated |
| User requests resend repeatedly | 60-second cooldown per attempt limits SMS charges |
| Firebase auto-retrieves SMS (Android) | Stage 2 skipped, sign-in completes without user typing the code |

## SMS Cost

Firebase Phone Auth is billed to the developer's Firebase project (Blaze plan), not to the user. First 10 verifications per month are free — useful for testing. Beyond that, pricing is per SMS and varies by country (Indonesia is on the lower end). The 60-second resend cooldown reduces unnecessary retries.
