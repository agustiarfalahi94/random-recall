import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:random_recall/core/services/profile_service.dart';
import 'package:random_recall/l10n/app_localizations.dart';
import 'package:random_recall/services/display_name_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;

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

      if (mounted) {
        setState(() {
          _nameController.text = profile?['name'] ?? '';
          _phoneController.text = profile?['phone_number'] ?? '';
          _isEmailUser = user.providerData.any((p) => p.providerId == 'password');
          _isPremium = isPremium;
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

    // Validate characters
    if (!DisplayNameService.isValidCharacters(trimmedName)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Display name contains invalid characters')),
        );
      }
      return;
    }

    // Check for profanity
    final hasProfanity = await DisplayNameService.checkProfanity(trimmedName);
    if (hasProfanity) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Display name contains inappropriate content')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _profileService.updateUserProfile(
        name: trimmedName,
        phoneNumber: _phoneController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.profileUpdateSuccess),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.profileUpdateFailed),
          ),
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
              decoration: const InputDecoration(hintText: 'Current Password'),
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
              decoration: const InputDecoration(hintText: 'Confirm Password'),
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
