import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// A bottom sheet that walks Xiaomi/HyperOS users through the two settings
/// they need to change so Random Recall can deliver notifications reliably:
///
///   1. Autostart — prevents MIUI/HyperOS from killing the background worker.
///   2. Power → No Restrictions — lets the app run without battery throttling.
///
/// Launches Settings → Apps → Background Start directly on MIUI/HyperOS.
/// Falls back to the generic app-info page if the intent isn't available.
Future<void> _openBackgroundStart() async {
  try {
    const intent = AndroidIntent(
      action: 'android.intent.action.MAIN',
      package: 'com.miui.securitycenter',
      componentName:
          'com.miui.permcenter.autostart.AutoStartManagementActivity',
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    await intent.launch();
  } catch (_) {
    await AppSettings.openAppSettings();
  }
}

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
    final l10n = AppLocalizations.of(context)!;
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
                  l10n.miuiDialogTitle,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.miuiDialogSubtitle,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),

          // Step 1 — Autostart / Background start
          _Step(
            number: '1',
            title: l10n.miuiStep1Title,
            description: l10n.miuiStep1Desc,
            icon: Icons.play_circle_outline_rounded,
            colorScheme: colorScheme,
            theme: theme,
          ),
          const SizedBox(height: 12),

          // Step 1 action button
          FilledButton.tonalIcon(
            onPressed: _openBackgroundStart,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(l10n.openBackgroundStartBtn),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 20),

          // Step 2 — Power / No Restrictions
          _Step(
            number: '2',
            title: l10n.miuiStep2Title,
            description: l10n.miuiStep2Desc,
            icon: Icons.battery_charging_full_rounded,
            colorScheme: colorScheme,
            theme: theme,
          ),
          const SizedBox(height: 12),

          // Step 2 action button
          FilledButton.tonalIcon(
            onPressed: () => AppSettings.openAppSettings(),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(l10n.openAppSettingsBtn),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 16),

          // Done / dismiss
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: Text(l10n.doneDismissBtn),
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
