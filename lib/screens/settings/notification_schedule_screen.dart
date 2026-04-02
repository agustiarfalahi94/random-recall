import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/streak/streak_service.dart';

class NotificationScheduleScreen extends StatefulWidget {
  const NotificationScheduleScreen({super.key, this.scrollToTimer = false});

  /// When true, the screen will auto-scroll to the Challenge Mode section.
  final bool scrollToTimer;

  @override
  State<NotificationScheduleScreen> createState() =>
      _NotificationScheduleScreenState();
}

class _NotificationScheduleScreenState
    extends State<NotificationScheduleScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  final _scrollController = ScrollController();
  final _timerSectionKey = GlobalKey();

  // Prefs state
  bool _randomAnytime = true;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 20, minute: 0);
  int _frequency = 3; // 1–10
  Set<int> _activeDays = {1, 2, 3, 4, 5}; // 1=Mon … 7=Sun
  int _timerSeconds = 0; // 0 = off

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  // Timer slider: 0 = off, then 5–90 in steps of 5 (18 divisions)

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final daysStr = prefs.getString('notif_active_days') ?? '1,2,3,4,5';
    setState(() {
      _randomAnytime = prefs.getBool('notif_random_anytime') ?? true;
      _startTime = TimeOfDay(
        hour: prefs.getInt('notif_start_hour') ?? 8,
        minute: 0,
      );
      _endTime = TimeOfDay(
        hour: prefs.getInt('notif_end_hour') ?? 20,
        minute: 0,
      );
      _frequency = (prefs.getInt('notif_frequency') ?? 3).clamp(1, 10);
      _activeDays = daysStr.split(',').map(int.parse).toSet();
      _timerSeconds = prefs.getInt('notif_timer_seconds') ?? 0;
      _isLoading = false;
    });

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
    // Since notification slots are spaced by hour, the window must span at
    // least 1 full hour (e.g. 1 PM start requires 2 PM or later end).
    if (!_randomAnytime && _endTime.hour <= _startTime.hour) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be at least 1 hour after start time.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_activeDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one active day.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notif_random_anytime', _randomAnytime);
      await prefs.setInt('notif_start_hour', _startTime.hour);
      await prefs.setInt('notif_end_hour', _endTime.hour);
      await prefs.setInt('notif_frequency', _frequency);
      final sortedDays = _activeDays.toList()..sort();
      await prefs.setString('notif_active_days', sortedDays.join(','));
      await prefs.setInt('notif_timer_seconds', _timerSeconds);

      await NotificationService.instance.scheduleNotifications();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification schedule saved! 🔔'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
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

  String get _activeDaysLabel {
    if (_activeDays.isEmpty) return 'You must choose at least 1!';
    final sorted = _activeDays.toList()..sort();
    final isWeekdays =
        sorted.length == 5 && sorted.every((d) => d >= 1 && d <= 5);
    final isWeekends =
        sorted.length == 2 && sorted.contains(6) && sorted.contains(7);
    final isDaily = sorted.length == 7;
    if (isDaily) return 'Every day';
    if (isWeekdays) return 'Weekdays only';
    if (isWeekends) return 'Weekends only';
    return sorted.map((d) => _dayLabels[d - 1]).join(', ');
  }

  Color _activeDaysLabelColor(ColorScheme cs) =>
      _activeDays.isEmpty ? cs.error : cs.primary;

  // ── Frequency label ────────────────────────────────────────────────────────

  String _frequencyLabel(int f) {
    if (f == 1) return 'Once a day — nice and easy';
    if (f <= 3) return '$f times a day — recommended';
    if (f <= 6) return '$f times a day — pretty active';
    if (f <= 9) return '$f times a day — intense!';
    return '10 times a day — maximum';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timeDisabled = _randomAnytime;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notification Schedule',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              children: [
                // ── 🔥 Challenge Mode (top — most exciting feature) ───────────
                Container(
                  key: _timerSectionKey,
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primaryContainer,
                        colorScheme.secondaryContainer,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fire emoji scales up when timer is in the challenge zone
                      _ChallengeFireDisplay(timerSeconds: _timerSeconds),
                      const SizedBox(height: 8),
                      Text(
                        'Challenge\nMode',
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: colorScheme.onPrimaryContainer,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _timerSeconds == 0
                            ? 'Set timer to ${StreakService.challengeThreshold}s or less → '
                                'answer daily → hit a 7-day streak → earn +1 free question slot!'
                            : _timerSeconds <= StreakService.challengeThreshold
                                ? '🔥 Challenge active! Keep going daily for 7 days to earn +1 free question slot!'
                                : 'Timer is too relaxed. Lower it to ${StreakService.challengeThreshold}s or less to activate the challenge.',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onPrimaryContainer.withOpacity(0.85),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

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
                                const Text(
                                  'Response timer',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  _timerSeconds == 0
                                      ? 'No time limit — relaxed mode'
                                      : 'Auto-marks wrong if time runs out',
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
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_timerSeconds}s',
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
                      Slider(
                        value: _timerSeconds.toDouble(),
                        min: 0,
                        max: 90,
                        divisions: 18, // 0, 5, 10 … 90
                        label: _timerSeconds == 0
                            ? 'Off'
                            : '${_timerSeconds}s',
                        onChanged: (v) =>
                            setState(() => _timerSeconds = v.round()),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Off',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurfaceVariant)),
                          Text('90s',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── Timing ───────────────────────────────────────────────────
                _SectionHeader(label: 'Timing', theme: theme),
                const SizedBox(height: 12),

                _SettingCard(
                  colorScheme: colorScheme,
                  child: Column(
                    children: [
                      // Anytime switch
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Send at any time',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Notifications arrive throughout the day',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        value: _randomAnytime,
                        onChanged: (v) => setState(() => _randomAnytime = v),
                      ),

                      Divider(
                        height: 1,
                        color: colorScheme.outlineVariant.withOpacity(0.4),
                      ),

                      // Start time — always visible, dimmed when anytime is on
                      Opacity(
                        opacity: timeDisabled ? 0.35 : 1.0,
                        child: IgnorePointer(
                          ignoring: timeDisabled,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.wb_sunny_outlined,
                                  size: 20),
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
                        ),
                      ),

                      Divider(
                        height: 1,
                        color: colorScheme.outlineVariant.withOpacity(0.4),
                      ),

                      // End time — always visible, dimmed when anytime is on
                      Opacity(
                        opacity: timeDisabled ? 0.35 : 1.0,
                        child: IgnorePointer(
                          ignoring: timeDisabled,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.nights_stay_outlined,
                                  size: 20),
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
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Frequency ─────────────────────────────────────────────────
                _SectionHeader(label: 'Frequency', theme: theme),
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
                                const Text(
                                  'Notifications per day',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  _frequencyLabel(_frequency),
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
                      Slider(
                        value: _frequency.toDouble(),
                        min: 1,
                        max: 10,
                        divisions: 9,
                        label: '$_frequency',
                        onChanged: (v) =>
                            setState(() => _frequency = v.round()),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('1',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurfaceVariant)),
                          Text('10',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Active days ───────────────────────────────────────────────
                _SectionHeader(label: 'Active Days', theme: theme),
                const SizedBox(height: 12),

                _SettingCard(
                  colorScheme: colorScheme,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick-select presets
                      Row(
                        children: [
                          _PresetChip(
                            label: 'Daily',
                            isSelected: _activeDays.length == 7,
                            colorScheme: colorScheme,
                            onTap: () => setState(
                                () => _activeDays = {1, 2, 3, 4, 5, 6, 7}),
                          ),
                          const SizedBox(width: 8),
                          _PresetChip(
                            label: 'Weekdays',
                            isSelected: _activeDays.length == 5 &&
                                _activeDays.every((d) => d <= 5),
                            colorScheme: colorScheme,
                            onTap: () => setState(
                                () => _activeDays = {1, 2, 3, 4, 5}),
                          ),
                          const SizedBox(width: 8),
                          _PresetChip(
                            label: 'Weekends',
                            isSelected: _activeDays.length == 2 &&
                                _activeDays.contains(6) &&
                                _activeDays.contains(7),
                            colorScheme: colorScheme,
                            onTap: () =>
                                setState(() => _activeDays = {6, 7}),
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
                          color: _activeDaysLabelColor(colorScheme),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

      // ── Save button ──────────────────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: FilledButton.icon(
            onPressed: (_isLoading || _isSaving) ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_isSaving ? 'Saving...' : 'Save Schedule'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Challenge fire display ────────────────────────────────────────────────────

/// Shows 1, 2, or 3 fire emojis depending on timer intensity.
/// - 0 (off): one small dimmed fire
/// - 21–90s (too relaxed): one normal fire
/// - 5–20s (challenge zone!): THREE large fires side by side
class _ChallengeFireDisplay extends StatelessWidget {
  const _ChallengeFireDisplay({required this.timerSeconds});
  final int timerSeconds;

  @override
  Widget build(BuildContext context) {
    final isChallenge =
        timerSeconds > 0 && timerSeconds <= StreakService.challengeThreshold;
    final isOff = timerSeconds == 0;

    if (isChallenge) {
      // Full blaze — three big fires
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text('🔥', style: TextStyle(fontSize: 52)),
          SizedBox(width: 2),
          Text('🔥', style: TextStyle(fontSize: 44)),
          SizedBox(width: 2),
          Text('🔥', style: TextStyle(fontSize: 36)),
        ],
      );
    }

    // Single fire: big but dimmed when off, normal when relaxed
    return Opacity(
      opacity: isOff ? 0.45 : 0.7,
      child: Text(
        '🔥',
        style: TextStyle(fontSize: isOff ? 28 : 36),
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({super.key, required this.label, required this.theme});
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
  const _SettingCard({required this.colorScheme, required this.child});
  final ColorScheme colorScheme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: child,
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip(
      {required this.label,
      required this.colorScheme,
      required this.onTap});
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
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
