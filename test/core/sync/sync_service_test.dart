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
}
