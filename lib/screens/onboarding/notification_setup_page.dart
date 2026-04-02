import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';

import '../../core/notifications/notification_service.dart';

typedef OnNotificationSetupComplete = void Function({
  required bool randomAnytime,
  required int startHour,
  required int endHour,
  required int frequency,
  required List<int> activeDays,
});

class NotificationSetupPage extends StatefulWidget {
  const NotificationSetupPage({super.key, required this.onComplete});

  final OnNotificationSetupComplete onComplete;

  @override
  State<NotificationSetupPage> createState() => _NotificationSetupPageState();
}

class _NotificationSetupPageState extends State<NotificationSetupPage>
    with WidgetsBindingObserver {
  bool _randomAnytime = true;
  int _startHour = 8;
  int _endHour = 20;
  int _frequency = 3;
  final Set<int> _activeDays = {1, 2, 3, 4, 5};
  bool _showPermissionError = false;
  bool _checkingPermission = false;
  bool _permPermanentlyDenied = false; // true after first denial
  // True while we wait for the user to return from Android notification settings
  bool _waitingForSettingsReturn = false;

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Called by Android when the app comes back to foreground.
  /// If we were waiting for the user to return from notification settings,
  /// check permission now — this is when the change actually takes effect.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForSettingsReturn) {
      _waitingForSettingsReturn = false;
      _checkPermissionAfterSettings();
    }
  }

  Future<void> _checkPermissionAfterSettings() async {
    setState(() => _checkingPermission = true);
    final granted = await NotificationService.instance.hasPermission();
    if (!mounted) return;
    setState(() => _checkingPermission = false);
    if (granted) {
      setState(() {
        _showPermissionError = false;
        _permPermanentlyDenied = false;
      });
      widget.onComplete(
        randomAnytime: _randomAnytime,
        startHour: _startHour,
        endHour: _endHour,
        frequency: _frequency,
        activeDays: _activeDays.toList()..sort(),
      );
    } else {
      // User came back but still hasn't granted — keep error visible
      setState(() => _showPermissionError = true);
    }
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour == 12) return '12 PM';
    if (hour < 12) return '$hour AM';
    return '${hour - 12} PM';
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: isStart ? _startHour : _endHour, minute: 0),
      helpText: isStart ? 'Select start time' : 'Select end time',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startHour = picked.hour;
        // Auto-advance end hour if it's no longer at least 1 hour ahead
        if (_endHour <= _startHour) _endHour = (_startHour + 1).clamp(0, 23);
      } else {
        if (picked.hour > _startHour) {
          _endHour = picked.hour;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('End time must be at least 1 hour after start time'),
            ),
          );
        }
      }
    });
  }

  Future<void> _onComplete() async {
    // If we already know permission is permanently denied, open the system
    // settings page. We DON'T await it — it resolves immediately on Android
    // (the moment the Settings app opens, not when user returns).
    // Instead, WidgetsBindingObserver.didChangeAppLifecycleState will fire
    // when the user comes back and we check permission there.
    if (_permPermanentlyDenied) {
      _waitingForSettingsReturn = true;
      AppSettings.openAppSettings(type: AppSettingsType.notification);
      return;
    }

    setState(() {
      _checkingPermission = true;
      _showPermissionError = false;
    });

    // First check if already granted (maybe they enabled it in Settings)
    bool granted = await NotificationService.instance.hasPermission();
    if (!granted) {
      // Show the system dialog (only works once — OS ignores subsequent calls)
      granted = await NotificationService.instance.requestPermission();
    }

    if (!mounted) return;

    if (!granted) {
      setState(() {
        _checkingPermission = false;
        _showPermissionError = true;
        _permPermanentlyDenied = true; // next tap → open Settings
      });
      return;
    }

    setState(() => _checkingPermission = false);

    widget.onComplete(
      randomAnytime: _randomAnytime,
      startHour: _startHour,
      endHour: _endHour,
      frequency: _frequency,
      activeDays: _activeDays.toList()..sort(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 48),
            _buildStepIndicator(colorScheme),
            const SizedBox(height: 28),
            Text(
              'When should we\nremind you?',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You can change these settings later in the app.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),

            // Timing toggle
            _SectionCard(
              colorScheme: colorScheme,
              child: Column(
                children: [
                  _TimingOptionTile(
                    title: 'Anytime (fully random)',
                    subtitle: 'Notifications at any hour of the day',
                    icon: '🎲',
                    isSelected: _randomAnytime,
                    colorScheme: colorScheme,
                    onTap: () => setState(() => _randomAnytime = true),
                  ),
                  Divider(height: 1, color: colorScheme.outlineVariant.withOpacity(0.4)),
                  _TimingOptionTile(
                    title: 'Set time range',
                    subtitle: 'Only notify within your chosen window',
                    icon: '🕐',
                    isSelected: !_randomAnytime,
                    colorScheme: colorScheme,
                    onTap: () => setState(() => _randomAnytime = false),
                  ),
                ],
              ),
            ),

            if (!_randomAnytime) ...[
              const SizedBox(height: 20),
              _SectionLabel(label: 'Time window', colorScheme: colorScheme),
              const SizedBox(height: 10),
              _SectionCard(
                colorScheme: colorScheme,
                child: Column(
                  children: [
                    _TimePickerRow(
                      label: 'From',
                      timeText: _formatHour(_startHour),
                      colorScheme: colorScheme,
                      onTap: () => _pickTime(isStart: true),
                    ),
                    Divider(height: 1, color: colorScheme.outlineVariant.withOpacity(0.4)),
                    _TimePickerRow(
                      label: 'Until',
                      timeText: _formatHour(_endHour),
                      colorScheme: colorScheme,
                      onTap: () => _pickTime(isStart: false),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SectionLabel(label: 'Active days', colorScheme: colorScheme),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(7, (index) {
                  final day = index + 1;
                  final isSelected = _activeDays.contains(day);
                  return FilterChip(
                    label: Text(_dayLabels[index]),
                    selected: isSelected,
                    showCheckmark: false,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _activeDays.add(day);
                        } else if (_activeDays.length > 1) {
                          _activeDays.remove(day);
                        }
                      });
                    },
                    selectedColor: colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? colorScheme.primary.withOpacity(0.5)
                          : colorScheme.outlineVariant,
                    ),
                    backgroundColor: colorScheme.surface,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  );
                }),
              ),
            ],

            const SizedBox(height: 24),
            _SectionLabel(label: 'How many times per day?', colorScheme: colorScheme),
            const SizedBox(height: 10),
            _SectionCard(
              colorScheme: colorScheme,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _frequency > 1 ? () => setState(() => _frequency--) : null,
                      icon: const Icon(Icons.remove_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.primaryContainer,
                        foregroundColor: colorScheme.onPrimaryContainer,
                        disabledBackgroundColor: colorScheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '$_frequency',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.primary,
                            ),
                          ),
                          Text(
                            _frequency == 1 ? 'time per day' : 'times per day',
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _frequency < 10 ? () => setState(() => _frequency++) : null,
                      icon: const Icon(Icons.add_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.primaryContainer,
                        foregroundColor: colorScheme.onPrimaryContainer,
                        disabledBackgroundColor: colorScheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // ── Permission error banner ────────────────────────────────────
            if (_showPermissionError) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notifications_off_rounded,
                        color: colorScheme.onErrorContainer, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notifications are turned off',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onErrorContainer,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _permPermanentlyDenied
                                ? 'Tap the button below to open Notification Settings. '
                                    'Enable "Random Recall" there, then come back here.'
                                : 'Random Recall needs notifications to remind you. '
                                    'Please go to Settings → Apps → Random Recall → '
                                    'Notifications and enable them, then come back.',
                            style: TextStyle(
                              color: colorScheme.onErrorContainer,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── "Checking…" hint — shown while verifying on return ──────────
            if (_checkingPermission) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Checking notification permission…',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            ElevatedButton(
              onPressed: _checkingPermission ? null : _onComplete,
              child: _checkingPermission
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_permPermanentlyDenied
                      ? 'Open Notification Settings ↗'
                      : _showPermissionError
                          ? 'Try again'
                          : 'Start Recalling! 🚀'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(ColorScheme colorScheme) {
    return Row(
      children: List.generate(3, (index) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index < 2 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: index == 2 ? colorScheme.primary : colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.colorScheme});
  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurfaceVariant,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, required this.colorScheme});
  final Widget child;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _TimingOptionTile extends StatelessWidget {
  const _TimingOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.colorScheme,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final String icon;
  final bool isSelected;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? colorScheme.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? colorScheme.primary : colorScheme.outline,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(Icons.check_rounded, size: 14, color: colorScheme.onPrimary)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimePickerRow extends StatelessWidget {
  const _TimePickerRow({
    required this.label,
    required this.timeText,
    required this.colorScheme,
    required this.onTap,
  });
  final String label;
  final String timeText;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, size: 20, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                  fontSize: 14,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                timeText,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onPrimaryContainer,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}
