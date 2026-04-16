import 'dart:math';
import 'package:timezone/timezone.dart' as tz;

/// A single computed notification slot: when to fire and which question to show.
class ScheduledSlot {
  final tz.TZDateTime scheduledAt; 
  final int questionId;
  final int slotIndex;

  const ScheduledSlot({
    required this.scheduledAt, 
    required this.questionId,
    required this.slotIndex,
  });
}

/// Pure scheduling logic — no platform channels, no DB, fully unit-testable.
///
/// [computeSlots] takes user settings + available question IDs + current time,
/// and returns every (time, questionId) pair that should be scheduled,
/// with past slots already filtered out.
class NotificationScheduler {
  NotificationScheduler._();

  // Schedule 8 days ahead to ensure a full week coverage even if running late Sunday.
  static const int daysToSchedule = 8;

  /// Computes notification slots for the next [daysToSchedule] days.
  ///
  /// Rules:
  ///   1. Only schedules on [activeDays] (1=Mon … 7=Sun).
  ///   2. Slots are evenly spaced within [startHour, endHour) with small jitter.
  ///   3. No question repeats within the same day.
  ///   4. Questions unused this week are preferred over week-repeats.
  ///   5. Slots whose time has already passed [now] are excluded.
  ///
  /// [random] can be injected for deterministic unit tests.
  static List<ScheduledSlot> computeSlots({
    required bool randomAnytime,
    required int startHour,
    required int endHour,
    required int frequency,
    required Set<int> activeDays,
    required tz.TZDateTime now,
    required List<int> questionIds,
    Random? random,
  }) {
    if (questionIds.isEmpty || frequency <= 0) return [];

    final rng = random ?? Random();
    final slots = <ScheduledSlot>[];
    final weekUsedIds = <int>{};

    final effectiveStart = randomAnytime ? 0 : startHour;
    final effectiveEnd = randomAnytime ? 23 : endHour;
    // Overnight window (e.g. 11 PM → 2 AM) wraps around midnight.
    final isOvernight = effectiveEnd < effectiveStart;

    // Allow frequency to exceed question count by repeating questions if necessary.
    final dailyFrequency = frequency;

    for (int dayOffset = 0; dayOffset < daysToSchedule; dayOffset++) {
      // Add duration to 'now' (which is already local) to get the target day
      final targetDate = now.add(Duration(days: dayOffset));
      final weekday = targetDate.weekday; // 1=Mon … 7=Sun

      if (!activeDays.contains(weekday)) continue;

      // Pick distinct questions for this day
      final dayUsedIds = <int>{};
      final dayQuestionIds = <int>[];

      for (int slot = 0; slot < dailyFrequency; slot++) {
        final picked = _pickQuestion(questionIds, weekUsedIds, dayUsedIds, rng);
        if (picked != null) {
          dayQuestionIds.add(picked);
          dayUsedIds.add(picked);
        }
      }

      weekUsedIds.addAll(dayUsedIds);

      // Spread the notifications evenly across the minute-window.
      // For overnight windows (e.g. 23→2), the span wraps: (24 - 23 + 2) = 3 hours.
      final totalMinutes = isOvernight
          ? (24 - effectiveStart + effectiveEnd) * 60
          : (effectiveEnd - effectiveStart) * 60;
      final spacing = totalMinutes / dayQuestionIds.length;

      // Window-end boundary: same day for normal, next day for overnight.
      final windowEnd = tz.TZDateTime(
        tz.local,
        targetDate.year,
        targetDate.month,
        targetDate.day + (isOvernight ? 1 : 0),
        effectiveEnd,
      );

      for (int i = 0; i < dayQuestionIds.length; i++) {
        // Use a deterministic jitter based on the question ID. This prevents the
        // alarm time from "drifting" every time the app reschedules due to a sync.
        final baseOffsetMinutes = (spacing * i).toInt();
        final maxJitter = (spacing * 0.3).toInt().clamp(1, 59);

        // Seed the random with the question ID so the jitter is consistent for this question
        final jitter = Random(dayQuestionIds[i]).nextInt(maxJitter);

        final totalOffset = baseOffsetMinutes + jitter;

        var slotTime = tz.TZDateTime(
          tz.local,
          targetDate.year,
          targetDate.month,
          targetDate.day,
          effectiveStart,
        ).add(Duration(minutes: totalOffset));

        // Ensure jitter doesn't push the slot past the window boundary
        if (!slotTime.isBefore(windowEnd)) {
          slotTime = slotTime.subtract(Duration(minutes: jitter + 1));
        }

        // Skip slots that have already passed today.
        // Buffer of 2 minutes ensures the OS has time to register the alarm.
        if (slotTime.isAfter(now.add(const Duration(minutes: 2)))) {
          slots.add(ScheduledSlot(
            scheduledAt: slotTime,
            questionId: dayQuestionIds[i],
            slotIndex: i,
          ));
        }
      }
    }

    slots.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    // Return only the first 7 days worth of slots (up to max possible alarms)
    return slots.take(100).toList();
  }

  static int? _pickQuestion(
    List<int> all,
    Set<int> weekUsed,
    Set<int> dayUsed,
    Random rng,
  ) {
    // Prefer: not used this week AND not used today
    final preferred = all
        .where((id) => !weekUsed.contains(id) && !dayUsed.contains(id))
        .toList();
    if (preferred.isNotEmpty) return preferred[rng.nextInt(preferred.length)];

    // Fallback: not used today (allow week repeat)
    final dayFresh = all.where((id) => !dayUsed.contains(id)).toList();
    if (dayFresh.isNotEmpty) return dayFresh[rng.nextInt(dayFresh.length)];

    // Final Fallback: Pool exhausted for today. Return any question from the 
    // total pool to satisfy the requested frequency.
    return all[rng.nextInt(all.length)];
  }
}
