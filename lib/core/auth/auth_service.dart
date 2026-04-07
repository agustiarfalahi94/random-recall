import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../sync/sync_service.dart';

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Stream of user authentication state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Returns the current user if logged in.
  User? get currentUser => _auth.currentUser;

  /// Sign in with Google.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await _ensureUserDocument(userCredential.user!);
      }
      return userCredential;
    } catch (e) {
      debugPrint('AuthService: Google Sign-In failed: $e');
      rethrow;
    }
  }

  /// Sign in with Email and Password.
  Future<UserCredential> signInWithEmail(String email, String password) async {
    final userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    if (userCredential.user != null) {
      await _ensureUserDocument(userCredential.user!);
    }
    return userCredential;
  }

  /// Sign up with Email and Password.
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    if (userCredential.user != null) {
      await _ensureUserDocument(userCredential.user!);
    }
    return userCredential;
  }

  /// Sends a password reset email.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Sign out from all providers.
  Future<void> signOut() async {
    try {
      final user = currentUser;
      if (user != null) {
        // 1. Perform a final backup so data is safe in the cloud
        await SyncService.instance.performBackup();
      }

      // Stop cloud sync listeners first
      SyncService.instance.stopRealtimeSync();
      await _googleSignIn.signOut();
      await _auth.signOut();
      
      // Clear local data so the next user starts fresh
      await DatabaseHelper.instance.clearAllData();
      // Also clear local flags so the next user sees onboarding
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); 
    } catch (e) {
      debugPrint('AuthService: Sign-out error: $e');
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
