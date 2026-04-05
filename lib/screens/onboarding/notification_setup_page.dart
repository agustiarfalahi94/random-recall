import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/utils/battery_optimization.dart';

typedef OnNotificationSetupComplete = void Function({
  required bool randomAnytime,
  required int startHour,
  required int endHour,
  required int frequency,
  required List<int> activeDays,
});

class NotificationSetupPage extends StatefulWidget {
  const NotificationSetupPage({
    super.key,
    required this.onComplete,
    required this.onBack,
  });

  final OnNotificationSetupComplete onComplete;
  final VoidCallback onBack;

  @override
  State<NotificationSetupPage> createState() => _NotificationSetupPageState();
}

class _NotificationSetupPageState extends State<NotificationSetupPage>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  bool _randomAnytime = true;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 20, minute: 0);
  int _frequency = 3;
  Set<int> _activeDays = {1, 2, 3, 4, 5, 6, 7};
  bool _showPermissionError = false;
  bool _checkingPermission = false;
  bool _permPermanentlyDenied = false;
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
      final isIgnoring = await isIgnoringBatteryOptimizations();
      if (!mounted) return;
      if (!isIgnoring) await requestIgnoreBatteryOptimizations();
      if (!mounted) return;
      widget.onComplete(
        randomAnytime: _randomAnytime,
        startHour: _startTime.hour,
        endHour: _endTime.hour,
        frequency: _frequency,
        activeDays: _activeDays.toList()..sort(),
      );
    } else {
      setState(() => _showPermissionError = true);
    }
  }

  String _formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      helpText: isStart ? 'Select start time' : 'Select end time',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
        // Auto-advance end if end is no longer at least 1 hour ahead
        if (_endTime.hour <= _startTime.hour) {
          _endTime = TimeOfDay(hour: (_startTime.hour + 1).clamp(0, 23), minute: 0);
        }
      } else {
        _endTime = picked;
      }
    });
  }

  String get _activeDaysLabel {
    if (_activeDays.isEmpty) return 'You must choose at least 1!';
    final sorted = _activeDays.toList()..sort();
    final isWeekdays = sorted.length == 5 && sorted.every((d) => d >= 1 && d <= 5);
    final isWeekends = sorted.length == 2 && sorted.contains(6) && sorted.contains(7);
    final isDaily = sorted.length == 7;
    if (isDaily) return 'Every day';
    if (isWeekdays) return 'Weekdays only';
    if (isWeekends) return 'Weekends only';
    return sorted.map((d) => _dayLabels[d - 1]).join(', ');
  }

  Future<void> _onComplete() async {
    // Validate time range before checking permission
    if (!_randomAnytime && _endTime.hour <= _startTime.hour) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be at least 1 hour after start time.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_permPermanentlyDenied) {
      _waitingForSettingsReturn = true;
      AppSettings.openAppSettings(type: AppSettingsType.notification);
      return;
    }

    setState(() {
      _checkingPermission = true;
      _showPermissionError = false;
    });

    bool granted = await NotificationService.instance.hasPermission();
    if (!granted) {
      granted = await NotificationService.instance.requestPermission();
    }

    if (!mounted) return;

    if (!granted) {
      setState(() {
        _checkingPermission = false;
        _showPermissionError = true;
        _permPermanentlyDenied = true;
      });
      return;
    }

    setState(() => _checkingPermission = false);

    // Request battery-optimization whitelist so Android/MIUI never blocks
    // our exact alarms — shows a one-time system dialog if not yet granted.
    final isIgnoring = await isIgnoringBatteryOptimizations();
    if (!mounted) return;
    if (!isIgnoring) await requestIgnoreBatteryOptimizations();
    if (!mounted) return;

    widget.onComplete(
      randomAnytime: _randomAnytime,
      startHour: _startTime.hour,
      endHour: _endTime.hour,
      frequency: _frequency,
      activeDays: _activeDays.toList()..sort(),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // ── Back button ───────────────────────────────────────────────────
            TextButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
              label: const Text('Back'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),

            const SizedBox(height: 16),
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
            const SizedBox(height: 28),

            // ── Timing toggle ────────────────────────────────────────────────
            _SectionLabel(label: 'Timing', colorScheme: colorScheme),
            const SizedBox(height: 10),
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

            // ── Time window — matches settings screen exactly ─────────────────
            if (!_randomAnytime) ...[
              const SizedBox(height: 20),
              _SectionLabel(label: 'Time window', colorScheme: colorScheme),
              const SizedBox(height: 10),
              _SectionCard(
                colorScheme: colorScheme,
                child: Column(
                  children: [
                    // Start time row
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.wb_sunny_outlined, size: 20),
                      ),
                      title: const Text(
                        'Start time',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: _TimeChip(
                        label: _formatTime(_startTime),
                        colorScheme: colorScheme,
                        onTap: () => _pickTime(isStart: true),
                      ),
                    ),
                    Divider(height: 1, color: colorScheme.outlineVariant.withOpacity(0.4)),
                    // End time row
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.nights_stay_outlined, size: 20),
                      ),
                      title: const Text(
                        'End time',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: _TimeChip(
                        label: _formatTime(_endTime),
                        colorScheme: colorScheme,
                        onTap: () => _pickTime(isStart: false),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Active days — always visible, matches settings screen ─────────
            const SizedBox(height: 20),
            _SectionLabel(label: 'Active days', colorScheme: colorScheme),
            const SizedBox(height: 10),
            _SectionCard(
              colorScheme: colorScheme,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Preset chips
                    Row(
                      children: [
                        _PresetChip(
                          label: 'Daily',
                          isSelected: _activeDays.length == 7,
                          colorScheme: colorScheme,
                          onTap: () => setState(() => _activeDays = {1, 2, 3, 4, 5, 6, 7}),
                        ),
                        const SizedBox(width: 8),
                        _PresetChip(
                          label: 'Weekdays',
                          isSelected: _activeDays.length == 5 &&
                              _activeDays.every((d) => d <= 5),
                          colorScheme: colorScheme,
                          onTap: () => setState(() => _activeDays = {1, 2, 3, 4, 5}),
                        ),
                        const SizedBox(width: 8),
                        _PresetChip(
                          label: 'Weekends',
                          isSelected: _activeDays.length == 2 &&
                              _activeDays.contains(6) &&
                              _activeDays.contains(7),
                          colorScheme: colorScheme,
                          onTap: () => setState(() => _activeDays = {6, 7}),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Individual day chips
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(7, (index) {
                        final day = index + 1;
                        final isSelected = _activeDays.contains(day);
                        return _DayChip(
                          label: _dayLabels[index],
                          isSelected: isSelected,
                          colorScheme: colorScheme,
                          onTap: () {
                            setState(() {
                              if (isSelected && _activeDays.length > 1) {
                                _activeDays.remove(day);
                              } else if (!isSelected) {
                                _activeDays.add(day);
                              }
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    // Dynamic label
                    Text(
                      _activeDaysLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _activeDays.isEmpty
                            ? colorScheme.error
                            : colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Frequency ────────────────────────────────────────────────────
            const SizedBox(height: 20),
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

            // ── Permission error banner ───────────────────────────────────────
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
                                    'Please allow notifications when prompted.',
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

            // ── Checking spinner ──────────────────────────────────────────────
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_permPermanentlyDenied
                      ? 'Open Notification Settings ↗'
                      : _showPermissionError
                          ? 'Try again'
                          : 'Start Recalling! 🚀'),
            ),

            // Skip option — only shown when permission is denied.
            // Lets the user proceed without notifications and enable them
            // later from the app's settings screen.
            if (_showPermissionError && !_checkingPermission) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => widget.onComplete(
                  randomAnytime: _randomAnytime,
                  startHour: _startTime.hour,
                  endHour: _endTime.hour,
                  frequency: _frequency,
                  activeDays: _activeDays.toList()..sort(),
                ),
                child: Text(
                  'Skip for now — enable notifications later',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],

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

// ── Shared small widgets ───────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.colorScheme});
  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: colorScheme.primary,
        letterSpacing: 1.2,
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

/// Tappable pill chip showing a formatted time — identical style to settings screen.
class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label, required this.colorScheme, required this.onTap});
  final String label;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: colorScheme.onPrimaryContainer,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

/// Daily / Weekdays / Weekends quick-select chip — identical style to settings screen.
class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.isSelected,
    required this.colorScheme,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Individual day square chip — identical style to settings screen.
class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.isSelected,
    required this.colorScheme,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label[0],
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
