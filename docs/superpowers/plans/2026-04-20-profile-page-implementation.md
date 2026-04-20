# Profile Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a profile page as the 4th tab in the bottom navigation bar with editable fields, profile picture management, and account controls (change password, delete account).

**Architecture:**
- New ProfileService handles image compression, Firestore sync, and Firebase operations
- New ProfileScreen UI displays user info with edit capabilities
- Navigation bar extended from 3 to 4 tabs (Home, Questions, Analytics, Profile)
- Image compression/caching strategy: resize to 512×512px, compress to 80% JPEG quality

**Tech Stack:**
- Flutter (image_picker, cached_network_image)
- Firebase Storage, Firestore, Authentication
- SQLite/SharedPreferences for local caching

---

## File Structure

### New Files
- `lib/core/services/profile_service.dart` — Business logic (image handling, Firestore sync, auth operations)
- `lib/screens/profile/profile_screen.dart` — UI screen with editable fields

### Modified Files
- `lib/screens/home/home_screen.dart` — Add 4th navigation destination
- `pubspec.yaml` — Add `image_picker`, `cached_network_image` dependencies
- `lib/l10n/app_en.arb` — Add 18 profile-related strings
- `lib/l10n/app_id.arb` — Add 18 profile-related strings (Indonesian)
- `CHANGELOG.md` — Document v0.9.0 feature

---

## Task 1: Add Dependencies

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Open pubspec.yaml and locate dependencies section**

- [ ] **Step 2: Add image_picker and cached_network_image packages**

Add these lines to the `dependencies:` section (alphabetically ordered):

```yaml
dependencies:
  # ... existing dependencies ...
  cached_network_image: ^10.0.0
  image_picker: ^1.0.0
  # ... rest of dependencies ...
```

- [ ] **Step 3: Run flutter pub get**

```bash
cd /Users/lilianyoctoria/Documents/random_recall
flutter pub get
```

Expected: No errors, packages added to pubspec.lock.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "v0.9.0: add image_picker and cached_network_image dependencies for profile page"
```

---

## Task 2: Add Localization Strings

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_id.arb`

- [ ] **Step 1: Add English localization strings to app_en.arb**

Open `lib/l10n/app_en.arb` and add these key-value pairs inside the JSON object:

```json
{
  "profilePageTitle": "Profile",
  "profilePictureLabel": "Profile Picture",
  "nameLabel": "Name",
  "phoneLabel": "Phone Number",
  "emailLabel": "Email",
  "subscriptionStatusLabel": "Subscription Status",
  "subscriptionStatusPremium": "Premium",
  "subscriptionStatusFree": "Free",
  "changePasswordButton": "Change Password",
  "deleteAccountButton": "Delete Account",
  "deleteAccountWarning": "Are you sure? Account deletion is permanent. All your data will be deleted.",
  "deleteAccountConfirm": "Delete Account",
  "deleteAccountCancel": "Cancel",
  "profilePictureSourceCamera": "Take Photo",
  "profilePictureSourceGallery": "Choose from Gallery",
  "profilePictureUpdated": "Profile picture updated",
  "profilePictureUpdateFailed": "Failed to update profile picture",
  "profileUpdateSuccess": "Profile updated successfully",
  "profileUpdateFailed": "Failed to update profile",
  "passwordChangedSuccess": "Password changed successfully",
  "passwordChangedFailed": "Failed to change password",
  "accountDeletedSuccess": "Account deleted successfully",
  "accountDeleteFailed": "Failed to delete account",
  "googleAccountLabel": "Google Account",
  "emailAccountLabel": "Email"
}
```

- [ ] **Step 2: Add Indonesian localization strings to app_id.arb**

Open `lib/l10n/app_id.arb` and add these key-value pairs:

