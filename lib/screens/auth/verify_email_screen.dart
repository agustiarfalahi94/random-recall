import 'dart:async';
import 'package:flutter/material.dart';
import 'package:random_recall/l10n/app_localizations.dart';
import '../../core/auth/auth_service.dart';
import '../../core/services/analytics_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isResending = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (timer) => _checkEmailVerified(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkEmailVerified() async {
    await AuthService.instance.reloadUser();
    final user = AuthService.instance.currentUser;
    if (user != null && user.emailVerified) {
      _timer?.cancel();
      await AuthService.instance.initializeUserSession();
      // Track login analytics (parity with Google and direct email login)
      AnalyticsService.instance.trackLogin(method: 'email').ignore();
      AnalyticsService.instance.identify(user.uid, email: user.email).ignore();
    }
  }

  Future<void> _resendEmail() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isResending = true);
    try {
      await AuthService.instance.currentUser?.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.verificationResent)));
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = AuthService.instance.currentUser;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32.0,
                  vertical: 40.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('✉️', style: TextStyle(fontSize: 80)),
                    const SizedBox(height: 32),
                    Text(
                      l10n.verifyEmailTitle,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.verifyEmailSent(user?.email ?? ''),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, height: 1.5),
                    ),
                    const SizedBox(height: 32),
                    OutlinedButton(
                      onPressed: _checkEmailVerified,
                      child: Text(l10n.iHaveClickedLink),
                    ),
                    const SizedBox(height: 48),
                    ElevatedButton(
                      onPressed: _isResending ? null : _resendEmail,
                      child: _isResending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.resendEmail),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        final signingOutText = l10n.signingOut;

                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => Center(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(),
                                    const SizedBox(height: 16),
                                    Text(signingOutText),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );

                        try {
                          await AuthService.instance.signOut(
                            onBeforeFinalSignOut: () async {
                              if (navigator.canPop()) navigator.pop();
                            },
                          );
                        } catch (e) {
                          if (navigator.canPop()) navigator.pop();
                          messenger.showSnackBar(
                            SnackBar(content: Text(l10n.errorUnexpected)),
                          );
                        }
                      },
                      child: Text(l10n.cancelSignOut),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      l10n.waitingVerification,
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
