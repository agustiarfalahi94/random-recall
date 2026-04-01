import 'package:flutter_test/flutter_test.dart';

// Pure logic tests — no plugins, no DB, no Flutter context needed.
// Tests the scheduling logic that lives in NotificationService.

void main() {
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

  // ── Time range validation ───────────────────────────────────────────────────

  group('Time range validation', () {
    bool isTimeRangeValid(int startHour, int endHour) =>
        startHour < endHour;

    test('8am to 8pm → valid', () {
      expect(isTimeRangeValid(8, 20), true);
    });

    test('same hour → invalid', () {
      expect(isTimeRangeValid(9, 9), false);
    });

    test('end before start → invalid', () {
      expect(isTimeRangeValid(20, 8), false);
    });

    test('midnight to 1am → valid', () {
      expect(isTimeRangeValid(0, 1), true);
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
}