```json
{
  "profilePageTitle": "Profil",
  "profilePictureLabel": "Foto Profil",
  "nameLabel": "Nama",
  "phoneLabel": "Nomor Telepon",
  "emailLabel": "Email",
  "subscriptionStatusLabel": "Status Langganan",
  "subscriptionStatusPremium": "Premium",
  "subscriptionStatusFree": "Gratis",
  "changePasswordButton": "Ubah Kata Sandi",
  "deleteAccountButton": "Hapus Akun",
  "deleteAccountWarning": "Apakah Anda yakin? Penghapusan akun bersifat permanen. Semua data Anda akan dihapus.",
  "deleteAccountConfirm": "Hapus Akun",
  "deleteAccountCancel": "Batal",
  "profilePictureSourceCamera": "Ambil Foto",
  "profilePictureSourceGallery": "Pilih dari Galeri",
  "profilePictureUpdated": "Foto profil diperbarui",
  "profilePictureUpdateFailed": "Gagal memperbarui foto profil",
  "profileUpdateSuccess": "Profil berhasil diperbarui",
  "profileUpdateFailed": "Gagal memperbarui profil",
  "passwordChangedSuccess": "Kata sandi berhasil diubah",
  "passwordChangedFailed": "Gagal mengubah kata sandi",
  "accountDeletedSuccess": "Akun berhasil dihapus",
  "accountDeleteFailed": "Gagal menghapus akun",
  "googleAccountLabel": "Akun Google",
  "emailAccountLabel": "Email"
}
```

- [ ] **Step 3: Run flutter gen-l10n**

```bash
flutter gen-l10n
```

