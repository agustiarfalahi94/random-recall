// lib/screens/auth/display_name_setup_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:random_recall/l10n/app_localizations.dart';
import 'package:random_recall/services/display_name_service.dart';

class DisplayNameSetupScreen extends StatefulWidget {
  final bool canDismiss; // false for new users (can't skip), true for existing users (optional)
  final VoidCallback? onComplete;

  const DisplayNameSetupScreen({
    super.key,
    this.canDismiss = false,
    this.onComplete,
  });

  @override
  State<DisplayNameSetupScreen> createState() => _DisplayNameSetupScreenState();
}

class _DisplayNameSetupScreenState extends State<DisplayNameSetupScreen> {
  final _controller = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validateInput(String value) {
    setState(() {
      final l10n = AppLocalizations.of(context)!;

      if (value.trim().isEmpty) {  // Changed from isWhitespaceOnly()
        _errorMessage = l10n.displayNameEmpty;
      } else if (!DisplayNameService.isValidCharacters(value)) {
        _errorMessage = l10n.displayNameInvalidCharacters;
      } else {
        _errorMessage = null;
      }
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _controller.text.trim();

    // Validate
    if (!DisplayNameService.isValidCharacters(name)) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check profanity
      final isProfane = await DisplayNameService.checkProfanity(name);
      if (isProfane) {
        setState(() {
          _errorMessage = l10n.displayNameProfanity;
          _isLoading = false;
        });
        return;
      }

      // Update Firebase Auth displayName
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updateDisplayName(name);

        // Also save to Firestore for backup
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(
              {'name': name, 'updatedAt': FieldValue.serverTimestamp()},
              SetOptions(merge: true),
            );
      }

      widget.onComplete?.call();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving name. Please try again.';
        _isLoading = false;
      });
    }
  }

  bool get _isValid =>
      _errorMessage == null &&
      _controller.text.isNotEmpty &&
      DisplayNameService.isValidCharacters(_controller.text);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return PopScope(
      canPop: widget.canDismiss, // Can't dismiss if canDismiss=false
      child: Dialog(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.displayNameLabel,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.displayNameMaxLength,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  onChanged: _validateInput,
                  enabled: !_isLoading,
                  maxLength: DisplayNameService.maxLength,
                  decoration: InputDecoration(
                    hintText: l10n.displayNameInputHint,
                    border: const OutlineInputBorder(),
                    errorText: _errorMessage,
                    counterText: '${_controller.text.length}/${DisplayNameService.maxLength}',
                    suffixIcon: _errorMessage == null && _controller.text.isNotEmpty
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (widget.canDismiss)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : () => Navigator.pop(context),
                          child: Text(l10n.displayNameCancel),
                        ),
                      ),
                    if (widget.canDismiss) const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _isLoading || !_isValid ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(l10n.displayNameSubmit),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
