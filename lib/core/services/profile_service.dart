import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
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
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  /// Compress and resize image to 512x512 at 80% JPEG quality
  Future<File> compressImage(File imageFile) async {
    try {
      // Read image
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) throw Exception('Failed to decode image');

      // Resize to 512x512
      final resized = img.copyResize(
        image,
        width: 512,
        height: 512,
        interpolation: img.Interpolation.linear,
      );

      // Compress to 80% quality and save
      final compressed = img.encodeJpg(resized, quality: 80);

      // Save to temporary directory
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/profile_picture_temp.jpg');
      await tempFile.writeAsBytes(compressed);

      return tempFile;
    } catch (e) {
      debugPrint('ProfileService: Image compression failed: $e');
      rethrow;
    }
  }

  /// Pick image from camera
  Future<File?> pickImageFromCamera() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100, // Original quality before compression
      );
      return pickedFile != null ? File(pickedFile.path) : null;
    } catch (e) {
      debugPrint('ProfileService: Camera pick failed: $e');
      return null;
    }
  }

  /// Pick image from gallery
  Future<File?> pickImageFromGallery() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100, // Original quality before compression
      );
      return pickedFile != null ? File(pickedFile.path) : null;
    } catch (e) {
      debugPrint('ProfileService: Gallery pick failed: $e');
      return null;
    }
  }

  /// Upload image to Firebase Storage and return download URL
  Future<String> uploadProfilePicture(File imageFile) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final storageRef = _storage.ref().child('users/$userId/profile_picture.jpg');
      await storageRef.putFile(imageFile);
      final downloadUrl = await storageRef.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      debugPrint('ProfileService: Upload to Storage failed: $e');
      rethrow;
    }
  }

  /// Update user profile in Firestore
  Future<void> updateUserProfile({
    required String name,
    String? phoneNumber,
    String? profilePictureUrl,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final updateData = {
        'name': name,
        'phone_number': phoneNumber,
        if (profilePictureUrl != null) 'profile_picture_url': profilePictureUrl,
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

      // Delete Firebase Storage profile picture
      try {
        await _storage.ref().child('users/${user.uid}/profile_picture.jpg').delete();
      } catch (_) {
        // File may not exist, ignore
      }

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

      // Delete Firebase Storage profile picture
      try {
        await _storage.ref().child('users/${user.uid}/profile_picture.jpg').delete();
      } catch (_) {
        // File may not exist, ignore
      }

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
