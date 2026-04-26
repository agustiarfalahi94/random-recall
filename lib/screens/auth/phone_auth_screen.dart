import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:random_recall/l10n/app_localizations.dart';

import '../../core/auth/auth_service.dart';

enum PhoneAuthMode { signIn, link, change }

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key, this.mode = PhoneAuthMode.signIn});

  final PhoneAuthMode mode;

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  // Stage 1
  String _completePhoneNumber = '';
  bool _phoneValid = false;

  // Stage 2
  final _codeController = TextEditingController();
  String? _verificationId;
  int? _resendToken;

  bool _isStage2 = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Resend cooldown
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _codeController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _resendCooldown = 60;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) t.cancel();
      });
    });
  }

  Future<void> _sendOtp({bool isResend = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await AuthService.instance.verifyPhoneNumber(
      phoneNumber: _completePhoneNumber,
      resendToken: isResend ? _resendToken : null,
      onCodeSent: (verificationId, resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _isStage2 = true;
          _isLoading = false;
        });
        _startCooldown();
      },
      onAutoVerified: (credential) async {
        // Android auto-retrieved the SMS — complete immediately.
        if (!mounted) return;
        setState(() => _isLoading = true);
        try {
          await _completeWithCredential(credential);
        } catch (e) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = e.toString();
            });
          }
        }
      },
      onFailed: (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = _mapError(e, AppLocalizations.of(context)!);
        });
      },
    );
  }

  Future<void> _verifyCode() async {
    final l10n = AppLocalizations.of(context)!;
    final code = _codeController.text.trim();
    if (code.length != 6) return;
    if (_verificationId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _completeWithVerificationId(_verificationId!, code);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _mapError(e, l10n);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = l10n.phoneAuthFailed;
        });
      }
    }
  }

  Future<void> _completeWithCredential(PhoneAuthCredential credential) async {
    await _completeWithVerificationId(
      credential.verificationId!,
      credential.smsCode!,
    );
  }

  Future<void> _completeWithVerificationId(
    String verificationId,
    String smsCode,
  ) async {
    switch (widget.mode) {
      case PhoneAuthMode.signIn:
        await AuthService.instance.signInWithPhone(verificationId, smsCode);
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);

      case PhoneAuthMode.link:
        await AuthService.instance.linkPhoneNumber(verificationId, smsCode);
        if (!mounted) return;
        Navigator.of(context).pop(true);

      case PhoneAuthMode.change:
        await AuthService.instance.changePhoneNumber(verificationId, smsCode);
        if (!mounted) return;
        Navigator.of(context).pop(true);
    }
  }

  String _mapError(FirebaseAuthException e, AppLocalizations l10n) {
    switch (e.code) {
      case 'invalid-verification-code':
        return l10n.phoneAuthInvalidCode;
      case 'too-many-requests':
        return l10n.phoneAuthTooManyRequests;
      case 'credential-already-in-use':
      case 'provider-already-linked':
        return l10n.phoneAuthCredentialInUse;
      default:
        return l10n.phoneAuthFailed;
    }
  }

  String _appBarTitle(AppLocalizations l10n) {
    switch (widget.mode) {
      case PhoneAuthMode.signIn:
        return l10n.phoneAuthTitle;
      case PhoneAuthMode.link:
        return l10n.linkPhoneTitle;
      case PhoneAuthMode.change:
        return l10n.changePhoneTitle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_appBarTitle(l10n))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '📱',
              style: TextStyle(fontSize: 48),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              _isStage2 ? l10n.phoneAuthEnterCode : l10n.phoneAuthEnterNumber,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (_isStage2) ...[
              const SizedBox(height: 8),
              Text(
                l10n.phoneAuthCodeSentTo(_completePhoneNumber),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 32),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: colorScheme.onErrorContainer,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
            ],

            if (!_isStage2) ...[
              // Stage 1: phone entry
              IntlPhoneField(
                initialCountryCode: 'ID',
                disableLengthCheck: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(13),
                ],
                decoration: InputDecoration(
                  labelText: l10n.phoneAuthEnterNumber,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (phone) {
                  setState(() {
                    _completePhoneNumber = phone.completeNumber;
                    _phoneValid = phone.number.length >= 9;
                  });
                },
                onCountryChanged: (_) {},
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: (_isLoading || !_phoneValid) ? null : _sendOtp,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.phoneAuthSendOtp),
              ),
            ] else ...[
              // Stage 2: OTP entry
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                onChanged: (v) {
                  setState(() {}); // rebuild to update button state
                  if (v.length == 6) _verifyCode();
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed:
                    (_isLoading || _codeController.text.length != 6)
                        ? null
                        : _verifyCode,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.phoneAuthVerify),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: (_isLoading || _resendCooldown > 0)
                    ? null
                    : () => _sendOtp(isResend: true),
                child: Text(
                  _resendCooldown > 0
                      ? l10n.phoneAuthResendIn(_resendCooldown)
                      : l10n.phoneAuthResend,
                  style: TextStyle(color: colorScheme.secondary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
