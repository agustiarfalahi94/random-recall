import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';

/// A bottom sheet that walks Xiaomi/HyperOS users through the two settings
/// they need to change so Random Recall can deliver notifications reliably:
///
///   1. Autostart — prevents MIUI/HyperOS from blocking the app from starting
///      in the background (required for WorkManager to run).
///   2. Battery saver — set to "No Restrictions" so the OS doesn't throttle
///      or kill background processes for this app.
///
/// Call [MiuiBatteryDialog.show] from any screen.
class MiuiBatteryDialog extends StatelessWidget {
  const MiuiBatteryDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const MiuiBatteryDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Row(
            children: [
              Icon(Icons.battery_saver_rounded,
                  color: colorScheme.primary, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Fix notifications on MIUI / HyperOS',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Xiaomi phones aggressively restrict background apps by default. '
            'Two quick settings changes will make sure your quiz notifications '
            'arrive reliably.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),

          // Step 1 — Autostart
          _Step(
            number: '1',
            title: 'Enable Autostart',
            description:
                'Settings → Apps → Manage Apps → Random Recall → Autostart → turn ON',
            icon: Icons.play_circle_outline_rounded,
            colorScheme: colorScheme,
            theme: theme,
          ),
          const SizedBox(height: 16),

          // Step 2 — Battery saver
          _Step(
            number: '2',
            title: 'Set battery to No Restrictions',
            description:
                'Settings → Battery → App Battery Saver → Random Recall → No Restrictions',
            icon: Icons.battery_charging_full_rounded,
            colorScheme: colorScheme,
            theme: theme,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Text(
              'On newer HyperOS: Settings → Battery → Battery Usage → '
              'Random Recall → No Restrictions.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 28),

          // Open battery settings button
          FilledButton.icon(
            onPressed: () => AppSettings.openAppSettings(),
            icon: const Icon(Icons.settings_rounded),
            label: const Text('Open App Settings'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
          const SizedBox(height: 12),

          // Done / dismiss
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text("I've done this — close"),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
    required this.colorScheme,
    required this.theme,
  });

  final String number;
  final String title;
  final String description;
  final IconData icon;
  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Number badge
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
