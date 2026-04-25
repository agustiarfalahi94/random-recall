# Phone Number Authentication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Firebase Phone Auth (SMS OTP) as a third login method, link the verified phone to the profile phone field, and support account linking for existing users.

**Architecture:** Firebase's built-in `verifyPhoneNumber` / `signInWithCredential` API is used throughout. Three new methods are added to `AuthService`. A single reusable `PhoneAuthScreen` handles sign-in, link, and change modes via a parameter. The profile phone field becomes read-only and driven by the Firebase Auth credential.

**Tech Stack:** `firebase_auth` (already installed), `intl_phone_field` (new — country code picker + phone input), `cloud_firestore` (already installed)

---

## File Map

**New files:**
- `lib/screens/auth/phone_auth_screen.dart` — two-stage OTP screen (phone entry → code entry); handles sign-in, link, and change modes
- `lib/screens/auth/optional_email_prompt_screen.dart` — post-signup prompt for phone-only users to optionally add a recovery email + password

**Modified files:**
- `pubspec.yaml` — add `intl_phone_field`
- `lib/l10n/app_en.arb` + `lib/l10n/app_id.arb` — new strings
- `lib/core/auth/auth_service.dart` — add `verifyPhoneNumber`, `signInWithPhone`, `linkPhoneNumber`, `changePhoneNumber`; update `initializeUserSession` and `_ensureUserDocument`
- `lib/main.dart` — add phone to `isVerified` gate (line ~312)
- `lib/screens/auth/login_screen.dart` — add "Continue with Phone Number" button
- `lib/screens/profile/profile_screen.dart` — replace free-text phone field with auth-driven display; add phone delete re-auth branch
- `lib/core/services/profile_service.dart` — add `deleteAccountPhoneAuth`

---

### Task 1: Add `intl_phone_field` dependency and all ARB strings

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_id.arb`

- [ ] **Step 1: Add `intl_phone_field` to pubspec.yaml**

Open `pubspec.yaml`. Under `dependencies:`, after the `firebase_auth` line, add:

```yaml
  intl_phone_field: ^3.2.0
```

- [ ] **Step 2: Install the package**

```bash
flutter pub get
```

Expected: resolves successfully, no errors.

- [ ] **Step 3: Add English ARB strings**

Open `lib/l10n/app_en.arb`. Add the following block immediately before the closing `}` of the file:

```json
  "continueWithPhone": "Continue with Phone Number",
  "phoneAuthTitle": "Phone Number",
  "phoneAuthEnterNumber": "Enter your phone number",
  "phoneAuthSendOtp": "Send OTP",
  "phoneAuthEnterCode": "Enter the 6-digit code",
  "phoneAuthCodeSentTo": "Code sent to {phone}",
  "@phoneAuthCodeSentTo": {
    "placeholders": { "phone": { "type": "String" } }
  },
  "phoneAuthVerify": "Verify",
  "phoneAuthResend": "Resend",
  "phoneAuthResendIn": "Resend in {seconds}s",
  "@phoneAuthResendIn": {
    "placeholders": { "seconds": { "type": "int" } }
  },
  "phoneAuthInvalidCode": "Invalid verification code. Please try again.",
  "phoneAuthTooManyRequests": "Too many attempts. Please try again later.",
  "phoneAuthCredentialInUse": "This phone number is already linked to another account.",
  "phoneAuthFailed": "Phone verification failed. Please try again.",
  "linkPhoneTitle": "Link Phone Number",
  "changePhoneTitle": "Change Phone Number",
  "profilePhoneLinkedLabel": "Verified phone",
  "profileLinkPhone": "Link phone number",
  "profileChangePhone": "Change",
  "optionalEmailTitle": "Add Recovery Email",
  "optionalEmailSubtitle": "Add an email address so you can recover your account if you ever lose access to your phone number.",
  "optionalEmailAddButton": "Add Email",
  "optionalEmailSkip": "Skip for now",
  "optionalEmailCreatePassword": "Create a password",
  "optionalEmailConfirmPassword": "Confirm password",
  "optionalEmailSuccess": "Recovery email added! Check your inbox to verify it.",
  "optionalEmailPasswordMismatch": "Passwords do not match.",
  "optionalEmailPasswordLength": "Password must be at least 6 characters.",
  "profileAddRecoveryEmail": "Add recovery email",
  "profileAddRecoveryEmailSubtitle": "Protect your account with a backup email address",
  "phoneDeleteReauthTitle": "Confirm with SMS Code",
  "phoneDeleteReauthSubtitle": "We'll send a verification code to {phone} to confirm.",
  "@phoneDeleteReauthSubtitle": {
    "placeholders": { "phone": { "type": "String" } }
  }
