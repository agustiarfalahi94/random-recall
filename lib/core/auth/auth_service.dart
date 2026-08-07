import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../notifications/notification_service.dart';
import '../services/analytics_service.dart';
import '../streak/streak_service.dart';
import '../sync/sync_service.dart';
import '../plan/subscription_service.dart';

/// Thrown when Google Sign-In hits an email that is already registered to an
/// email/password account. Carries the Google credential so the UI can link
/// the two providers after verifying the password.
class AccountExistsException implements Exception {
  final String email;
  final AuthCredential googleCredential;
  const AccountExistsException({
    required this.email,
    required this.googleCredential,
  });

  @override
  String toString() => 'AccountExistsException(email: $email)';
}

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // google_sign_in 7.x requires initialize() to be called exactly once before
  // any other method.
  bool _googleSignInInitialized = false;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleSignInInitialized) return;
    // CRITICAL: the v7 Credential Manager flow REQUIRES the server client ID
    // passed explicitly — it no longer reads it from google-services.json.
    // Without it the plugin throws missingServerClientId and sign-in fails.
    // Mirrors oauth_client type 3 in android/app/google-services.json.
    await _googleSignIn.initialize(
      serverClientId:
          '737631418905-koc163grfi8e1v5rmusnlii4cvjm8b02.apps.googleusercontent.com',
    );
    _googleSignInInitialized = true;
  }

  /// Stream of user authentication state changes.
  /// userChanges() notifies the UI whenever the user is reloaded (e.g., email verified).
  /// Stored as a lazy field (not a getter) so StreamBuilder always gets the same
  /// instance and never misses emissions due to re-subscription on rebuild.
  late final Stream<User?> authStateChanges = _auth.userChanges();

  /// Returns the current user if logged in.
  User? get currentUser => _auth.currentUser;

  /// A user is "verified" if they proved ownership of an email or phone.
  /// Phone users are verified by OTP; email users by verification email.
  static bool isVerified({
    required bool hasEmailVerified,
    required bool hasPhone,
  }) => hasEmailVerified || hasPhone;

  static bool isVerifiedUser(User? user) =>
      user != null &&
      isVerified(
        hasEmailVerified: user.emailVerified,
        hasPhone: user.phoneNumber != null,
      );

  /// Sign in with Google.
  Future<UserCredential?> signInWithGoogle() async {
    AuthCredential? credential;
    try {
      await _ensureGoogleInitialized();
      final GoogleSignInAccount googleUser;
      try {
        googleUser = await _googleSignIn.authenticate();
      } on GoogleSignInException catch (e) {
        // Only user-initiated cancellations are expected non-results.
        // Everything else must surface so the UI can show what went wrong.
        if (e.code == GoogleSignInExceptionCode.canceled ||
            e.code == GoogleSignInExceptionCode.interrupted ||
            e.code == GoogleSignInExceptionCode.uiUnavailable) {
          debugPrint('AuthService: Google Sign-In cancelled (${e.code.name})');
          return null;
        }
        debugPrint('AuthService: Google Sign-In failed: ${e.code.name}: $e');
        rethrow;
      }

      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        debugPrint('AuthService: Google Sign-In returned no ID token');
        throw StateError('Google Sign-In returned no ID token');
      }
      credential = GoogleAuthProvider.credential(idToken: idToken);

      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await _ensureUserDocument(userCredential.user!);
        await initializeUserSession();
        AnalyticsService.instance.trackLogin(method: 'google').ignore();
        AnalyticsService.instance
            .identify(
              userCredential.user!.uid,
              email: userCredential.user!.email,
            )
            .ignore();
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        // The email is already registered to an email/password account.
        // Surface a friendly exception carrying the Google credential so the
        // UI can verify the password and link the two providers.
        debugPrint('AuthService: Google email already registered: ${e.email}');
        throw AccountExistsException(
          email: e.email ?? '',
          googleCredential: e.credential ?? credential!,
        );
      }
      debugPrint('AuthService: Google Sign-In failed: $e');
      rethrow;
    } catch (e) {
      debugPrint('AuthService: Google Sign-In failed: $e');
      rethrow;
    }
  }

  /// After a Google sign-in collision ([AccountExistsException]), proves
  /// ownership of the existing email/password account and links the Google
  /// credential so both providers sign in to the same account.
  Future<void> linkGoogleToExistingAccount({
    required String email,
    required String password,
    required AuthCredential googleCredential,
  }) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = userCredential.user;
    if (user == null) throw Exception('Sign-in returned no user');
    await user.linkWithCredential(googleCredential);
    await user.reload();
    await _ensureUserDocument(user);
    await initializeUserSession();
    AnalyticsService.instance.trackLogin(method: 'google').ignore();
    AnalyticsService.instance.identify(user.uid, email: user.email).ignore();
  }

  /// Sign in with Email and Password.
  Future<UserCredential> signInWithEmail(String email, String password) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (userCredential.user != null) {
      // CRITICAL: Force a reload from server to catch accounts deleted in Console
      await userCredential.user!.reload();
      await _ensureUserDocument(userCredential.user!);

      // Only initialize data if verified
      if (_auth.currentUser != null && _auth.currentUser!.emailVerified) {
        await initializeUserSession();
        AnalyticsService.instance.trackLogin(method: 'email').ignore();
        AnalyticsService.instance
            .identify(
              userCredential.user!.uid,
              email: userCredential.user!.email,
            )
            .ignore();
      }
    }
    return userCredential;
  }

  /// Sign up with Email and Password.
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (userCredential.user != null) {
      // Ensure we have the latest state before sending verification
      await userCredential.user!.reload();
      await userCredential.user!.sendEmailVerification();
      await _ensureUserDocument(userCredential.user!);
    }
    return userCredential;
  }

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
      AnalyticsService.instance.identify(userCredential.user!.uid).ignore();
    }
    return userCredential;
  }

  /// Links a phone credential to the currently signed-in account.
  /// Use this when an existing email/Google user wants to add their phone.
  Future<void> linkPhoneNumber(String verificationId, String smsCode) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    await user.linkWithCredential(credential);
    await user.reload();
    await _db.collection('users').doc(user.uid).update({
      'phone_number': _auth.currentUser?.phoneNumber,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Changes the phone credential on the currently signed-in account.
  /// Unlinks the old phone provider then links the new credential.
  Future<void> changePhoneNumber(String verificationId, String smsCode) async {
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

  /// Performs RevenueCat login and Cloud Restore only for verified users.
  /// Ensures user document exists (defensive — normally created at signup).
  Future<void> initializeUserSession() async {
    final user = currentUser;
    // Phone users are verified by OTP — no emailVerified check needed for them.
    if (user == null || !isVerifiedUser(user)) return;

    await _ensureUserDocument(user);
    await SubscriptionService.instance.logIn(user.uid);
    await SyncService.instance.performRestore(
      force: true,
      isInitialLogin: true,
    );
    // Sync streak/challenge state from Firestore now that the user is
    // authenticated. StreakService.initialize() only loads SharedPreferences
    // (no Firestore) so it is safe to call at startup without a user.
    // loadFromCloud() is the auth-required half — called here after login.
    await StreakService.instance.loadFromCloud();

    // If a challenge was active, the locked notification settings have been
    // written back to SharedPreferences by loadFromCloud(). Reschedule now so
    // notifications fire correctly on a fresh install or device switch.
    if (StreakService.instance.isChallengeActive) {
      await NotificationService.instance.scheduleNotifications();
    }
  }

  /// Force-reloads the user from Firebase servers.
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  /// Sends a password reset email.
  /// Per Firebase's email enumeration protection guidance, we do not check
  /// whether the email is registered before sending — the response is always
  /// "if an account exists you'll receive a link", which prevents attackers
  /// from probing which emails are registered.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  bool _isSigningOut = false;

  /// Sign out from all providers.
  Future<void> signOut({
    FutureOr<void> Function()? onBeforeFinalSignOut,
  }) async {
    if (_isSigningOut) return;
    _isSigningOut = true;

    try {
      final user = currentUser;

      // 1. Attempt final backup — 20 s budget. A slow connection must not
      //    silently lose the user's latest scores.
      var backedUp = false;
      if (user != null) {
        backedUp = await SyncService.instance
            .performBackup(force: true)
            .timeout(
              const Duration(seconds: 20),
              onTimeout: () {
                debugPrint('AuthService: Signout backup timed out');
                return false;
              },
            )
            .catchError((e) {
              debugPrint('Signout backup failed: $e');
              return false;
            });
      }

      // 2. Subscription and Google logout
      SubscriptionService.instance.logOut().catchError(
        (e) => debugPrint('RevenueCat logout failed: $e'),
      );
      await _googleSignIn.signOut().catchError((_) => null);

      // 3. Clear local data so the next user starts fresh — but ONLY when the
      //    backup succeeded (or the local data belongs to a different account).
      //    On a failed backup, keep the data: the next login uploads it before
      //    the restore wipes it (SyncService._preWipeBackupIfLocalDataBelongsTo).
      final prefs = await SharedPreferences.getInstance();
      final localOwner = prefs.getString(SyncService.localDataOwnerKey);
      final belongsToUser = localOwner == null || localOwner == user?.uid;
      if (backedUp || !belongsToUser) {
        await DatabaseHelper.instance.clearAllData();
        await prefs.remove(SyncService.localDataOwnerKey);
      } else {
        debugPrint(
          'AuthService: Backup failed — keeping local data for next login',
        );
      }

      // 4. Clear all challenge-mode state so a new account on this device
      //    does not inherit the previous user's challenge session.
      await StreakService.instance.resetChallenge();

      // 5. Selective cleanup: clear all user-specific preferences
      for (final key in const [
        'onboarding_complete',
        'timer_streak_days',
        'timer_streak_last_date',
        'timer_streak_bonus_questions',
        'total_7day_completed',
        'total_14day_completed',
        'challenge_badge_unlocked',
        'highest_title',
        'is_premium',
        'bonus_categories',
        'notif_schedule_mirror',
      ]) {
        await prefs.remove(key);
      }
    } catch (e) {
      // Log errors but never let them block the critical sign-out steps below.
      debugPrint('AuthService: Sign-out cleanup error (non-fatal): $e');
    } finally {
      // 5. UI HOOK — always dismiss dialogs/sheets before Firebase tears down
      //    the session, regardless of any cleanup errors above.
      if (onBeforeFinalSignOut != null) {
        try {
          await onBeforeFinalSignOut();
        } catch (e) {
          debugPrint('AuthService: onBeforeFinalSignOut error: $e');
        }
      }

      debugPrint('AuthService: Performing Firebase signOut...');
      // 6. Track logout — fire-and-forget, don't block on it.
      AnalyticsService.instance.trackLogout().catchError((_) {});
      AnalyticsService.instance.reset().catchError((_) {});

      // 7. FINAL STEP: always sign out of Firebase so authStateChanges emits
      //    null and the StreamBuilder switches to LoginScreen.
      try {
        await _auth.signOut();
      } catch (e) {
        debugPrint('AuthService: Firebase signOut error: $e');
      }

      _isSigningOut = false;
    }
  }

  /// Ensures a user document exists in Firestore.
  Future<void> _ensureUserDocument(User user) async {
    final userDoc = _db.collection('users').doc(user.uid);
    final doc = await userDoc.get();

    if (!doc.exists) {
      await userDoc.set({
        if (user.email != null) 'email': user.email,
        if (user.phoneNumber != null) 'phone_number': user.phoneNumber,
        'is_premium': false,
        'created_at': FieldValue.serverTimestamp(),
      });
    }
  }
}
