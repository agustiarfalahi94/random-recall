import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../core/notifications/notification_service.dart';

class PermissionRequiredScreen extends StatefulWidget {
  const PermissionRequiredScreen({super.key});

  @override
  State<PermissionRequiredScreen> createState() => _PermissionRequiredScreenState();
}

class _PermissionRequiredScreenState extends State<PermissionRequiredScreen> {
  bool _isChecking = false;

  Future<void> _handleAction() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isChecking = true);

    final granted = await NotificationService.instance.requestPermission();

    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.enableInSettings),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await AppSettings.openAppSettings(type: AppSettingsType.notification);
    }

    if (mounted) setState(() => _isChecking = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🔔', style: TextStyle(fontSize: 80)),
              const SizedBox(height: 32),
              Text(
                l10n.notifRequired,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.notifRequiredDesc,
                style: TextStyle(color: colorScheme.onSurfaceVariant, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _isChecking ? null : _handleAction,
                child: _isChecking
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(l10n.enableNotifications),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => SystemNavigator.pop(),
                child: Text(
                  l10n.exitApp,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
