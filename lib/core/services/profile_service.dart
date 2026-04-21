import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._internal();

  factory ProfileService() {
    return _instance;
  }

  ProfileService._internal();

  static ProfileService get instance => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Update user profile in Firestore and Firebase Auth displayName
  Future<void> updateUserProfile({
    required String name,
    String? phoneNumber,
  }) async {
    try {
      final user = _auth.currentUser;
      final userId = user?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // Update Firebase Auth displayName
      await user!.updateDisplayName(name);

      // Update Firestore
      final updateData = {
        'name': name,
        'phone_number': phoneNumber,
        'updated_at': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(userId).update(updateData);
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

  /// Helper: Delete all user data from Firestore
  Future<void> _deleteUserData(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).delete();
    } catch (e) {
      debugPrint('ProfileService: Delete Firestore data failed: $e');
      rethrow;
    }
  }
}
