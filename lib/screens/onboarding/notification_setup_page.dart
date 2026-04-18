import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/utils/battery_optimization.dart';

typedef OnNotificationSetupComplete =
    void Function({
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

  List<String> _getDayLabels(AppLocalizations l10n) => [
    l10n.dayMon,
    l10n.dayTue,
    l10n.dayWed,
    l10n.dayThu,
    l10n.dayFri,
    l10n.daySat,
    l10n.daySun,
  ];

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
    final l10n = AppLocalizations.of(context)!;
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      helpText: isStart ? l10n.selectStartTime : l10n.selectEndTime,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
        if (_endTime.hour <= _startTime.hour) {
          _endTime = TimeOfDay(
            hour: (_startTime.hour + 1).clamp(0, 23),
            minute: 0,
          );
        }
      } else {
        _endTime = picked;
      }
    });
  }

  String _activeDaysLabel(AppLocalizations l10n) {
    if (_activeDays.isEmpty) return l10n.mustChooseDay;
    final sorted = _activeDays.toList()..sort();
    final isWeekdays =
        sorted.length == 5 && sorted.every((d) => d >= 1 && d <= 5);
    final isWeekends =
        sorted.length == 2 && sorted.contains(6) && sorted.contains(7);
    final isDaily = sorted.length == 7;
    if (isDaily) return l10n.everyDay;
    if (isWeekdays) return l10n.weekdaysOnly;
    if (isWeekends) return l10n.weekendsOnly;
    final dayLabels = _getDayLabels(l10n);
    return sorted.map((d) => dayLabels[d - 1]).join(', ');
  }

  Future<void> _onComplete() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_randomAnytime && _endTime.hour <= _startTime.hour) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.endTimeMustBeAfter),
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
    super.build(context);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dayLabels = _getDayLabels(l10n);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            TextButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
              label: Text(l10n.back),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),

            const SizedBox(height: 16),
            _buildStepIndicator(colorScheme),
            const SizedBox(height: 28),
            Text(
              l10n.notifSetupTitle,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.notifSetupSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),

            _SectionLabel(label: l10n.timingSection, colorScheme: colorScheme),
            const SizedBox(height: 10),
            _SectionCard(
              colorScheme: colorScheme,
              child: Column(
                children: [
                  _TimingOptionTile(
                    title: l10n.anytimeOption,
                    subtitle: l10n.anytimeSubtitle,
                    icon: '🎲',
                    isSelected: _randomAnytime,
                    colorScheme: colorScheme,
                    onTap: () => setState(() => _randomAnytime = true),
                  ),
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withOpacity(0.4),
                  ),
                  _TimingOptionTile(
                    title: l10n.setTimeRange,
                    subtitle: l10n.setTimeRangeSubtitle,
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
              _SectionLabel(
                label: l10n.timeWindowSection,
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 10),
              _SectionCard(
                colorScheme: colorScheme,
                child: Column(
                  children: [
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
                      title: Text(
                        l10n.startTime,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: _TimeChip(
                        label: _formatTime(_startTime),
                        colorScheme: colorScheme,
                        onTap: () => _pickTime(isStart: true),
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: colorScheme.outlineVariant.withOpacity(0.4),
                    ),
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
                      title: Text(
                        l10n.endTime,
                        style: const TextStyle(fontWeight: FontWeight.w600),
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

            const SizedBox(height: 20),
            _SectionLabel(
              label: l10n.activeDaysSection,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 10),
            _SectionCard(
              colorScheme: colorScheme,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _PresetChip(
                          label: l10n.presetDaily,
                          isSelected: _activeDays.length == 7,
                          colorScheme: colorScheme,
                          onTap: () => setState(
                            () => _activeDays = {1, 2, 3, 4, 5, 6, 7},
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PresetChip(
                          label: l10n.presetWeekdays,
                          isSelected:
                              _activeDays.length == 5 &&
                              _activeDays.every((d) => d <= 5),
                          colorScheme: colorScheme,
                          onTap: () =>
                              setState(() => _activeDays = {1, 2, 3, 4, 5}),
                        ),
                        const SizedBox(width: 8),
                        _PresetChip(
                          label: l10n.presetWeekends,
                          isSelected:
                              _activeDays.length == 2 &&
                              _activeDays.contains(6) &&
                              _activeDays.contains(7),
                          colorScheme: colorScheme,
                          onTap: () => setState(() => _activeDays = {6, 7}),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(7, (index) {
                        final day = index + 1;
                        final isSelected = _activeDays.contains(day);
                        return _DayChip(
                          label: dayLabels[index],
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
                    Text(
                      _activeDaysLabel(l10n),
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

            const SizedBox(height: 20),
            _SectionLabel(
              label: l10n.howManyTimesPerDay,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 10),
            _SectionCard(
              colorScheme: colorScheme,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 4.0,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _frequency > 1
                          ? () => setState(() => _frequency--)
                          : null,
                      icon: const Icon(Icons.remove_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.primaryContainer,
                        foregroundColor: colorScheme.onPrimaryContainer,
                        disabledBackgroundColor:
                            colorScheme.surfaceContainerHighest,
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
                            _frequency == 1
                                ? l10n.timePerDay
                                : l10n.timesPerDay,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _frequency < 10
                          ? () => setState(() => _frequency++)
                          : null,
                      icon: const Icon(Icons.add_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.primaryContainer,
                        foregroundColor: colorScheme.onPrimaryContainer,
                        disabledBackgroundColor:
                            colorScheme.surfaceContainerHighest,
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
                    Icon(
                      Icons.notifications_off_rounded,
                      color: colorScheme.onErrorContainer,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.notificationsOff,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onErrorContainer,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _permPermanentlyDenied
                                ? l10n.notifPermDeniedMsg
                                : l10n.notifNeedsPermission,
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
                    l10n.checkingPermission,
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
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _permPermanentlyDenied
                          ? l10n.openNotifSettings
                          : _showPermissionError
                          ? l10n.tryAgain
                          : l10n.startRecalling,
                    ),
            ),

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
                  l10n.skipForNow,
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
              color: index == 2
                  ? colorScheme.primary
                  : colorScheme.primaryContainer,
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
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
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
                  ? Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: colorScheme.onPrimary,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.label,
    required this.colorScheme,
    required this.onTap,
  });
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
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

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
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label[0],
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
