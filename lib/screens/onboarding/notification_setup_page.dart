import 'package:flutter/material.dart';

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

class _NotificationSetupPageState extends State<NotificationSetupPage> {
  bool _randomAnytime = true;
  int _startHour = 8;
  int _endHour = 20;
  int _frequency = 3;
  final Set<int> _activeDays = {1, 2, 3, 4, 5};

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour == 12) return '12 PM';
    if (hour < 12) return '$hour AM';
    return '${hour - 12} PM';
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = TimeOfDay(hour: isStart ? _startHour : _endHour, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: isStart ? 'Select start time' : 'Select end time',
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startHour = picked.hour;
        if (_endHour <= _startHour) {
          _endHour = (_startHour + 1).clamp(0, 23);
        }
      } else {
        if (picked.hour > _startHour) {
          _endHour = picked.hour;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('End time must be after start time'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  void _onComplete() {
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

            // Step indicator
            _buildStepIndicator(colorScheme),

            const SizedBox(height: 28),

            Text(
              'When should we\nremind you?',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
                letterSpacing: -0.3,
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

            // Timing mode toggle
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

            // Time range pickers (conditional)
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
                    checkmarkColor: colorScheme.primary,
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
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  );
                }),
              ),
            ],

            const SizedBox(height: 24),

            // Frequency
            _SectionLabel(label: 'How many times per day?', colorScheme: colorScheme),
            const SizedBox(height: 10),

            _SectionCard(
              colorScheme: colorScheme,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
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

            ElevatedButton(
              onPressed: _onComplete,
              child: const Text('Start Recalling! 🚀'),
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
        final isActive = index < 3;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index < 2 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: isActive
                  ? (index == 2 ? colorScheme.primary : colorScheme.primaryContainer)
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}

// Helper widgets

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
