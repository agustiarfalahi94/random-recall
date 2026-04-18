import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../services/analytics_service.dart';
import '../sync/sync_service.dart';
import '../plan/subscription_service.dart';

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static bool _pendingLocalCleanup =
      false; // Flag to trigger one-time local data cleanup

  /// Stream of user authentication state changes.
  /// userChanges() notifies the UI whenever the user is reloaded (e.g., email verified).
  /// Stored as a lazy field (not a getter) so StreamBuilder always gets the same
  /// instance and never misses emissions due to re-subscription on rebuild.
  late final Stream<User?> authStateChanges = _auth.userChanges();

  /// Returns the current user if logged in.
  User? get currentUser => _auth.currentUser;

  /// Sign in with Google.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

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
    } catch (e) {
      debugPrint('AuthService: Google Sign-In failed: $e');
      rethrow;
    }
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

  /// Performs RevenueCat login and Cloud Restore only for verified users.
  Future<void> initializeUserSession() async {
    final user = currentUser;
    if (user == null || !user.emailVerified) return;

    await SubscriptionService.instance.logIn(user.uid);
    await SyncService.instance.performRestore(
      force: true,
      isInitialLogin: true,
    );
  }

  /// Force-reloads the user from Firebase servers.
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  /// Sends a password reset email after verifying the user exists in Auth and Firestore.
  Future<void> sendPasswordResetEmail(String email) async {
    // 1. Check if email exists in Firebase Authentication
    final methods = await _auth.fetchSignInMethodsForEmail(email);
    if (methods.isEmpty) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No account found with this email address.',
      );
    }

    // 2. Check if user document exists in Firestore database
    final userQuery = await _db
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (userQuery.docs.isEmpty) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'User record not found in database.',
      );
    }

    // 3. Trigger Firebase reset email
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

      // 1. Attempt final backup (swallow errors so we don't block signout)
      if (user != null) {
        await SyncService.instance
            .performBackup(force: true)
            .catchError((e) => debugPrint('Signout backup failed: $e'));
      }


      // 3. Subscription and Google logout
      SubscriptionService.instance.logOut().catchError(
        (e) => debugPrint('RevenueCat logout failed: $e'),
      );
      await _googleSignIn.signOut().catchError((_) => null);

      // 4. CRITICAL: Clear local data so the next user starts fresh
      await DatabaseHelper.instance.clearAllData();

      // 5. Selective cleanup: Clear app-specific preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('onboarding_complete');
      await prefs.remove('timer_streak_days');
      await prefs.remove('timer_streak_last_date');
      await prefs.remove('timer_streak_bonus_questions');

      // 6. UI HOOK: Allow the caller to dismiss dialogs/sheets before the
      // root widget tree swaps, which prevents crashes on certain Android devices.
      if (onBeforeFinalSignOut != null) {
        await onBeforeFinalSignOut();
      }

      debugPrint('AuthService: Performing Firebase signOut...');
      // 7. Track logout and detach the user identity before Firebase tears down the session
      await AnalyticsService.instance.trackLogout().catchError((_) {});
      await AnalyticsService.instance.reset().catchError((_) {});
      // 8. FINAL STEP: Sign out of Firebase to trigger the UI switch in main.dart
      await _auth.signOut();
    } catch (e) {
      debugPrint('AuthService: Sign-out error: $e');
    } finally {
      _isSigningOut = false;
    }
  }

  /// Ensures a user document exists in Firestore.
  Future<void> _ensureUserDocument(User user) async {
    final userDoc = _db.collection('users').doc(user.uid);
    final doc = await userDoc.get();

    if (!doc.exists) {
      await userDoc.set({
        'email': user.email,
        'is_premium': false,
        'created_at': FieldValue.serverTimestamp(),
      });
    }
  }
}