```

- [ ] **Step 4: Add Indonesian ARB strings**

Open `lib/l10n/app_id.arb`. Add the following block immediately before the closing `}`:

```json
  "continueWithPhone": "Lanjutkan dengan Nomor Telepon",
  "phoneAuthTitle": "Nomor Telepon",
  "phoneAuthEnterNumber": "Masukkan nomor telepon Anda",
  "phoneAuthSendOtp": "Kirim OTP",
  "phoneAuthEnterCode": "Masukkan kode 6 digit",
  "phoneAuthCodeSentTo": "Kode dikirim ke {phone}",
  "@phoneAuthCodeSentTo": {
    "placeholders": { "phone": { "type": "String" } }
  },
  "phoneAuthVerify": "Verifikasi",
  "phoneAuthResend": "Kirim Ulang",
  "phoneAuthResendIn": "Kirim ulang dalam {seconds}d",
  "@phoneAuthResendIn": {
    "placeholders": { "seconds": { "type": "int" } }
  },
  "phoneAuthInvalidCode": "Kode verifikasi tidak valid. Coba lagi.",
  "phoneAuthTooManyRequests": "Terlalu banyak percobaan. Coba lagi nanti.",
  "phoneAuthCredentialInUse": "Nomor telepon ini sudah terhubung ke akun lain.",
  "phoneAuthFailed": "Verifikasi telepon gagal. Coba lagi.",
  "linkPhoneTitle": "Hubungkan Nomor Telepon",
  "changePhoneTitle": "Ganti Nomor Telepon",
  "profilePhoneLinkedLabel": "Telepon terverifikasi",
  "profileLinkPhone": "Hubungkan nomor telepon",
  "profileChangePhone": "Ubah",
  "optionalEmailTitle": "Tambah Email Pemulihan",
  "optionalEmailSubtitle": "Tambahkan alamat email agar Anda bisa memulihkan akun jika kehilangan akses ke nomor telepon.",
  "optionalEmailAddButton": "Tambah Email",
  "optionalEmailSkip": "Lewati",
  "optionalEmailCreatePassword": "Buat kata sandi",
  "optionalEmailConfirmPassword": "Konfirmasi kata sandi",
  "optionalEmailSuccess": "Email pemulihan ditambahkan! Periksa kotak masuk Anda untuk verifikasi.",
  "optionalEmailPasswordMismatch": "Kata sandi tidak cocok.",
  "optionalEmailPasswordLength": "Kata sandi minimal 6 karakter.",
  "profileAddRecoveryEmail": "Tambah email pemulihan",
  "profileAddRecoveryEmailSubtitle": "Lindungi akun dengan alamat email cadangan",
  "phoneDeleteReauthTitle": "Konfirmasi dengan Kode SMS",
  "phoneDeleteReauthSubtitle": "Kami akan mengirim kode verifikasi ke {phone} untuk konfirmasi.",
  "@phoneDeleteReauthSubtitle": {
    "placeholders": { "phone": { "type": "String" } }
  }
```

- [ ] **Step 5: Regenerate localizations**

```bash
flutter gen-l10n
```

Expected: runs without errors, generates updated `lib/l10n/app_localizations*.dart`.

- [ ] **Step 6: Verify no analyze errors**

```bash
flutter analyze lib/l10n/
```

Expected: 0 errors.

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/l10n/app_en.arb lib/l10n/app_id.arb
git commit -m "feat(phone-auth): add intl_phone_field + all ARB strings"
```

---

### Task 2: Update `AuthService` — phone auth methods and session gate

**Files:**
- Modify: `lib/core/auth/auth_service.dart`

Read the current file at `lib/core/auth/auth_service.dart` before making any changes.

- [ ] **Step 1: Write a failing test for the session gate logic**

Create `test/core/auth/auth_service_phone_gate_test.dart`:

```dart
// Tests the phone-auth session gate logic in isolation.
// We test the boolean condition, not AuthService directly (Firebase can't be
// instantiated in unit tests without full Firebase setup).
import 'package:flutter_test/flutter_test.dart';

bool isVerifiedUser({
  required bool emailVerified,
  required bool isGoogle,
  required bool isAnonymous,
  required String? phoneNumber,
}) {
  return isGoogle || isAnonymous || emailVerified || phoneNumber != null;
}

void main() {
  group('isVerifiedUser gate', () {
    test('phone user with no email is considered verified', () {
      expect(
        isVerifiedUser(
          emailVerified: false,
          isGoogle: false,
          isAnonymous: false,
          phoneNumber: '+628123456789',
        ),
        isTrue,
      );
    });

    test('email user with unverified email is not verified', () {
      expect(
        isVerifiedUser(
          emailVerified: false,
          isGoogle: false,
          isAnonymous: false,
          phoneNumber: null,
        ),
        isFalse,
      );
    });

    test('google user is verified regardless of emailVerified', () {
      expect(
        isVerifiedUser(
          emailVerified: false,
          isGoogle: true,
          isAnonymous: false,
          phoneNumber: null,
        ),
        isTrue,
      );
    });

    test('linked account with phone and email verified is verified', () {
      expect(
        isVerifiedUser(
          emailVerified: true,
          isGoogle: false,
          isAnonymous: false,
          phoneNumber: '+628123456789',
        ),
        isTrue,
      );
    });
  });
}
```

