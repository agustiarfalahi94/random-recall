import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:random_recall/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/services/analytics_service.dart';
import '../../core/streak/streak_service.dart';
import '../../core/sync/sync_service.dart';
import '../../core/utils/battery_optimization.dart';
import '../../core/utils/device_info.dart';
import '../../widgets/miui_battery_dialog.dart';
import '../debug/debug_notification_screen.dart';

class NotificationScheduleScreen extends StatefulWidget {
  const NotificationScheduleScreen({
    super.key,
    this.scrollToTimer = false,
    this.isStartingChallenge = false,
    this.challengeDuration = 7,
  });

  /// When true, the screen will auto-scroll to the Timer section.
  final bool scrollToTimer;

  /// When true, the user is starting a new challenge from the home screen.
  /// The timer is restricted to 5 or 10 s; saving locks the notification
  /// settings and activates the challenge.
  final bool isStartingChallenge;

  /// Duration of the challenge being started (7 or 14 days).
  final int challengeDuration;

  @override
  State<NotificationScheduleScreen> createState() =>
      _NotificationScheduleScreenState();
}

class _NotificationScheduleScreenState
    extends State<NotificationScheduleScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isMiui = false;
  bool _isIgnoringBattery = true; // assume OK until checked

  final _scrollController = ScrollController();
  final _timerSectionKey = GlobalKey();

  // Prefs state
  bool _randomAnytime = true;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 20, minute: 0);
  int _frequency = 3; // 1–10
  Set<int> _activeDays = {1, 2, 3, 4, 5, 6, 7}; // 1=Mon … 7=Sun
  int _timerSeconds = 0; // 0 = off

  // Snapshot of values as-loaded from prefs — used to detect unsaved changes.
  bool _savedRandomAnytime = true;
  TimeOfDay _savedStartTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _savedEndTime = const TimeOfDay(hour: 20, minute: 0);
  int _savedFrequency = 3;
  Set<int> _savedActiveDays = {1, 2, 3, 4, 5, 6, 7};
  int _savedTimerSeconds = 0;

  bool get _hasChanges {
    if (widget.isStartingChallenge) return true;
    return _randomAnytime != _savedRandomAnytime ||
        _startTime != _savedStartTime ||
        _endTime != _savedEndTime ||
        _frequency != _savedFrequency ||
        !_setEquals(_activeDays, _savedActiveDays) ||
        _timerSeconds != _savedTimerSeconds;
  }

  bool _setEquals(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);

  int _debugTaps = 0;

  void _handleDebugTap() {
    _debugTaps++;
    if (_debugTaps >= 7) {
      _debugTaps = 0;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DebugNotificationScreen()),
      );
    }
  }

  // Timer slider: 0 = off, then 5–90 in steps of 5 (18 divisions)

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
    _loadPrefs();
    isMiuiDevice().then((v) {
      if (mounted) setState(() => _isMiui = v);
    });
    isIgnoringBatteryOptimizations().then((v) {
      if (mounted) setState(() => _isIgnoringBattery = v);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final daysStr = prefs.getString('notif_active_days') ?? '1,2,3,4,5,6,7';
    final loadedRandomAnytime = prefs.getBool('notif_random_anytime') ?? true;
    final loadedStartTime = TimeOfDay(hour: prefs.getInt('notif_start_hour') ?? 8, minute: 0);
    final loadedEndTime = TimeOfDay(hour: prefs.getInt('notif_end_hour') ?? 20, minute: 0);
    final loadedFrequency = (prefs.getInt('notif_frequency') ?? 3).clamp(1, 10);
    final loadedActiveDays = daysStr.split(',').map(int.parse).toSet();
    final loadedTimerSeconds = prefs.getInt('notif_timer_seconds') ?? 0;

    setState(() {
      _randomAnytime = loadedRandomAnytime;
      _startTime = loadedStartTime;
      _endTime = loadedEndTime;
      _frequency = loadedFrequency;
      _activeDays = loadedActiveDays;
      // When starting a challenge the timer must be 5 or 10 s.
      // If the current setting is outside that range, clamp to 5 s.
      _timerSeconds = widget.isStartingChallenge
          ? loadedTimerSeconds.clamp(5, 10)
          : loadedTimerSeconds;

      // Snapshot for change-detection
      _savedRandomAnytime = loadedRandomAnytime;
      _savedStartTime = loadedStartTime;
      _savedEndTime = loadedEndTime;
      _savedFrequency = loadedFrequency;
      _savedActiveDays = Set.from(loadedActiveDays);
      _savedTimerSeconds = loadedTimerSeconds;

      _isLoading = false;
    });

    // If a challenge is active, enforce locked values in the UI.
    if (StreakService.instance.isChallengeActive) {
      final lockedAnytime = StreakService.instance.lockedRandomAnytime;
      final lockedDays = StreakService.instance.lockedActiveDaysCsv;
      if (mounted) {
        setState(() {
          if (lockedAnytime != null) _randomAnytime = lockedAnytime;
          if (lockedDays != null) {
            _activeDays = lockedDays.split(',').map(int.parse).toSet();
          }
          // Timer is also locked when challenge active
          if (StreakService.instance.isChallengeActive) {
            _timerSeconds = loadedTimerSeconds.clamp(5, 10);
          }
        });
      }
    }

    // Auto-scroll to timer section if requested
    if (widget.scrollToTimer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _timerSectionKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            alignment: 0.1, // place near top with a small offset
          );
        }
      });
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final isChallengeActive = StreakService.instance.isChallengeActive;

    // Challenge setup: timer must be 5 or 10 seconds only.
    if (widget.isStartingChallenge && (_timerSeconds != 5 && _timerSeconds != 10)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.challengeTimerRequirementSnack),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // The window must span at least 1 hour. Overnight windows (e.g. 11 PM → 2 AM)
    // are valid — the span wraps around midnight.
    if (!_randomAnytime) {
      final span = (_endTime.hour - _startTime.hour) % 24;
      if (span < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.timeWindowError),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    if (_activeDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.selectActiveDayError),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Show confirmation before committing the challenge.
    if (widget.isStartingChallenge) {
      final confirmed = await _showChallengeConfirmationDialog();
      if (!confirmed) return;
    }

    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();

      // Determine the effective anytime setting to lock in for the challenge.
      final lockedAnytime = StreakService.instance.lockedRandomAnytime;
      final effectiveAnytime = isChallengeActive && lockedAnytime != null
          ? lockedAnytime
          : _randomAnytime;

      await prefs.setBool('notif_random_anytime', effectiveAnytime);
      await prefs.setInt('notif_start_hour', _startTime.hour);
      await prefs.setInt('notif_end_hour', _endTime.hour);
      await prefs.setInt('notif_frequency', _frequency);
      final sortedDays = _activeDays.toList()..sort();
      await prefs.setString('notif_active_days', sortedDays.join(','));
      await prefs.setInt('notif_timer_seconds', _timerSeconds);

      // Activate the challenge, locking frequency, active days, anytime mode, and timer.
      if (widget.isStartingChallenge) {
        await StreakService.instance.startChallenge(
          widget.challengeDuration,
          _frequency,
          lockedActiveDaysCsv: sortedDays.join(','),
          lockedRandomAnytime: effectiveAnytime,
          timerSeconds: _timerSeconds,
        );
      }

      bool notifScheduledOk = true;
      try {
        await NotificationService.instance.scheduleNotifications();
      } on PlatformException catch (pe) {
        if (pe.code == 'exact_alarms_not_permitted') {
          notifScheduledOk = false;
        } else {
          rethrow;
        }
      }

      AnalyticsService.instance
          .trackScheduleChanged(
            frequency: _frequency,
            randomAnytime: _randomAnytime,
            timerSeconds: _timerSeconds,
          )
          .ignore();

      // Manually trigger a backup since settings live in SharedPreferences, not the DB
      await SyncService.instance.performBackup();

      if (!mounted) return;

      if (!notifScheduledOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.exactAlarmPermissionWarning),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isStartingChallenge
                  ? l10n.challengeActivatedSnack(widget.challengeDuration)
                  : l10n.scheduleSavedSnack,
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.saveFailedSnack(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool> _showChallengeConfirmationDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final d = widget.challengeDuration;

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.challengeConfirmTitle(d)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.challengeConfirmRequirementsTitle),
              const SizedBox(height: 8),
              _buildRequirementBullet(l10n.challengeConfirmRequirementAnswers),
              _buildRequirementBullet(l10n.challengeConfirmRequirementTimer(_timerSeconds)),
              _buildRequirementBullet(l10n.challengeConfirmRequirementDays(d)),
              const SizedBox(height: 12),
              Text(
                l10n.challengeConfirmFooter,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.challengeWarningStart),
          ),
        ],
      ),
    ) ?? false;
  }

  Widget _buildRequirementBullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(text, style: const TextStyle(fontSize: 13)),
    );
  }

  Future<void> _pickTime({required bool isStart}) async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      helpText: isStart ? l10n.selectStartTime : l10n.selectEndTime,
      // Force English locale inside the picker so AM/PM renders consistently
      // across all app languages (avoids locale-specific layout differences).
      builder: (context, child) => Localizations.override(
        context: context,
        locale: const Locale('en'),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
        // Auto-set end time to start + 1 hour, preserving the picked minutes.
        // e.g. start = 2:30 PM → end = 3:30 PM (not 3:00 PM).
        _endTime = TimeOfDay(hour: (picked.hour + 1) % 24, minute: picked.minute);
      } else {
        _endTime = picked;
      }
    });
  }

  String _formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  // ── Active days label ──────────────────────────────────────────────────────

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

  Color _activeDaysLabelColor(ColorScheme cs) =>
      _activeDays.isEmpty ? cs.error : cs.primary;

  // ── Frequency label ────────────────────────────────────────────────────────

  String _frequencyLabel(int f, AppLocalizations l10n) {
    if (f == 1) return l10n.freqOnce;
    if (f <= 3) return l10n.freqRecommended(f);
    if (f <= 6) return l10n.freqActive(f);
    if (f <= 9) return l10n.freqIntense(f);
    return l10n.freqMax;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dayLabels = _getDayLabels(l10n);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final challengeActive = StreakService.instance.isChallengeActive;
    final lockedAnytime = StreakService.instance.lockedRandomAnytime;
    // During challenge: honour the anytime mode that was locked at start.
    final effectiveAnytime = challengeActive && lockedAnytime != null
        ? lockedAnytime
        : _randomAnytime;
    final timePickersDisabled = effectiveAnytime;
    final anytimeSwitchDisabled = challengeActive;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _handleDebugTap,
          child: Text(
            l10n.notifScheduleTitle,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              children: [
                _SettingCard(
                  key: _timerSectionKey,
                  colorScheme: colorScheme,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.responseTimer,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (challengeActive)
                                  Text(
                                    l10n.lockedDuringChallenge,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colorScheme.error,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  )
                                else
                                  Text(
                                    _timerSeconds == 0
                                        ? l10n.noTimeLimit
                                        : l10n.autoMarksWrong,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (_timerSeconds > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$_timerSeconds${l10n.secondsUnit}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Challenge active or setup: restrict timer to 5-10 s only.
                      if (challengeActive || widget.isStartingChallenge)
                        Opacity(
                          opacity: challengeActive ? 0.5 : 1.0,
                          child: Slider(
                            value: _timerSeconds.clamp(5, 10).toDouble(),
                            min: 5,
                            max: 10,
                            divisions: 1,
                            label: '$_timerSeconds${l10n.secondsUnit}',
                            onChanged: challengeActive
                                ? null
                                : (v) => setState(() => _timerSeconds = v.round()),
                          ),
                        )
                      else
                        Slider(
                          value: _timerSeconds.toDouble(),
                          min: 0,
                          max: 90,
                          divisions: 18,
                          label: _timerSeconds == 0
                              ? l10n.off
                              : '$_timerSeconds${l10n.secondsUnit}',
                          onChanged: (v) =>
                              setState(() => _timerSeconds = v.round()),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            (challengeActive || widget.isStartingChallenge) ? '5${l10n.secondsUnit}' : l10n.off,
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            (challengeActive || widget.isStartingChallenge)
                                ? '10${l10n.secondsUnit}'
                                : '90${l10n.secondsUnit}',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── Timing ───────────────────────────────────────────────────
                _SectionHeader(label: l10n.timingSection, theme: theme),
                const SizedBox(height: 12),

                _SettingCard(
                  colorScheme: colorScheme,
                  child: Column(
                    children: [
                      Opacity(
                        opacity: anytimeSwitchDisabled ? 0.35 : 1.0,
                        child: IgnorePointer(
                          ignoring: anytimeSwitchDisabled,
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              l10n.sendAtAnyTime,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              l10n.sendAtAnyTimeSubtitle,
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                            value: effectiveAnytime,
                            onChanged: (v) => setState(() => _randomAnytime = v),
                          ),
                        ),
                      ),

                      Divider(
                        height: 1,
                        color: colorScheme.outlineVariant.withOpacity(0.4),
                      ),

                      // Start time — always visible, dimmed when anytime is on
                      Opacity(
                        opacity: timePickersDisabled ? 0.35 : 1.0,
                        child: IgnorePointer(
                          ignoring: timePickersDisabled,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.wb_sunny_outlined,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              l10n.startTime,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: _TimeChip(
                              label: _formatTime(_startTime),
                              colorScheme: colorScheme,
                              onTap: () => _pickTime(isStart: true),
                            ),
                          ),
                        ),
                      ),

                      Divider(
                        height: 1,
                        color: colorScheme.outlineVariant.withOpacity(0.4),
                      ),

                      // End time — always visible, dimmed when anytime is on
                      Opacity(
                        opacity: timePickersDisabled ? 0.35 : 1.0,
                        child: IgnorePointer(
                          ignoring: timePickersDisabled,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.nights_stay_outlined,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              l10n.endTime,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: _TimeChip(
                              label: _formatTime(_endTime),
                              colorScheme: colorScheme,
                              onTap: () => _pickTime(isStart: false),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Frequency ─────────────────────────────────────────────────
                _SectionHeader(label: l10n.frequencySection, theme: theme),
                const SizedBox(height: 12),

                _SettingCard(
                  colorScheme: colorScheme,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.notifPerDay,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (challengeActive)
                                  Text(
                                    '${l10n.lockedDuringChallenge}: ${StreakService.instance.lockedFrequency}/day',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  )
                                else
                                  Text(
                                    _frequencyLabel(_frequency, l10n),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '$_frequency',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      if (challengeActive)
                        Opacity(
                          opacity: 0.5,
                          child: Slider(
                            value: StreakService.instance.lockedFrequency.toDouble(),
                            min: StreakService.instance.lockedFrequency.toDouble(),
                            max: StreakService.instance.lockedFrequency.toDouble(),
                            divisions: 1,
                            label: '${StreakService.instance.lockedFrequency}',
                            onChanged: null,
                          ),
                        )
                      else
                        Slider(
                          value: _frequency.toDouble(),
                          min: 1,
                          max: 50,
                          divisions: 49,
                          label: '$_frequency',
                          onChanged: (v) =>
                              setState(() => _frequency = v.round()),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '1',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '50',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Active days ───────────────────────────────────────────────
                _SectionHeader(
                  label: l10n.activeDaysSectionTitle,
                  theme: theme,
                ),
                const SizedBox(height: 12),

                _SettingCard(
                  colorScheme: colorScheme,
                  child: Opacity(
                    opacity: challengeActive ? 0.5 : 1.0,
                    child: IgnorePointer(
                      ignoring: challengeActive,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Quick-select presets
                          Row(
                            children: [
                              Expanded(
                                child: _PresetChip(
                                  label: l10n.presetDaily,
                                  isSelected: _activeDays.length == 7,
                                  colorScheme: colorScheme,
                                  onTap: () => setState(
                                    () => _activeDays = {1, 2, 3, 4, 5, 6, 7},
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _PresetChip(
                                  label: l10n.presetWeekdays,
                                  isSelected:
                                      _activeDays.length == 5 &&
                                      _activeDays.every((d) => d <= 5),
                                  colorScheme: colorScheme,
                                  onTap: () =>
                                      setState(() => _activeDays = {1, 2, 3, 4, 5}),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _PresetChip(
                                  label: l10n.presetWeekends,
                                  isSelected:
                                      _activeDays.length == 2 &&
                                      _activeDays.contains(6) &&
                                      _activeDays.contains(7),
                                  colorScheme: colorScheme,
                                  onTap: () => setState(() => _activeDays = {6, 7}),
                                ),
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

                          // Dynamic label
                          Text(
                            challengeActive
                                ? l10n.lockedDuringChallenge
                                : _activeDaysLabel(l10n),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _activeDaysLabelColor(colorScheme),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // ── Battery optimisation whitelist ───────────────────────────
                if (!_isIgnoringBattery) ...[
                  const SizedBox(height: 12),
                  _BatteryOptimizationCard(
                    onTap: () async {
                      await requestIgnoreBatteryOptimizations();
                      // Re-check after user returns from the system dialog
                      final v = await isIgnoringBatteryOptimizations();
                      if (mounted) setState(() => _isIgnoringBattery = v);
                    },
                  ),
                ],

                // ── MIUI / HyperOS battery tip ───────────────────────────────
                if (_isMiui) ...[
                  const SizedBox(height: 12),
                  _MiuiHelpCard(onTap: () => MiuiBatteryDialog.show(context)),
                ],
              ],
            ),

      // ── Save button ──────────────────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: FilledButton.icon(
            onPressed: (_isLoading || _isSaving)
                ? null
                : _hasChanges
                    ? _save
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.noSettingsChanged),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_isSaving ? l10n.saving : l10n.saveSchedule),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              disabledBackgroundColor: null, // keep default disabled style
            ).copyWith(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) return null;
                if (!_hasChanges) {
                  return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12);
                }
                return null; // use default filled colour
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) return null;
                if (!_hasChanges) {
                  return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38);
                }
                return null;
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.theme});
  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({super.key, required this.colorScheme, required this.child});
  final ColorScheme colorScheme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: child,
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
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
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

// ── MIUI help card ─────────────────────────────────────────────────────────────

class _MiuiHelpCard extends StatelessWidget {
  const _MiuiHelpCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.tertiaryContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.tertiary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.battery_saver_rounded,
              color: colorScheme.tertiary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.miuiFixTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: colorScheme.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.of(context)!.miuiFixSubtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onTertiaryContainer.withValues(
                        alpha: 0.75,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.tertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Battery optimisation fix card ──────────────────────────────────────────────

class _BatteryOptimizationCard extends StatelessWidget {
  const _BatteryOptimizationCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.battery_alert_rounded,
              color: colorScheme.error,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.batteryOptOn,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.of(context)!.batteryOptSubtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onErrorContainer.withValues(
                        alpha: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.error,
              size: 20,
            ),
          ],
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
