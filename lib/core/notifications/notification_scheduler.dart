import 'dart:math';

/// A single computed notification slot: when to fire and which question to show.
class ScheduledSlot {
  final DateTime scheduledAt; // naive local DateTime
  final int questionId;

  const ScheduledSlot({required this.scheduledAt, required this.questionId});
}

/// Pure scheduling logic — no platform channels, no DB, fully unit-testable.
///
/// [computeSlots] takes user settings + available question IDs + current time,
/// and returns every (time, questionId) pair that should be scheduled,
/// with past slots already filtered out.
class NotificationScheduler {
  NotificationScheduler._();

  static const int daysToSchedule = 7;

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
    required DateTime now,
    required List<int> questionIds,
    Random? random,
  }) {
    if (questionIds.isEmpty || frequency <= 0) return [];

    final rng = random ?? Random();
    final slots = <ScheduledSlot>[];
    final weekUsedIds = <int>{};

    final effectiveStart = randomAnytime ? 0 : startHour;
    final effectiveEnd = randomAnytime ? 24 : endHour;

    // Rule: Don't schedule more notifications than we have unique questions per day.
    // This prevents the "same question spam" issue the user reported.
    final dailyFrequency = frequency.clamp(1, questionIds.length);

    for (int dayOffset = 0; dayOffset < daysToSchedule; dayOffset++) {
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

      // Spread the notifications evenly across the minute-window
      // e.g. 8:00 AM to 8:00 PM = 720 minutes. Frequency 3 = one every 240 mins.
      final totalMinutes = (effectiveEnd - effectiveStart) * 60;
      final spacing = totalMinutes / dayQuestionIds.length;

      for (int i = 0; i < dayQuestionIds.length; i++) {
        // Calculate base minute for this slot, then add a small jitter (up to 30% of spacing)
        // to keep it feeling random but guaranteed to be separated.
        final baseOffsetMinutes = (spacing * i).toInt();
        final maxJitter = (spacing * 0.3).toInt().clamp(1, 59);
        final jitter = rng.nextInt(maxJitter);
        
        final totalOffset = baseOffsetMinutes + jitter;
        
        final slotTime = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          effectiveStart,
        ).add(Duration(minutes: totalOffset));

        // Skip slots that have already passed today
        if (slotTime.isAfter(now)) {
          slots.add(ScheduledSlot(
            scheduledAt: slotTime,
            questionId: dayQuestionIds[i],
          ));
        }
      }
    }

    slots.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return slots;
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

    return null; // No more unique questions available for this day
  }
}