- [ ] **Step 2: Run the test to confirm it passes (pure logic, no Firebase)**

```bash
flutter test test/core/auth/auth_service_phone_gate_test.dart -v
```

Expected: 4 passing tests.

- [ ] **Step 3: Add phone auth methods to `AuthService`**

Open `lib/core/auth/auth_service.dart`. After the closing brace of `signUpWithEmail` (around line 102), add the following three methods:

```dart
  /// Initiates phone number verification — sends an SMS OTP.
  /// [resendToken] is the token from a previous [onCodeSent] call; pass it
  /// to trigger a resend without re-entering the phone number.
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(PhoneAuthCredential credential) onAutoVerified,
    required void Function(FirebaseAuthException e) onFailed,
    int? resendToken,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onAutoVerified,
      verificationFailed: onFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (_) {},
      forceResendingToken: resendToken,
    );
  }

  /// Completes OTP sign-in for a new or returning phone user.
  Future<UserCredential> signInWithPhone(
    String verificationId,
    String smsCode,
  ) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    if (userCredential.user != null) {
      await _ensureUserDocument(userCredential.user!);
      await initializeUserSession();
      AnalyticsService.instance.trackLogin(method: 'phone').ignore();
      AnalyticsService.instance
          .identify(userCredential.user!.uid)
          .ignore();
    }
    return userCredential;
  }

  /// Links a phone credential to the currently signed-in account.
  /// Use this when an existing email/Google user wants to add their phone.
  Future<void> linkPhoneNumber(
    String verificationId,
    String smsCode,
  ) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    await user.linkWithCredential(credential);
    await user.reload();
    // Mirror the verified number into Firestore
    await _db.collection('users').doc(user.uid).update({
      'phone_number': _auth.currentUser?.phoneNumber,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Changes the phone credential on the currently signed-in account.
  /// Unlinks the old phone provider then links the new credential.
  Future<void> changePhoneNumber(
    String verificationId,
    String smsCode,
  ) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    final hasPhone = user.providerData.any((p) => p.providerId == 'phone');
    if (hasPhone) {
      await user.unlink('phone');
    }
    await user.linkWithCredential(credential);
    await user.reload();
    await _db.collection('users').doc(user.uid).update({
      'phone_number': _auth.currentUser?.phoneNumber,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
```

- [ ] **Step 4: Update `initializeUserSession` to allow phone users through**

Find the current `initializeUserSession` method (around line 106). It currently starts with:

```dart
  Future<void> initializeUserSession() async {
    final user = currentUser;
    if (user == null || !user.emailVerified) return;
```

Replace that guard with:

```dart
  Future<void> initializeUserSession() async {
    final user = currentUser;
    // Phone users are verified by OTP — no emailVerified check needed for them.
    final isVerified = user?.emailVerified == true || user?.phoneNumber != null;
    if (user == null || !isVerified) return;
```

- [ ] **Step 5: Update `_ensureUserDocument` to write phone_number for phone-only users**

Find `_ensureUserDocument` (around line 219). The current `set` call writes:

```dart
      await userDoc.set({
        'email': user.email,
        'is_premium': false,
        'created_at': FieldValue.serverTimestamp(),
      });
```

Replace it with:

```dart
      await userDoc.set({
        if (user.email != null) 'email': user.email,
        if (user.phoneNumber != null) 'phone_number': user.phoneNumber,
        'is_premium': false,
        'created_at': FieldValue.serverTimestamp(),
      });
```

- [ ] **Step 6: Analyze**

```bash
flutter analyze lib/core/auth/auth_service.dart
```

Expected: 0 errors (only pre-existing infos at most).

- [ ] **Step 7: Commit**

```bash
git add lib/core/auth/auth_service.dart test/core/auth/auth_service_phone_gate_test.dart
git commit -m "feat(phone-auth): add verifyPhoneNumber, signInWithPhone, linkPhoneNumber, changePhoneNumber to AuthService"
```

---

### Task 3: Update `main.dart` verification gate

