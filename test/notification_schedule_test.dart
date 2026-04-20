import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:random_recall/core/notifications/notification_scheduler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

// Pure logic tests — no plugins, no DB, no Flutter context needed.

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  // ── Active days label logic ─────────────────────────────────────────────────

  group('Active days label', () {
    String activeDaysLabel(Set<int> days) {
      if (days.isEmpty) return 'You must choose at least 1!';
      final sorted = days.toList()..sort();
      final isWeekdays =
          sorted.length == 5 && sorted.every((d) => d >= 1 && d <= 5);
      final isWeekends =
          sorted.length == 2 && sorted.contains(6) && sorted.contains(7);
      final isDaily = sorted.length == 7;
      if (isDaily) return 'Every day';
      if (isWeekdays) return 'Weekdays only';
      if (isWeekends) return 'Weekends only';
      const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return sorted.map((d) => dayLabels[d - 1]).join(', ');
    }

    test('all 7 days → Every day', () {
      expect(activeDaysLabel({1, 2, 3, 4, 5, 6, 7}), 'Every day');
    });

    test('Mon–Fri → Weekdays only', () {
      expect(activeDaysLabel({1, 2, 3, 4, 5}), 'Weekdays only');
    });

    test('Sat–Sun → Weekends only', () {
      expect(activeDaysLabel({6, 7}), 'Weekends only');
    });

    test('empty → must choose at least 1', () {
      expect(activeDaysLabel({}), 'You must choose at least 1!');
    });

    test('Mon, Wed, Fri → custom label', () {
      expect(activeDaysLabel({1, 3, 5}), 'Mon, Wed, Fri');
    });

    test('single day → correct label', () {
      expect(activeDaysLabel({3}), 'Wed');
    });
  });

  // ── Frequency label logic ───────────────────────────────────────────────────

  group('Frequency label', () {
    String frequencyLabel(int f) {
      if (f == 1) return 'Once a day — nice and easy';
      if (f <= 3) return '$f times a day — recommended';
      if (f <= 6) return '$f times a day — pretty active';
      if (f <= 9) return '$f times a day — intense!';
      return '10 times a day — maximum';
    }

    test('1 → nice and easy', () {
      expect(frequencyLabel(1), 'Once a day — nice and easy');
    });

    test('2 → recommended', () {
      expect(frequencyLabel(2), '2 times a day — recommended');
    });

    test('3 → recommended', () {
      expect(frequencyLabel(3), '3 times a day — recommended');
    });

    test('5 → pretty active', () {
      expect(frequencyLabel(5), '5 times a day — pretty active');
    });

    test('8 → intense', () {
      expect(frequencyLabel(8), '8 times a day — intense!');
    });

    test('10 → maximum', () {
      expect(frequencyLabel(10), '10 times a day — maximum');
    });
  });

  // ── Time range validation (overnight-aware) ─────────────────────────────────

  group('Time range validation', () {
    /// Mirrors the validation used in notification_schedule_screen _save().
    bool isTimeRangeValid(int startHour, int endHour) {
      final span = (endHour - startHour) % 24;
      return span >= 1;
    }

    test('8am to 8pm → valid', () {
      expect(isTimeRangeValid(8, 20), true);
    });

    test('same hour → invalid', () {
      expect(isTimeRangeValid(9, 9), false);
    });

    test('end before start → valid overnight (e.g. 8pm to 8am)', () {
      expect(isTimeRangeValid(20, 8), true);
    });

    test('midnight to 1am → valid', () {
      expect(isTimeRangeValid(0, 1), true);
    });

    test('11pm to midnight → valid overnight', () {
      expect(isTimeRangeValid(23, 0), true);
    });

    test('10pm to 6am → valid overnight (8 hours)', () {
      expect(isTimeRangeValid(22, 6), true);
    });
  });

  // ── Notification ID uniqueness ──────────────────────────────────────────────

  group('Notification ID generation', () {
    int notifId(int weekday, int slotIndex) => weekday * 100 + slotIndex;

    test('IDs are unique across all weekday+slot combos', () {
      final ids = <int>{};
      for (int day = 1; day <= 7; day++) {
        for (int slot = 0; slot < 10; slot++) {
          final id = notifId(day, slot);
          expect(ids.contains(id), false,
              reason: 'Duplicate ID $id for day=$day slot=$slot');
          ids.add(id);
        }
      }
    });

    test('Mon slot 0 → 100', () => expect(notifId(1, 0), 100));
    test('Mon slot 9 → 109', () => expect(notifId(1, 9), 109));
    test('Sun slot 0 → 700', () => expect(notifId(7, 0), 700));
    test('Sun slot 9 → 709', () => expect(notifId(7, 9), 709));
  });

  // ── Score percentage calculation ────────────────────────────────────────────

  group('Score percentage', () {
    double calcPercentage(int correct, int total) =>
        total > 0 ? (correct / total) * 100 : 0;

    test('10/10 → 100%', () => expect(calcPercentage(10, 10), 100.0));
    test('0/10 → 0%', () => expect(calcPercentage(0, 10), 0.0));
    test('0/0 → 0% (no division by zero)', () =>
        expect(calcPercentage(0, 0), 0.0));
    test('1/2 → 50%', () => expect(calcPercentage(1, 2), 50.0));
    test('7/10 → 70%', () => expect(calcPercentage(7, 10), 70.0));
  });

  // ── NotificationScheduler ───────────────────────────────────────────────────

  group('NotificationScheduler.computeSlots', () {
    // Lazily create after tz.initializeTimeZones() has run in setUpAll.
    late final tz.TZDateTime monday8am;
    const allDays = {1, 2, 3, 4, 5, 6, 7};
    const weekdays = {1, 2, 3, 4, 5};
    const weekends = {6, 7};

    setUpAll(() {
      // Monday 2026-04-06 08:00:00 local
      monday8am = tz.TZDateTime(tz.local, 2026, 4, 6, 8, 0, 0);
    });

    test('returns empty when questionIds is empty', () {
      final slots = NotificationScheduler.computeSlots(
        randomAnytime: true,
        startHour: 8,
        endHour: 20,
        frequency: 3,
        activeDays: allDays,
        now: monday8am,
        questionIds: [],
        random: Random(0),
      );
      expect(slots, isEmpty);
    });

    test('returns empty when frequency is 0', () {
      final slots = NotificationScheduler.computeSlots(
        randomAnytime: true,
        startHour: 8,
        endHour: 20,
        frequency: 0,
        activeDays: allDays,
        now: monday8am,
        questionIds: [1, 2, 3],
        random: Random(0),
      );
      expect(slots, isEmpty);
    });

    test('schedules on all 7 days when all days active', () {
      final slots = NotificationScheduler.computeSlots(
        randomAnytime: false,
        startHour: 8,
        endHour: 20,
        frequency: 1,
        activeDays: allDays,
        now: monday8am,
        questionIds: [1, 2, 3, 4, 5, 6, 7],
        random: Random(0),
      );
      // 7 days × 1 slot = 7, but day 0 (today at 8am) may have some slots
      // already passed — at 08:00 most slots at 8:xx could just make it.
      // We expect at least 6 slots (some may be filtered for being in the past).
      expect(slots.length, greaterThanOrEqualTo(6));
    });

    test('no slots on weekends when only weekdays active', () {
      final slots = NotificationScheduler.computeSlots(
        randomAnytime: true,
        startHour: 0,
        endHour: 23,
        frequency: 2,
        activeDays: weekdays,
        now: monday8am,
        questionIds: [1, 2, 3],
        random: Random(0),
      );
      for (final slot in slots) {
        final weekday = slot.scheduledAt.weekday;
        expect(weekdays.contains(weekday), true,
            reason: 'Found weekend slot: ${slot.scheduledAt}');
      }
    });

    test('no slots on weekdays when only weekends active', () {
      final slots = NotificationScheduler.computeSlots(
        randomAnytime: true,
        startHour: 0,
        endHour: 23,
        frequency: 2,
        activeDays: weekends,
        now: monday8am,
        questionIds: [1, 2, 3],
        random: Random(0),
      );
      for (final slot in slots) {
        final weekday = slot.scheduledAt.weekday;
        expect(weekends.contains(weekday), true,
            reason: 'Found weekday slot: ${slot.scheduledAt}');
      }
    });

    test('all slot times are in the future relative to now', () {
      final slots = NotificationScheduler.computeSlots(
        randomAnytime: true,
        startHour: 0,
        endHour: 23,
        frequency: 3,
        activeDays: allDays,
        now: monday8am,
        questionIds: [1, 2, 3, 4, 5],
        random: Random(0),
      );
      for (final slot in slots) {
        expect(slot.scheduledAt.isAfter(monday8am) ||
               slot.scheduledAt.isAtSameMomentAs(monday8am), true,
            reason: 'Slot in the past: ${slot.scheduledAt}');
      }
    });

    test('all past slots excluded when now is late evening', () {
      // Saturday 23:50 — nearly all of today's slots should be in the past.
      final lateNight = tz.TZDateTime(tz.local, 2026, 4, 11, 23, 50, 0); // Saturday
      final slots = NotificationScheduler.computeSlots(
        randomAnytime: false,
        startHour: 8,
        endHour: 20,
        frequency: 3,
        activeDays: allDays,
        now: lateNight,
        questionIds: [1, 2, 3],
        random: Random(0),
      );
      for (final slot in slots) {
        expect(slot.scheduledAt.isAfter(lateNight), true,
            reason: 'Past slot not filtered: ${slot.scheduledAt}');
      }
    });

    test('no duplicate question IDs within the same day', () {
      final slots = NotificationScheduler.computeSlots(
        randomAnytime: false,
        startHour: 8,
        endHour: 20,
        frequency: 5,
        activeDays: {1}, // Monday only
        now: monday8am,
        questionIds: [1, 2, 3, 4, 5, 6, 7],
        random: Random(0),
      );
      // Group slots by date and check uniqueness within each day
      final byDay = <String, List<int>>{};
      for (final slot in slots) {
        final key =
            '${slot.scheduledAt.year}-${slot.scheduledAt.month}-${slot.scheduledAt.day}';
        byDay.putIfAbsent(key, () => []).add(slot.questionId);
      }
      for (final entry in byDay.entries) {
        final ids = entry.value;
        expect(ids.toSet().length, ids.length,
            reason: 'Duplicate question on ${entry.key}: $ids');
      }
    });

    test('slots are returned sorted by time ascending', () {
      final slots = NotificationScheduler.computeSlots(
        randomAnytime: true,
        startHour: 0,
        endHour: 23,
        frequency: 3,
        activeDays: allDays,
        now: monday8am,
        questionIds: [1, 2, 3, 4, 5],
        random: Random(7),
      );
      for (int i = 1; i < slots.length; i++) {
        expect(
          slots[i].scheduledAt
              .isAfter(slots[i - 1].scheduledAt) ||
          slots[i].scheduledAt
              .isAtSameMomentAs(slots[i - 1].scheduledAt),
          true,
          reason: 'Slots not sorted at index $i',
        );
      }
    });

    test('slot hours respect time range [startHour, endHour)', () {
      for (int seed = 0; seed < 10; seed++) {
        final slots = NotificationScheduler.computeSlots(
          randomAnytime: false,
          startHour: 10,
          endHour: 18,
          frequency: 4,
          activeDays: allDays,
          now: monday8am,
          questionIds: [1, 2, 3, 4, 5],
          random: Random(seed),
        );
        for (final slot in slots) {
          expect(slot.scheduledAt.hour, greaterThanOrEqualTo(10));
          expect(slot.scheduledAt.hour, lessThan(18));
        }
      }
    });

    test('single question in DB — all slots use that question', () {
      final slots = NotificationScheduler.computeSlots(
        randomAnytime: true,
        startHour: 0,
        endHour: 23,
        frequency: 3,
        activeDays: {1}, // Monday only
        now: monday8am,
        questionIds: [42],
        random: Random(0),
      );
      expect(slots, isNotEmpty);
      for (final slot in slots) {
        expect(slot.questionId, 42);
      }
    });

    test('frequency controls max slots per active day', () {
      const freq = 2;
      final slots = NotificationScheduler.computeSlots(
        randomAnytime: false,
        startHour: 8,
        endHour: 20,
        frequency: freq,
        activeDays: allDays,
        now: monday8am,
        questionIds: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
        random: Random(0),
      );
      // Group by date and assert ≤ freq slots per day
      final byDay = <String, int>{};
      for (final slot in slots) {
        final key =
            '${slot.scheduledAt.year}-${slot.scheduledAt.month}-${slot.scheduledAt.day}';
        byDay[key] = (byDay[key] ?? 0) + 1;
      }
      for (final entry in byDay.entries) {
        expect(entry.value, lessThanOrEqualTo(freq),
            reason: '${entry.key} has ${entry.value} slots, max is $freq');
      }
    });

    // ── Overnight window tests ─────────────────────────────────────────────

    test('overnight window 11PM–2AM produces slots', () {
      final slots = NotificationScheduler.computeSlots(
        randomAnytime: false,
        startHour: 23,
        endHour: 2,
        frequency: 3,
        activeDays: allDays,
        now: monday8am,
        questionIds: [1, 2, 3],
        random: Random(0),
      );
      expect(slots, isNotEmpty,
          reason: 'Overnight 23→2 should produce slots');
    });

    test('overnight window 11PM–midnight (1h) produces slots', () {
      final slots = NotificationScheduler.computeSlots(
        randomAnytime: false,
        startHour: 23,
        endHour: 0,
        frequency: 1,
        activeDays: allDays,
        now: monday8am,
        questionIds: [1],
        random: Random(0),
      );
      expect(slots, isNotEmpty,
          reason: 'Overnight 23→0 should produce slots');
      for (final slot in slots) {
        expect(slot.scheduledAt.hour, 23,
            reason: 'Single-hour overnight window: slot must be at hour 23');
      }
    });

    test('overnight slot hours stay within the window bounds', () {
      for (int seed = 0; seed < 10; seed++) {
        final slots = NotificationScheduler.computeSlots(
          randomAnytime: false,
          startHour: 22,
          endHour: 4,
          frequency: 3,
          activeDays: allDays,
          now: monday8am,
          questionIds: [1, 2, 3, 4, 5],
          random: Random(seed),
        );
        for (final slot in slots) {
          final h = slot.scheduledAt.hour;
          // Valid hours for 22→4: 22, 23, 0, 1, 2, 3
          final inWindow = h >= 22 || h < 4;
          expect(inWindow, true,
              reason: 'Seed $seed: hour $h outside overnight window 22→4 '
                  '(${slot.scheduledAt})');
        }
      }
    });

    test('overnight slots are all in the future', () {
      final lateNight = tz.TZDateTime(tz.local, 2026, 4, 6, 22, 0, 0);
      final slots = NotificationScheduler.computeSlots(
        randomAnytime: false,
        startHour: 23,
        endHour: 2,
        frequency: 2,
        activeDays: allDays,
        now: lateNight,
        questionIds: [1, 2, 3],
        random: Random(0),
      );
      for (final slot in slots) {
        expect(slot.scheduledAt.isAfter(lateNight), true,
            reason: 'Past slot: ${slot.scheduledAt}');
      }
    });
  });
}
