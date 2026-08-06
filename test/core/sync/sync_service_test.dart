// NOTE: these tests only touch static pure helpers — they do NOT construct
// SyncService.instance (its field initializer touches FirebaseFirestore, which
// throws in `flutter test`). Static access is safe.
import 'package:flutter_test/flutter_test.dart';
import 'package:random_recall/core/sync/sync_service.dart';
import 'package:random_recall/models/score_record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncService.chunkRanges', () {
    test('splits into ≤ chunkSize ranges', () {
      expect(SyncService.chunkRanges(1200, chunkSize: 450), [
        (0, 450),
        (450, 900),
        (900, 1200),
      ]);
    });

    test('single range when total < chunkSize', () {
      expect(SyncService.chunkRanges(100, chunkSize: 450), [(0, 100)]);
    });

    test('empty total yields no ranges', () {
      expect(SyncService.chunkRanges(0), isEmpty);
    });
  });

  group('SyncService.tombstonePlan', () {
    test('flattens deterministically by collection then id', () {
      final plan = SyncService.tombstonePlan({
        'questions': {5, 1},
        'categories': {2},
      });
      expect(plan, [('categories', 2), ('questions', 1), ('questions', 5)]);
    });

    test('empty journal yields empty plan', () {
      expect(SyncService.tombstonePlan({}), isEmpty);
    });
  });

  group('SyncService.scoresForSync', () {
    test('keeps records at or after cutoff', () {
      final now = DateTime(2026, 8, 6);
      final cutoff = now.subtract(const Duration(days: 30));
      final tooOld = ScoreRecord(
        questionId: 1,
        categoryId: 1,
        isCorrect: true,
        answeredAt: cutoff.subtract(const Duration(days: 1)),
        updatedAt: now,
      );
      final boundary = ScoreRecord(
        questionId: 2,
        categoryId: 1,
        isCorrect: true,
        answeredAt: cutoff,
        updatedAt: now,
      );
      final recent = ScoreRecord(
        questionId: 3,
        categoryId: 1,
        isCorrect: true,
        answeredAt: now,
        updatedAt: now,
      );
      final result = SyncService.scoresForSync([
        tooOld,
        boundary,
        recent,
      ], cutoff);
      expect(result, [boundary, recent]);
    });
  });

  group('SyncService.hasCloudData', () {
    test('true if questions or scores exist', () {
      expect(
        SyncService.hasCloudData(hasQuestions: true, hasScores: false),
        true,
      );
      expect(
        SyncService.hasCloudData(hasQuestions: false, hasScores: true),
        true,
      );
      expect(
        SyncService.hasCloudData(hasQuestions: true, hasScores: true),
        true,
      );
      expect(
        SyncService.hasCloudData(hasQuestions: false, hasScores: false),
        false,
      );
    });
  });

  group('SyncService.dropTombstoned', () {
    test('drops cloud doc ids present in the tombstone set', () {
      expect(SyncService.dropTombstoned(['1', '2', '3'], {2}), ['1', '3']);
    });

    test('keeps all when tombstone set is empty', () {
      expect(SyncService.dropTombstoned(['1', '2'], {}), ['1', '2']);
    });

    test('ignores non-numeric cloud ids safely', () {
      expect(SyncService.dropTombstoned(['abc', '4'], {4}), ['abc']);
    });
  });

  group('SyncService.keepScoresForRestoredRefs', () {
    ScoreRecord score(int questionId, int categoryId) => ScoreRecord(
      questionId: questionId,
      categoryId: categoryId,
      isCorrect: true,
      answeredAt: DateTime(2026, 8, 6),
      updatedAt: DateTime(2026, 8, 6),
    );

    test('keeps a score whose question and category were both restored', () {
      final kept = score(1, 1);
      expect(SyncService.keepScoresForRestoredRefs([kept], {1}, {1}), [kept]);
    });

    test('drops a score whose question was NOT restored (orphaned)', () {
      final kept = score(1, 1);
      final orphanQuestion = score(99, 1);
      expect(
        SyncService.keepScoresForRestoredRefs([kept, orphanQuestion], {1}, {1}),
        [kept],
      );
    });

    test('drops a score whose category was NOT restored', () {
      final kept = score(1, 1);
      final orphanCategory = score(1, 99);
      expect(
        SyncService.keepScoresForRestoredRefs([kept, orphanCategory], {1}, {1}),
        [kept],
      );
    });
  });
}
