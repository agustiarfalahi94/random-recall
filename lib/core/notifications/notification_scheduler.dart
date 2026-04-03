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
    final effectiveEnd = randomAnytime ? 23 : endHour;

    for (int dayOffset = 0; dayOffset < daysToSchedule; dayOffset++) {
      final targetDate = now.add(Duration(days: dayOffset));
      final weekday = targetDate.weekday; // 1=Mon … 7=Sun

      if (!activeDays.contains(weekday)) continue;

      // Pick distinct questions for this day
      final dayUsedIds = <int>{};
      final dayQuestionIds = <int>[];

      for (int slot = 0; slot < frequency; slot++) {
        final picked = _pickQuestion(questionIds, weekUsedIds, dayUsedIds, rng);
        if (picked != null) {
          dayQuestionIds.add(picked);
          dayUsedIds.add(picked);
        }
      }

      weekUsedIds.addAll(dayUsedIds);

      final slotHours = generateSlotHours(
        effectiveStart, effectiveEnd, dayQuestionIds.length, rng,
      );

      for (int i = 0; i < dayQuestionIds.length; i++) {
        final minute = rng.nextInt(60);
        final scheduledAt = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          slotHours[i],
          minute,
        );

        // Skip slots that have already passed
        if (scheduledAt.isBefore(now)) continue;

        slots.add(ScheduledSlot(
          scheduledAt: scheduledAt,
          questionId: dayQuestionIds[i],
        ));
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

    // Last resort: any question (single-question DB edge case)
    return all[rng.nextInt(all.length)];
  }

  /// Generates [count] evenly-spaced hours in [[start], [end]),
  /// with a small random jitter so notifications don't feel mechanical.
  ///
  /// Result is always clamped to [[start], [end] - 1].
  static List<int> generateSlotHours(
      int start, int end, int count, Random rng) {
    if (count <= 0) return [];
    final window = (end - start).clamp(1, 23);
    final spacing = window / count;
    return List.generate(count, (i) {
      final base = start + (spacing * i).round();
      final maxJitter = (spacing / 2).floor().clamp(0, 2);
      final jitter = maxJitter > 0 ? rng.nextInt(maxJitter + 1) : 0;
      return (base + jitter).clamp(start, end - 1);
    });
  }
}
