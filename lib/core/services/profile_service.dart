import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../streak/streak_service.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._internal();

  factory ProfileService() {
    return _instance;
  }

  ProfileService._internal();

  static ProfileService get instance => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Update user profile in Firestore and Firebase Auth displayName.
  /// Phone number is managed via auth linking — not updated here.
  Future<void> updateUserProfile({required String name}) async {
    try {
      final user = _auth.currentUser;
      final userId = user?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // Update Firebase Auth displayName
      await user!.updateDisplayName(name);

      // Update Firestore
      await _firestore.collection('users').doc(userId).update({
        'name': name,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('ProfileService: Firestore update failed: $e');
      rethrow;
    }
  }

  /// Get current user profile from Firestore
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data();
    } catch (e) {
      debugPrint('ProfileService: Fetch profile failed: $e');
      return null;
    }
  }

  /// Change password for email users
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('User not authenticated or using social login');
      }

      // Re-authenticate with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);
    } catch (e) {
      debugPrint('ProfileService: Change password failed: $e');
      rethrow;
    }
  }

  /// Re-authenticate user and delete account (email)
  Future<void> deleteAccountEmailAuth(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('User not authenticated');
      }

      // Re-authenticate
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Delete Firestore data
      await _deleteUserData(user.uid);

      // Delete auth account
      await user.delete();
    } catch (e) {
      debugPrint('ProfileService: Delete account (email) failed: $e');
      rethrow;
    }
  }

  /// Re-authenticate user and delete account (Google)
  Future<void> deleteAccountGoogleAuth() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Re-authenticate with Google (this will trigger Google sign-in)
      final googleProvider = GoogleAuthProvider();
      await user.reauthenticateWithProvider(googleProvider);

      // Delete Firestore data
      await _deleteUserData(user.uid);

      // Delete auth account
      await user.delete();
    } catch (e) {
      debugPrint('ProfileService: Delete account (Google) failed: $e');
      rethrow;
    }
  }

  /// Re-authenticates with a fresh OTP then deletes the account.
  /// [verificationId] and [smsCode] come from a fresh verifyPhoneNumber call
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

  /// Helper: Delete all user data from Firestore and local storage.
  /// Firestore does not cascade-delete subcollections when a parent document
  /// is deleted, so each subcollection must be explicitly cleared first.
  Future<void> _deleteUserData(String userId) async {
    try {
      final userDoc = _firestore.collection('users').doc(userId);

      // Delete all documents in each subcollection before removing the root doc.
      // Uses batched deletes (max 500 writes per batch) to handle large datasets.
      await _deleteSubcollection(userDoc.collection('questions'));
      await _deleteSubcollection(userDoc.collection('categories'));
      await _deleteSubcollection(userDoc.collection('score_records'));
      await _deleteSubcollection(userDoc.collection('private'));

      await userDoc.delete();

      // Clear local SQLite data so the next user on this device starts fresh.
      await DatabaseHelper.instance.clearAllData();

      // Clear all app-specific SharedPreferences including challenge-mode state.
      // Use direct prefs removal rather than StreakService.resetChallenge() to
      // avoid triggering _saveToFirestore() on the already-deleted Firestore doc.
      final prefs = await SharedPreferences.getInstance();
      for (final key in const [
        'challenge_mode_active', 'challenge_mode_start_date',
        'challenge_mode_day', 'challenge_duration',
        'challenge_locked_frequency', 'challenge_locked_active_days',
        'challenge_locked_random_anytime', 'challenge_locked_timer_seconds',
        'challenge_last_answer_date',
        'total_7day_completed', 'total_14day_completed',
        'challenge_badge_unlocked', 'highest_title',
        'onboarding_complete',
        'timer_streak_days', 'timer_streak_last_date',
        'timer_streak_bonus_questions',
        'is_premium', 'bonus_categories',
      ]) {
        await prefs.remove(key);
      }
    } catch (e) {
      debugPrint('ProfileService: Delete user data failed: $e');
      rethrow;
    }
  }

  Future<void> _deleteSubcollection(CollectionReference ref) async {
    const batchSize = 400;
    QuerySnapshot snapshot;
    do {
      snapshot = await ref.limit(batchSize).get();
      if (snapshot.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } while (snapshot.docs.length == batchSize);
  }
}
