import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
    } on AccountExistsException catch (e) {
      // Email already used by an email/password account — offer to link.
      if (mounted) {
        await _showAccountLinkDialog(e);
      }
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

  /// An account with this email already exists (email/password). Ask for the
  /// password to prove ownership, then link the Google credential so both
  /// providers sign in to the same account.
  Future<void> _showAccountLinkDialog(AccountExistsException e) async {
    final l10n = AppLocalizations.of(context)!;
    final passwordController = TextEditingController();
    String? errorMessage;

    final linked = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.accountExistsTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.accountExistsBody(e.email)),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.password,
                  border: const OutlineInputBorder(),
                  errorText: errorMessage,
                ),
                onSubmitted: (_) async {
                  final error = await _linkGoogleAccount(
                    dialogContext,
                    e,
                    passwordController.text,
                  );
                  if (error == null) {
                    Navigator.of(dialogContext).pop(true);
                  } else {
                    setDialogState(() => errorMessage = error);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () async {
                final error = await _linkGoogleAccount(
                  dialogContext,
                  e,
                  passwordController.text,
                );
                if (error == null) {
                  Navigator.of(dialogContext).pop(true);
                } else {
                  setDialogState(() => errorMessage = error);
                }
              },
              child: Text(l10n.accountExistsLinkButton),
            ),
          ],
        ),
      ),
    );
    passwordController.dispose();

    if (linked == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.accountExistsSuccess)));
    }
  }

  /// Returns null on success, or a localized error message to show in the
  /// dialog on failure.
  Future<String?> _linkGoogleAccount(
    BuildContext dialogContext,
    AccountExistsException e,
    String password,
  ) async {
    final l10n = AppLocalizations.of(dialogContext)!;
    try {
      await AuthService.instance.linkGoogleToExistingAccount(
        email: e.email,
        password: password,
        googleCredential: e.googleCredential,
      );
      return null;
    } catch (error) {
      debugPrint('LoginScreen: Account link failed: $error');
      return l10n.errorWrongPassword;
    }
  }

  Future<void> _handlePhoneSignIn() async {
    // Capture current UID before sign-in to detect new vs returning user.
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
        MaterialPageRoute(builder: (_) => const OptionalEmailPromptScreen()),
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