**Files:**
- Modify: `lib/main.dart` (~line 312)

Read `lib/main.dart` around lines 304–320 before editing.

- [ ] **Step 1: Find and update the `isVerified` line**

Locate the block that reads:

```dart
                      final bool isVerified =
                          isGoogle || isAnonymous || user.emailVerified;
```

Replace with:

```dart
                      // Phone users are verified by OTP — include them.
                      final bool isVerified =
                          isGoogle ||
                          isAnonymous ||
                          user.emailVerified ||
                          user.phoneNumber != null;
```

- [ ] **Step 2: Analyze**

```bash
flutter analyze lib/main.dart
```

Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat(phone-auth): allow phone-verified users through the main auth gate"
```

---

### Task 4: Create `PhoneAuthScreen`

**Files:**
- Create: `lib/screens/auth/phone_auth_screen.dart`

This screen handles three modes passed via the `mode` parameter:
- `PhoneAuthMode.signIn` — called from `LoginScreen`, unauthenticated user
- `PhoneAuthMode.link` — called from `ProfileScreen`, adds phone to existing account
- `PhoneAuthMode.change` — called from `ProfileScreen`, replaces existing phone

- [ ] **Step 1: Create the file**

Create `lib/screens/auth/phone_auth_screen.dart` with the following complete content:

```dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:random_recall/l10n/app_localizations.dart';

import '../../core/auth/auth_service.dart';

