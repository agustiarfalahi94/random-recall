import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_settings/app_settings.dart';
import '../../core/notifications/notification_service.dart';

class PermissionRequiredScreen extends StatefulWidget {
  const PermissionRequiredScreen({super.key});

  @override
  State<PermissionRequiredScreen> createState() => _PermissionRequiredScreenState();
}

class _PermissionRequiredScreenState extends State<PermissionRequiredScreen> {
  bool _isChecking = false;

  Future<void> _handleAction() async {
    setState(() => _isChecking = true);
    
    // Request permission via service
    final granted = await NotificationService.instance.requestPermission();
    
    if (!granted && mounted) {
      // If still not granted (user clicked "Don't Allow" previously), open app settings
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable notifications in system settings to continue.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await AppSettings.openAppSettings(type: AppSettingsType.notification);
    }
    
    if (mounted) setState(() => _isChecking = false);
  }

  @override
  Widget build(BuildContext context) {
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
                'Notifications Required',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Random Recall works by sending you random quiz notifications throughout the day. Without this permission, the app cannot function.',
                style: TextStyle(color: colorScheme.onSurfaceVariant, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _isChecking ? null : _handleAction,
                child: _isChecking 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Enable Notifications'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => SystemNavigator.pop(),
                child: Text(
                  'Exit App',
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