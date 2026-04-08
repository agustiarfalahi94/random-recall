import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';

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
    // Periodically check if email is verified
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) => _checkEmailVerified());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkEmailVerified() async {
    await AuthService.instance.reloadUser();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.emailVerified) {
      _timer?.cancel();
      // This triggers RevenueCat login and Cloud Restore now that we are verified
      await AuthService.instance.initializeUserSession();
    }
  }

  Future<void> _resendEmail() async {
    setState(() => _isResending = true);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email resent!')),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('✉️', style: TextStyle(fontSize: 80)),
                    const SizedBox(height: 32),
                    const Text(
                      'Verify your email',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'We sent a verification link to ${user?.email}.\nPlease check your inbox and click the link to continue.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, height: 1.5),
                    ),
                    const SizedBox(height: 32),
                    OutlinedButton(
                      onPressed: _checkEmailVerified,
                      child: const Text('I have clicked the link'),
                    ),
                    const SizedBox(height: 48),
                    ElevatedButton(
                      onPressed: _isResending ? null : _resendEmail,
                      child: _isResending 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Resend Email'),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Signing out...'),
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
                  messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
                      child: const Text('Cancel / Sign Out'),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Waiting for verification...',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.blue),
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