enum PhoneAuthMode { signIn, link, change }

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key, this.mode = PhoneAuthMode.signIn});

  final PhoneAuthMode mode;

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  // Stage 1
  String _completePhoneNumber = '';
  bool _phoneValid = false;

  // Stage 2
  final _codeController = TextEditingController();
  String? _verificationId;
  int? _resendToken;

  bool _isStage2 = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Resend cooldown
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _codeController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _resendCooldown = 60;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) t.cancel();
      });
    });
  }

  Future<void> _sendOtp({bool isResend = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await AuthService.instance.verifyPhoneNumber(
      phoneNumber: _completePhoneNumber,
      resendToken: isResend ? _resendToken : null,
      onCodeSent: (verificationId, resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _isStage2 = true;
          _isLoading = false;
        });
        _startCooldown();
      },
      onAutoVerified: (credential) async {
        // Android auto-retrieved the SMS — complete immediately.
        if (!mounted) return;
        setState(() => _isLoading = true);
        try {
          await _completeWithCredential(credential);
        } catch (e) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = e.toString();
            });
          }
        }
      },
      onFailed: (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = _mapError(e, AppLocalizations.of(context)!);
        });
      },
    );
  }

  Future<void> _verifyCode() async {
    final l10n = AppLocalizations.of(context)!;
    final code = _codeController.text.trim();
    if (code.length != 6) return;
    if (_verificationId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await _completeWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _mapError(e, l10n);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = l10n.phoneAuthFailed;
        });
      }
    }
  }

  Future<void> _completeWithCredential(AuthCredential credential) async {
    switch (widget.mode) {
      case PhoneAuthMode.signIn:
        final uc = await AuthService.instance.signInWithPhone(
          (credential as PhoneAuthCredential).verificationId!,
          credential.smsCode!,
        );
        if (!mounted) return;
        // Routing handled by StreamBuilder in main.dart — just pop back to root.
        Navigator.of(context).popUntil((route) => route.isFirst);
        break;

      case PhoneAuthMode.link:
        await AuthService.instance.linkPhoneNumber(
          (credential as PhoneAuthCredential).verificationId!,
          credential.smsCode!,
        );
        if (!mounted) return;
        Navigator.of(context).pop(true); // true = success
        break;

      case PhoneAuthMode.change:
        await AuthService.instance.changePhoneNumber(
          (credential as PhoneAuthCredential).verificationId!,
          credential.smsCode!,
        );
        if (!mounted) return;
        Navigator.of(context).pop(true);
        break;
    }
  }

  String _mapError(FirebaseAuthException e, AppLocalizations l10n) {
    switch (e.code) {
      case 'invalid-verification-code':
        return l10n.phoneAuthInvalidCode;
      case 'too-many-requests':
        return l10n.phoneAuthTooManyRequests;
      case 'credential-already-in-use':
      case 'provider-already-linked':
        return l10n.phoneAuthCredentialInUse;
      default:
        return l10n.phoneAuthFailed;
    }
  }

  String _appBarTitle(AppLocalizations l10n) {
    switch (widget.mode) {
      case PhoneAuthMode.signIn:
        return l10n.phoneAuthTitle;
      case PhoneAuthMode.link:
        return l10n.linkPhoneTitle;
      case PhoneAuthMode.change:
        return l10n.changePhoneTitle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_appBarTitle(l10n))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('📱', style: TextStyle(fontSize: 48), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Text(
              _isStage2 ? l10n.phoneAuthEnterCode : l10n.phoneAuthEnterNumber,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (_isStage2) ...[
              const SizedBox(height: 8),
              Text(
                l10n.phoneAuthCodeSentTo(_completePhoneNumber),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 32),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: colorScheme.onErrorContainer, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
            ],

            if (!_isStage2) ...[
              // Stage 1: phone entry
              IntlPhoneField(
                initialCountryCode: 'ID',
                decoration: InputDecoration(
                  labelText: l10n.phoneAuthEnterNumber,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (phone) {
                  setState(() {
                    _completePhoneNumber = phone.completeNumber;
                    _phoneValid = phone.number.isNotEmpty;
                  });
                },
                onCountryChanged: (_) {},
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: (_isLoading || !_phoneValid) ? null : _sendOtp,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.phoneAuthSendOtp),
              ),
            ] else ...[
              // Stage 2: OTP entry
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  counterText: '',
                ),
                onChanged: (v) {
                  if (v.length == 6) _verifyCode();
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: (_isLoading || _codeController.text.length != 6)
                    ? null
                    : _verifyCode,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.phoneAuthVerify),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: (_isLoading || _resendCooldown > 0)
                    ? null
                    : () => _sendOtp(isResend: true),
                child: Text(
                  _resendCooldown > 0
                      ? l10n.phoneAuthResendIn(_resendCooldown)
                      : l10n.phoneAuthResend,
                  style: TextStyle(color: colorScheme.secondary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze**

```bash
flutter analyze lib/screens/auth/phone_auth_screen.dart
```

Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/auth/phone_auth_screen.dart
git commit -m "feat(phone-auth): add PhoneAuthScreen with sign-in/link/change modes"
```

---

### Task 5: Create `OptionalEmailPromptScreen`

**Files:**
- Create: `lib/screens/auth/optional_email_prompt_screen.dart`

This screen is pushed after `DisplayNameSetupScreen` for new phone-only users. It lets them optionally link an email + password to their account for recovery purposes.

- [ ] **Step 1: Create the file**

Create `lib/screens/auth/optional_email_prompt_screen.dart`:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:random_recall/l10n/app_localizations.dart';

class OptionalEmailPromptScreen extends StatefulWidget {
  const OptionalEmailPromptScreen({super.key});

  @override
  State<OptionalEmailPromptScreen> createState() =>
      _OptionalEmailPromptScreenState();
}

class _OptionalEmailPromptScreenState
    extends State<OptionalEmailPromptScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _skip() async {
    await _incrementPromptedCount();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _incrementPromptedCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({'phone_only_prompted': FieldValue.increment(1)}, SetOptions(merge: true));
  }

  Future<void> _addEmail() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (email.isEmpty || password.isEmpty) return;

    if (password != confirm) {
      setState(() => _errorMessage = l10n.optionalEmailPasswordMismatch);
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = l10n.optionalEmailPasswordLength);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');

      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.linkWithCredential(credential);
      await user.sendEmailVerification();

      // Update Firestore email field
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'email': email, 'updated_at': FieldValue.serverTimestamp()});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.optionalEmailSuccess),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.message ?? l10n.phoneAuthFailed;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      // Treat back-navigation as "skip"
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) return;
        await _incrementPromptedCount();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.optionalEmailTitle)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('🔐', style: TextStyle(fontSize: 48), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text(
                l10n.optionalEmailTitle,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.optionalEmailSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: colorScheme.onErrorContainer, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
              ],

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l10n.emailAddress,
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: l10n.optionalEmailCreatePassword,
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: l10n.optionalEmailConfirmPassword,
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isLoading ? null : _addEmail,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.optionalEmailAddButton),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isLoading ? null : _skip,
                child: Text(
                  l10n.optionalEmailSkip,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze**

```bash
flutter analyze lib/screens/auth/optional_email_prompt_screen.dart
```

Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/auth/optional_email_prompt_screen.dart
git commit -m "feat(phone-auth): add OptionalEmailPromptScreen for phone-only users"
```

---

### Task 6: Update `LoginScreen` — add phone button and new-user routing

**Files:**
- Modify: `lib/screens/auth/login_screen.dart`

Read the current file before editing.

- [ ] **Step 1: Add the phone button and handle new-user routing after sign-in**

The login screen needs to:
1. Add a "Continue with Phone Number" button
2. After phone sign-in of a **new** user, push `DisplayNameSetupScreen` → `OptionalEmailPromptScreen`

Replace the entire file content with:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:random_recall/l10n/app_localizations.dart';
import '../../core/auth/auth_service.dart';
import 'display_name_setup_screen.dart';
import 'email_auth_screen.dart';
import 'optional_email_prompt_screen.dart';
import 'phone_auth_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoggingIn = false;

  Future<void> _handleGoogleSignIn() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoggingIn = true);
    try {
      await AuthService.instance.signInWithGoogle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.loginFailedSnack(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  Future<void> _handlePhoneSignIn() async {
    // Capture whether the user is new BEFORE the sign-in (no current user yet).
    // PhoneAuthScreen pops itself when done; we check the result afterwards.
    final previousUid = AuthService.instance.currentUser?.uid;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PhoneAuthScreen(mode: PhoneAuthMode.signIn),
      ),
    );

    if (!mounted) return;

    final user = AuthService.instance.currentUser;
    if (user == null) return; // sign-in was cancelled or failed

    final isNewUser = previousUid == null || user.uid != previousUid;
    final hasNoDisplayName =
        user.displayName == null || user.displayName!.trim().isEmpty;

    if (isNewUser || hasNoDisplayName) {
      // New phone user — collect display name then optionally add email.
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const DisplayNameSetupScreen(canDismiss: false),
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const OptionalEmailPromptScreen(),
        ),
      );
    }
    // The StreamBuilder in main.dart handles routing to home once auth state changes.
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🧠', style: TextStyle(fontSize: 80)),
              const SizedBox(height: 24),
              Text(
                l10n.loginWelcomeTitle,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.loginSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              if (_isLoggingIn)
                const CircularProgressIndicator()
              else ...[
                _SocialLoginButton(
                  label: l10n.continueWithGoogle,
                  icon: Icons.login,
                  onPressed: _handleGoogleSignIn,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  foregroundColor: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EmailAuthScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.email_outlined),
                  label: Text(l10n.continueWithEmail),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(color: colorScheme.outline),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _handlePhoneSignIn,
                  icon: const Icon(Icons.phone_outlined),
                  label: Text(l10n.continueWithPhone),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(color: colorScheme.outline),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialLoginButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;

  const _SocialLoginButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: foregroundColor),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze**

```bash
flutter analyze lib/screens/auth/login_screen.dart
```

Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/auth/login_screen.dart
git commit -m "feat(phone-auth): add Continue with Phone Number button to LoginScreen"
```

---

### Task 7: Update `ProfileService` — add phone account deletion

**Files:**
- Modify: `lib/core/services/profile_service.dart`

Read the current file before editing.

- [ ] **Step 1: Add `deleteAccountPhoneAuth` method**

Open `lib/core/services/profile_service.dart`. After the closing brace of `deleteAccountGoogleAuth` (around line 131), add:

```dart
  /// Re-authenticates with a fresh OTP then deletes the account.
  /// [verificationId] and [smsCode] come from a fresh [AuthService.verifyPhoneNumber] call
  /// triggered from the UI just before calling this method.
  Future<void> deleteAccountPhoneAuth({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      await user.reauthenticateWithCredential(credential);

      // Delete Firestore data
      await _deleteUserData(user.uid);

      // Delete auth account
      await user.delete();
    } catch (e) {
      debugPrint('ProfileService: Delete account (phone) failed: $e');
      rethrow;
    }
  }
```

Also add the missing import at the top of the file (after the existing firebase_auth import):

```dart
import 'package:firebase_auth/firebase_auth.dart';
```

(It's already imported — just confirm it is; the `PhoneAuthProvider` is part of `firebase_auth`.)

- [ ] **Step 2: Analyze**

```bash
flutter analyze lib/core/services/profile_service.dart
```

Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add lib/core/services/profile_service.dart
git commit -m "feat(phone-auth): add deleteAccountPhoneAuth to ProfileService"
```

---

### Task 8: Update `ProfileScreen` — phone field and phone delete re-auth

**Files:**
- Modify: `lib/screens/profile/profile_screen.dart`

Read the full current file before editing.

This task has the most moving parts. Make the changes in order.

- [ ] **Step 1: Add new imports at the top of the file**

After the existing imports in `lib/screens/profile/profile_screen.dart`, add:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/phone_auth_screen.dart';
import '../auth/optional_email_prompt_screen.dart';
```

- [ ] **Step 2: Replace `_phoneController` with phone provider detection fields**

Find and remove:

```dart
  late TextEditingController _phoneController;
```

Add instead (alongside the existing `_isEmailUser` and `_isPremium` fields):

```dart
  bool _isPhoneUser = false;
  String? _linkedPhoneNumber; // null = no phone linked; non-null = verified phone
  int _phoneOnlyPrompted = 0; // how many times the recovery-email nudge has been shown
```

- [ ] **Step 3: Update `_loadProfileData` to populate new fields**

Replace the existing `_loadProfileData` method with:

```dart
  Future<void> _loadProfileData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final profile = await _profileService.getUserProfile();
      final prefs = await SharedPreferences.getInstance();
      final isPremium = prefs.getBool('is_premium') ?? false;

      if (mounted) {
        setState(() {
          _nameController.text = profile?['name'] ?? '';
          _isEmailUser = user.providerData.any((p) => p.providerId == 'password');
          _isPhoneUser = user.providerData.any((p) => p.providerId == 'phone');
          _linkedPhoneNumber = user.phoneNumber;
          _phoneOnlyPrompted = (profile?['phone_only_prompted'] as int?) ?? 0;
          _isPremium = isPremium;
        });
      }
    } catch (e) {
      debugPrint('ProfileScreen: Load profile failed: $e');
    }
  }
```

- [ ] **Step 4: Update `_updateProfile` to remove the phone field from the save call**

Find the `_updateProfile` method. Change the `updateUserProfile` call from:

```dart
      await _profileService.updateUserProfile(
        name: trimmedName,
        phoneNumber: _phoneController.text.trim(),
      );
```

to:

```dart
      await _profileService.updateUserProfile(name: trimmedName);
```

Also update `ProfileService.updateUserProfile` in `lib/core/services/profile_service.dart` so it no longer accepts or writes `phoneNumber` (phone is now managed by auth linking, not manual input). Replace the method body with:

```dart
  Future<void> updateUserProfile({required String name}) async {
    try {
      final user = _auth.currentUser;
      final userId = user?.uid;
      if (userId == null) throw Exception('User not authenticated');

      await user!.updateDisplayName(name);

      await _firestore.collection('users').doc(userId).update({
        'name': name,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('ProfileService: Firestore update failed: $e');
      rethrow;
    }
  }
```

- [ ] **Step 5: Add phone linking / changing helper methods**

After `_updateProfile`, add these two methods:

```dart
  Future<void> _openPhoneAuth(PhoneAuthMode mode) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PhoneAuthScreen(mode: mode),
      ),
    );
    if (result == true && mounted) {
      // Reload to reflect new phone number
      await _auth.currentUser?.reload();
      await _loadProfileData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mode == PhoneAuthMode.link
                ? AppLocalizations.of(context)!.profileUpdateSuccess
                : AppLocalizations.of(context)!.profileUpdateSuccess,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _dismissRecoveryEmailNudge() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({'phone_only_prompted': FieldValue.increment(1)}, SetOptions(merge: true));
    if (mounted) setState(() => _phoneOnlyPrompted++);
  }
```

- [ ] **Step 6: Update `_deleteAccount` to add the phone re-auth branch**

Replace the existing `_deleteAccount` method's second step:

```dart
    // Second step: Re-authentication
    if (_isEmailUser) {
      await _reauthenticateEmail();
    } else {
      await _reauthenticateGoogle();
    }
```

with:

```dart
    // Second step: Re-authentication — pick the simplest available method
    if (_isEmailUser) {
      await _reauthenticateEmail();
    } else if (_isPhoneUser && !_isEmailUser) {
      await _reauthenticatePhone();
    } else {
      await _reauthenticateGoogle();
    }
```

- [ ] **Step 7: Add `_reauthenticatePhone` method**

After `_reauthenticateGoogle`, add:

```dart
  Future<void> _reauthenticatePhone() async {
    final l10n = AppLocalizations.of(context)!;
    final phoneNumber = _linkedPhoneNumber;
    if (phoneNumber == null) return;

    // Show info dialog then launch OTP flow
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.phoneDeleteReauthTitle),
        content: Text(l10n.phoneDeleteReauthSubtitle(phoneNumber)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.deleteAccountCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.deleteAccountConfirm),
          ),
        ],
      ),
    );

    if (proceed != true || !mounted) return;

    // We need verificationId + smsCode before calling deleteAccountPhoneAuth.
    // Push PhoneAuthScreen in signIn mode; it will sign in with the same phone
    // (which re-authenticates), then we delete from within a fresh OTP flow.
    // Simpler approach: collect verificationId via a dedicated OTP prompt.
    String? verificationId;

    setState(() => _isLoading = true);

    await AuthService.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      onCodeSent: (id, _) {
        verificationId = id;
      },
      onAutoVerified: (credential) async {
        // Auto-retrieved — delete immediately
        try {
          await _profileService.deleteAccountPhoneAuth(
            verificationId: credential.verificationId!,
            smsCode: credential.smsCode!,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.accountDeletedSuccess)),
            );
            Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
          }
        } catch (e) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.accountDeleteFailed)),
            );
          }
        }
      },
      onFailed: (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.accountDeleteFailed)),
          );
        }
      },
    );

    // If auto-retrieval didn't fire, show a code-entry dialog
    if (verificationId != null && mounted) {
      final codeController = TextEditingController();
      final smsCode = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.phoneAuthEnterCode),
          content: TextField(
            controller: codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(counterText: ''),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, codeController.text.trim()),
              child: Text(l10n.deleteAccountConfirm),
            ),
          ],
        ),
      );

      if (smsCode != null && smsCode.length == 6 && mounted) {
        try {
          await _profileService.deleteAccountPhoneAuth(
            verificationId: verificationId!,
            smsCode: smsCode,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.accountDeletedSuccess)),
            );
            Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.accountDeleteFailed)),
            );
          }
        }
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }
```

- [ ] **Step 8: Replace the phone `TextField` in `build()` with the auth-driven widget**

In the `build()` method, find:

```dart
                  // Phone field
                  TextField(
                    controller: _phoneController,
                    maxLength: 20,
                    decoration: InputDecoration(
                      labelText: l10n.phoneLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
```

Replace with:

```dart
                  // Phone field — auth-driven, not free text
                  _buildPhoneField(l10n),
                  const SizedBox(height: 16),
```

Then add the `_buildPhoneField` helper method to the class (e.g., after `_loadProfileData`):

```dart
  Widget _buildPhoneField(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_linkedPhoneNumber != null) {
      // Phone is linked — show read-only with Change action
      return InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.profilePhoneLinkedLabel,
          border: const OutlineInputBorder(),
          suffixIcon: TextButton(
            onPressed: () => _openPhoneAuth(PhoneAuthMode.change),
            child: Text(l10n.profileChangePhone),
          ),
        ),
        child: Text(_linkedPhoneNumber!),
      );
    }

    // No phone linked — show Link button
    final hasEmailOrGoogle = _isEmailUser ||
        (_auth.currentUser?.providerData
                .any((p) => p.providerId == 'google.com') ??
            false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: () => _openPhoneAuth(PhoneAuthMode.link),
          icon: const Icon(Icons.phone_outlined),
          label: Text(l10n.profileLinkPhone),
        ),
        // Recovery email nudge — only for phone-only users, max 2 prompts
        if (_isPhoneUser && !hasEmailOrGoogle && _phoneOnlyPrompted < 2) ...[
          const SizedBox(height: 8),
          Card(
            color: colorScheme.secondaryContainer,
            child: ListTile(
              leading: Icon(Icons.email_outlined,
                  color: colorScheme.onSecondaryContainer),
              title: Text(
                l10n.profileAddRecoveryEmail,
                style: TextStyle(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                l10n.profileAddRecoveryEmailSubtitle,
                style:
                    TextStyle(color: colorScheme.onSecondaryContainer, fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const OptionalEmailPromptScreen(),
                      ),
                    ),
                    child: Text(l10n.optionalEmailAddButton),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _dismissRecoveryEmailNudge,
                    tooltip: l10n.optionalEmailSkip,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
```

- [ ] **Step 9: Remove `_phoneController` from `dispose()`**

Find and remove from `dispose()`:

```dart
    _phoneController.dispose();
```

- [ ] **Step 10: Analyze**

```bash
flutter analyze lib/screens/profile/profile_screen.dart lib/core/services/profile_service.dart
```

Expected: 0 errors.

- [ ] **Step 11: Run all tests**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 12: Commit**

```bash
git add lib/screens/profile/profile_screen.dart lib/core/services/profile_service.dart
git commit -m "feat(phone-auth): update ProfileScreen with auth-driven phone field and phone delete re-auth"
```

---

## Final verification

- [ ] **Run full test suite**

```bash
flutter test
```

Expected: all tests pass, including the new `auth_service_phone_gate_test.dart`.

- [ ] **Run full analyze**

```bash
flutter analyze
```

Expected: 0 errors (pre-existing info-level warnings are acceptable).

- [ ] **Manual smoke test checklist**
  - [ ] Login screen shows three buttons: Google, Email, Phone Number
  - [ ] Tapping Phone Number opens `PhoneAuthScreen`, sends OTP (use Firebase test numbers in console to avoid real SMS during dev)
  - [ ] New phone user is prompted for display name then optional email
  - [ ] Returning phone user goes straight to home
  - [ ] In profile, email/Google user sees "Link phone number" button
  - [ ] After linking, profile shows verified number + "Change" action
  - [ ] Phone-only user sees "Add recovery email" card in profile (dismissed after 2 taps)
  - [ ] Delete account flow for phone user triggers OTP re-auth

