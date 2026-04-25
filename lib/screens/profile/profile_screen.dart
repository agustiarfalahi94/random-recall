import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:random_recall/core/services/profile_service.dart';
import 'package:random_recall/l10n/app_localizations.dart';
import 'package:random_recall/services/display_name_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/auth_service.dart';
import '../auth/optional_email_prompt_screen.dart';
import '../auth/phone_auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late TextEditingController _nameController;

  bool _isEmailUser = false;
  bool _isPhoneUser = false;
  bool _isPremium = false;
  bool _isLoading = false;
  bool _isUploadingPhoto = false;
  String? _linkedPhoneNumber;
  String? _photoUrl;
  int _phoneOnlyPrompted = 0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _loadProfileData();
  }

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
          _isEmailUser =
              user.providerData.any((p) => p.providerId == 'password');
          _isPhoneUser =
              user.providerData.any((p) => p.providerId == 'phone');
          _linkedPhoneNumber = user.phoneNumber;
          _phoneOnlyPrompted =
              (profile?['phone_only_prompted'] as int?) ?? 0;
          _isPremium = isPremium;
          _photoUrl = user.photoURL ?? (profile?['photo_url'] as String?);
        });
      }
    } catch (e) {
      debugPrint('ProfileScreen: Load profile failed: $e');
    }
  }

  Future<void> _updateProfile() async {
    final l10n = AppLocalizations.of(context)!;
    final trimmedName = _nameController.text.trim();

    if (trimmedName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.nameLabel)),
        );
      }
      return;
    }

    if (!DisplayNameService.isValidCharacters(trimmedName)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Display name contains invalid characters'),
          ),
        );
      }
      return;
    }

    final hasProfanity =
        await DisplayNameService.checkProfanity(trimmedName);
    if (hasProfanity) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Display name contains inappropriate content'),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _profileService.updateUserProfile(name: trimmedName);

      await _auth.currentUser?.reload();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileUpdateSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileUpdateFailed)),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openPhoneAuth(PhoneAuthMode mode) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PhoneAuthScreen(mode: mode)),
    );
    if (result == true && mounted) {
      await _auth.currentUser?.reload();
      await _loadProfileData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.profileUpdateSuccess),
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
        .set(
          {'phone_only_prompted': FieldValue.increment(1)},
          SetOptions(merge: true),
        );
    if (mounted) setState(() => _phoneOnlyPrompted++);
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    final l10n = AppLocalizations.of(context)!;
    Navigator.pop(context); // close bottom sheet

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (image == null || !mounted) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final url = await _profileService.uploadProfilePhoto(image);
      if (mounted) {
        setState(() => _photoUrl = url);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.profilePhotoUpdated),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.profilePhotoUpdateFailed),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _showPhotoPickerSheet(AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(l10n.profilePhotoFromCamera),
              onTap: () => _pickAndUploadPhoto(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.profilePhotoFromGallery),
              onTap: () => _pickAndUploadPhoto(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(AppLocalizations l10n) {
    final initials = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()[0].toUpperCase()
        : '?';

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 52,
            backgroundColor:
                Theme.of(context).colorScheme.primaryContainer,
            child: _isUploadingPhoto
                ? const CircularProgressIndicator()
                : _photoUrl != null
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: _photoUrl!,
                          width: 104,
                          height: 104,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              const CircularProgressIndicator(),
                          errorWidget: (_, __, ___) => Text(
                            initials,
                            style: const TextStyle(
                                fontSize: 36, fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                    : Text(
                        initials,
                        style: const TextStyle(
                            fontSize: 36, fontWeight: FontWeight.bold),
                      ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _isUploadingPhoto
                  ? null
                  : () => _showPhotoPickerSheet(l10n),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.camera_alt,
                  size: 18,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneField(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_linkedPhoneNumber != null) {
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
        if (_isPhoneUser && !hasEmailOrGoogle && _phoneOnlyPrompted < 2) ...[
          const SizedBox(height: 8),
          Card(
            color: colorScheme.secondaryContainer,
            child: ListTile(
              leading: Icon(
                Icons.email_outlined,
                color: colorScheme.onSecondaryContainer,
              ),
              title: Text(
                l10n.profileAddRecoveryEmail,
                style: TextStyle(
                  color: colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                l10n.profileAddRecoveryEmailSubtitle,
                style: TextStyle(
                  color: colorScheme.onSecondaryContainer,
                  fontSize: 12,
                ),
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
              decoration:
                  const InputDecoration(hintText: 'Current Password'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'New Password'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration:
                  const InputDecoration(hintText: 'Confirm Password'),
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
              if (newPasswordController.text !=
                  confirmPasswordController.text) {
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

    // Route to the right re-auth based on provider.
    // Prefer email re-auth when both email and phone are linked.
    if (_isEmailUser) {
      await _reauthenticateEmail();
    } else if (_isPhoneUser) {
      await _reauthenticatePhone();
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
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/', (_) => false);
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

  Future<void> _reauthenticatePhone() async {
    final l10n = AppLocalizations.of(context)!;
    final phoneNumber = _linkedPhoneNumber;
    if (phoneNumber == null) return;

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

    String? verificationId;
    setState(() => _isLoading = true);

    await AuthService.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      onCodeSent: (id, _) {
        verificationId = id;
      },
      onAutoVerified: (credential) async {
        try {
          await _profileService.deleteAccountPhoneAuth(
            verificationId: credential.verificationId!,
            smsCode: credential.smsCode!,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.accountDeletedSuccess)),
            );
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/', (_) => false);
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

    // If auto-retrieval didn't fire, prompt for the code manually.
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
              onPressed: () =>
                  Navigator.pop(ctx, codeController.text.trim()),
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
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/', (_) => false);
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
                  // Profile photo
                  _buildAvatar(l10n),
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

                  // Phone field — auth-driven
                  _buildPhoneField(l10n),
                  const SizedBox(height: 16),

                  // Email (read-only)
                  TextField(
                    controller: TextEditingController(
                      text: _auth.currentUser?.email ?? '',
                    ),
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
                          backgroundColor:
                              _isPremium ? Colors.green : Colors.grey,
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
    super.dispose();
  }
}