Expected: No errors, AppLocalizations updated with new strings.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_id.arb
git commit -m "v0.9.0: add profile page localization strings"
```

---

## Task 3: Create ProfileService

**Files:**
- Create: `lib/core/services/profile_service.dart`

- [ ] **Step 1: Create profile_service.dart with image compression utility**

Create file `lib/core/services/profile_service.dart`:

```dart
import 'dart:io';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

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
```

- [ ] **Step 2: Verify ProfileService compiles**

```bash
cd /Users/lilianyoctoria/Documents/random_recall
flutter analyze lib/core/services/profile_service.dart
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/core/services/profile_service.dart
git commit -m "v0.9.0: add ProfileService with image compression and Firebase operations"
```

---

## Task 4: Create ProfileScreen UI

**Files:**
- Create: `lib/screens/profile/profile_screen.dart`

- [ ] **Step 1: Create profile_screen.dart with main profile page**

Create file `lib/screens/profile/profile_screen.dart`:

```dart
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:random_recall/core/services/profile_service.dart';
import 'package:random_recall/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  String _profilePictureUrl = '';
  bool _isEmailUser = false;
  bool _isPremium = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Load from Firestore
      final profile = await _profileService.getUserProfile();
      final prefs = await SharedPreferences.getInstance();
      final isPremium = prefs.getBool('is_premium') ?? false;

      setState(() {
        _nameController.text = profile?['name'] ?? '';
        _phoneController.text = profile?['phone_number'] ?? '';
        _profilePictureUrl = profile?['profile_picture_url'] ?? '';
        _isEmailUser = user.providerData.any((p) => p.providerId == 'password');
        _isPremium = isPremium;
      });
    } catch (e) {
      debugPrint('ProfileScreen: Load profile failed: $e');
    }
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.nameLabel)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _profileService.updateUserProfile(
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.profileUpdateSuccess),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.profileUpdateFailed),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleProfilePictureEdit() async {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: Text(l10n.profilePictureSourceCamera),
            onTap: () async {
              Navigator.pop(context);
              await _pickAndUploadImage(source: ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.image),
            title: Text(l10n.profilePictureSourceGallery),
            onTap: () async {
              Navigator.pop(context);
              await _pickAndUploadImage(source: ImageSource.gallery);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadImage({required ImageSource source}) async {
    final l10n = AppLocalizations.of(context)!;

    try {
      setState(() => _isLoading = true);

      File? imageFile;
      if (source == ImageSource.camera) {
        imageFile = await _profileService.pickImageFromCamera();
      } else {
        imageFile = await _profileService.pickImageFromGallery();
      }

      if (imageFile == null) return;

      // Compress image
      final compressedFile = await _profileService.compressImage(imageFile);

      // Upload to Firebase Storage
      final url = await _profileService.uploadProfilePicture(compressedFile);

      // Update Firestore
      await _profileService.updateUserProfile(
        name: _nameController.text.trim(),
        profilePictureUrl: url,
      );

      setState(() => _profilePictureUrl = url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profilePictureUpdated)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.profilePictureUpdateFailed)),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _changePassword() async {
    final l10n = AppLocalizations.of(context)!;
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.changePasswordButton),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              decoration: InputDecoration(hintText: 'Current Password'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: InputDecoration(hintText: 'New Password'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(hintText: 'Confirm Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.deleteAccountCancel),
          ),
          FilledButton(
            onPressed: () async {
              if (newPasswordController.text != confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match')),
                );
                return;
              }

              try {
                await _profileService.changePassword(
                  currentPassword: currentPasswordController.text,
                  newPassword: newPasswordController.text,
                );

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.passwordChangedSuccess)),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.passwordChangedFailed)),
                  );
                }
              }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final l10n = AppLocalizations.of(context)!;

    // First warning dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteAccountButton),
        content: Text(l10n.deleteAccountWarning),
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

    if (confirmed != true) return;

    // Second step: Re-authentication
    if (_isEmailUser) {
      await _reauthenticateEmail();
    } else {
      await _reauthenticateGoogle();
    }
  }

  Future<void> _reauthenticateEmail() async {
    final l10n = AppLocalizations.of(context)!;
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Password'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Enter your password'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.deleteAccountCancel),
          ),
          FilledButton(
            onPressed: () async {
              try {
                Navigator.pop(context);
                setState(() => _isLoading = true);

                await _profileService.deleteAccountEmailAuth(
                  passwordController.text,
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.accountDeletedSuccess)),
                  );
                  // Navigate to login or home
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.accountDeleteFailed)),
                  );
                }
              } finally {
                setState(() => _isLoading = false);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _reauthenticateGoogle() async {
    final l10n = AppLocalizations.of(context)!;

    try {
      setState(() => _isLoading = true);

      await _profileService.deleteAccountGoogleAuth();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.accountDeletedSuccess)),
        );
        // Navigate to login or home
        Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.accountDeleteFailed)),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profilePageTitle)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Profile Picture
                  Center(
                    child: GestureDetector(
                      onTap: _handleProfilePictureEdit,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundImage: _profilePictureUrl.isNotEmpty
                            ? CachedNetworkImageProvider(_profilePictureUrl)
                            : null,
                        child: _profilePictureUrl.isEmpty
                            ? const Icon(Icons.person, size: 60)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Name field
                  TextField(
                    controller: _nameController,
                    maxLength: 50,
                    decoration: InputDecoration(
                      labelText: l10n.nameLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

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

                  // Email (read-only)
                  TextField(
                    controller: TextEditingController(text: _auth.currentUser?.email ?? ''),
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: l10n.emailLabel,
                      hintText: _isEmailUser
                          ? l10n.emailAccountLabel
                          : l10n.googleAccountLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Subscription status
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.subscriptionStatusLabel),
                        Chip(
                          label: Text(
                            _isPremium
                                ? l10n.subscriptionStatusPremium
                                : l10n.subscriptionStatusFree,
                          ),
                          backgroundColor: _isPremium ? Colors.green : Colors.grey,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Update button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _updateProfile,
                      child: const Text('Update Profile'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Change password (email users only)
                  if (_isEmailUser)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _changePassword,
                        child: Text(l10n.changePasswordButton),
                      ),
                    ),
                  if (_isEmailUser) const SizedBox(height: 16),

                  // Delete account button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _deleteAccount,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: Text(l10n.deleteAccountButton),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}

enum ImageSource { camera, gallery }
```

- [ ] **Step 2: Verify ProfileScreen compiles**

```bash
flutter analyze lib/screens/profile/profile_screen.dart
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/profile/profile_screen.dart
git commit -m "v0.9.0: add ProfileScreen UI with editable fields and account controls"
```

---

## Task 5: Update Home Screen Navigation

**Files:**
- Modify: `lib/screens/home/home_screen.dart`

- [ ] **Step 1: Import ProfileScreen at top of home_screen.dart**

Add after existing imports:

```dart
import 'package:random_recall/screens/profile/profile_screen.dart';
```

- [ ] **Step 2: Update body list to include ProfileScreen**

Find the section:

```dart
body: [
  _HomeTab(),
  const QuestionsListScreen(),
  const AnalyticsScreen(),
][_currentIndex],
```

Change to:

```dart
body: [
  _HomeTab(),
  const QuestionsListScreen(),
  const AnalyticsScreen(),
  const ProfileScreen(),
][_currentIndex],
```

- [ ] **Step 3: Add Profile NavigationDestination**

Find the NavigationDestination list and add Profile destination after Analytics:

```dart
NavigationDestination(
  icon: const Icon(Icons.person_outlined),
  selectedIcon: const Icon(Icons.person_rounded),
  label: l10n.profilePageTitle,
),
```

- [ ] **Step 4: Verify home_screen compiles**

```bash
flutter analyze lib/screens/home/home_screen.dart
```

Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/home/home_screen.dart
git commit -m "v0.9.0: add Profile tab to bottom navigation bar"
```

---

## Task 6: Update CHANGELOG and Version

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Add v0.9.0 entry to CHANGELOG**

Add at the top after the header:

```markdown
## [0.9.0] — 2026-04-20

### Added
- **Profile Page** — New 4th tab in bottom navigation bar with user profile management.
  - Editable name and phone number fields (synced to Firestore)
  - Profile picture editing with camera/gallery picker (compressed 512×512, 80% JPEG quality, stored in Firebase Storage)
  - View email address (read-only, from login provider)
  - Subscription status display (Free/Premium badge)
  - Change password button (email users only, hidden for Google sign-in)
  - Delete account button with re-authentication flow (supports both email and Google authentication methods)

---
```

- [ ] **Step 2: Verify CHANGELOG entry**

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md
git commit -m "v0.9.0: add profile page feature to CHANGELOG"
```

---

## Task 7: Manual Testing

- [ ] **Step 1: Run flutter clean and get dependencies**

```bash
flutter clean && flutter pub get
```

- [ ] **Step 2: Run app on Android device**

```bash
flutter run
```

- [ ] **Step 3: Test Profile Tab Navigation**

- Tap Profile icon in bottom navigation bar
- Verify Profile screen loads without errors
- Verify profile picture placeholder shows (person icon)

- [ ] **Step 4: Test Edit Name/Phone**

- Edit name field (max 50 chars)
- Edit phone number field (max 20 chars)
- Tap "Update Profile" button
- Verify toast shows "Profile updated successfully"
- Close and reopen app to verify data persists

- [ ] **Step 5: Test Profile Picture Upload**

- Tap profile picture to open image picker
- Test "Take Photo" (camera)
- Verify image uploads and displays in profile picture circle
- Repeat with "Choose from Gallery"
- Verify image compressed and cached locally

- [ ] **Step 6: Test Change Password (Email Users Only)**

- Log in with email account
- Open Profile
- Verify "Change Password" button shows
- Tap and enter current password + new password
- Verify password change succeeds (use new password to log in on another device)

- [ ] **Step 7: Test Change Password Hidden (Google Users)**

- Log in with Google
- Open Profile
- Verify "Change Password" button does NOT show

- [ ] **Step 8: Test Delete Account**

- Tap "Delete Account" button
- Verify warning dialog appears with message about permanent deletion
- Cancel and verify nothing happens
- Tap again and confirm
- Verify re-authentication dialog (password for email, Google sign-in for Google)
- Complete re-auth
- Verify toast "Account deleted successfully"
- Verify redirected to login/home

- [ ] **Step 9: Test Localization**

- Change app language to Indonesian in Settings
- Open Profile
- Verify all labels and buttons are in Indonesian

- [ ] **Step 10: Commit successful testing**

```bash
git add -A && git commit -m "v0.9.0: profile page testing complete and verified"
```

---

## Task 8: Create Git Tag and Final Verification

- [ ] **Step 1: Create git tag**

```bash
git tag v0.9.0
```

- [ ] **Step 2: Verify git log shows v0.9.0**

```bash
git log --oneline -5 && git tag -l | grep v0.9.0
```

Expected: v0.9.0 tag visible in output.

- [ ] **Step 3: Final flutter analyze**

```bash
flutter analyze
```

Expected: No errors.

- [ ] **Step 4: Status check**

```bash
git status
```

Expected: Working tree clean, develop branch.

Done! Profile page implementation complete.
