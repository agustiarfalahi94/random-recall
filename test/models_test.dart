import 'package:flutter_test/flutter_test.dart';
import 'package:random_recall/models/category.dart';
import 'package:random_recall/models/question.dart';
import 'package:random_recall/models/score_record.dart';

void main() {
  // Required so the Flutter test runner sets up native plugin method channels
  // before any package code is compiled (prevents Dart VM crash on native libs).
  TestWidgetsFlutterBinding.ensureInitialized();
  // ── Category model ──────────────────────────────────────────────────────────

  group('Category', () {
    test('fromMap creates correct object', () {
      final map = {
        'id': 1,
        'name': 'Work',
        'icon': '💼',
        'created_at': '2024-01-01T00:00:00.000',
      };
      final category = Category.fromMap(map);
      expect(category.id, 1);
      expect(category.name, 'Work');
      expect(category.icon, '💼');
    });

    test('toMap produces correct map', () {
      final category = Category(
        id: 2,
        name: 'Coffee',
        icon: '☕',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      final map = category.toMap();
      expect(map['id'], 2);
      expect(map['name'], 'Coffee');
      expect(map['icon'], '☕');
    });

    test('copyWith updates only specified fields', () {
      final original = Category(
        id: 1,
        name: 'Work',
        icon: '💼',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      final updated = original.copyWith(name: 'Study');
      expect(updated.name, 'Study');
      expect(updated.icon, '💼'); // unchanged
      expect(updated.id, 1); // unchanged
    });
  });

  // ── Question model ──────────────────────────────────────────────────────────

  group('Question', () {
    test('fromMap creates correct object', () {
      final map = {
        'id': 10,
        'question': 'What is RAM?',
        'answer': 'Random Access Memory',
        'category_id': 1,
        'created_at': '2024-01-01T00:00:00.000',
      };
      final q = Question.fromMap(map);
      expect(q.id, 10);
      expect(q.question, 'What is RAM?');
      expect(q.answer, 'Random Access Memory');
      expect(q.categoryId, 1);
    });

    test('toMap omits id when null', () {
      final q = Question(
        question: 'What is RAM?',
        answer: 'Random Access Memory',
        categoryId: 1,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      final map = q.toMap();
      expect(map.containsKey('id'), false);
    });

    test('toMap includes id when set', () {
      final q = Question(
        id: 5,
        question: 'What is RAM?',
        answer: 'Random Access Memory',
        categoryId: 1,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      final map = q.toMap();
      expect(map['id'], 5);
    });

    test('copyWith updates question text only', () {
      final original = Question(
        id: 1,
        question: 'Old question',
        answer: 'Old answer',
        categoryId: 2,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      final updated = original.copyWith(question: 'New question');
      expect(updated.question, 'New question');
      expect(updated.answer, 'Old answer'); // unchanged
      expect(updated.categoryId, 2); // unchanged
    });
  });

  // ── ScoreRecord model ───────────────────────────────────────────────────────

  group('ScoreRecord', () {
    test('fromMap maps isCorrect int to bool — correct (1)', () {
      final map = {
        'id': 1,
        'question_id': 10,
        'category_id': 1,
        'is_correct': 1,
        'answered_at': '2024-01-01T00:00:00.000',
      };
      final record = ScoreRecord.fromMap(map);
      expect(record.isCorrect, true);
    });

    test('fromMap maps isCorrect int to bool — wrong (0)', () {
      final map = {
        'id': 2,
        'question_id': 10,
        'category_id': 1,
        'is_correct': 0,
        'answered_at': '2024-01-01T00:00:00.000',
      };
      final record = ScoreRecord.fromMap(map);
      expect(record.isCorrect, false);
    });

    test('toMap converts bool isCorrect to int', () {
      final record = ScoreRecord(
        questionId: 10,
        categoryId: 1,
        isCorrect: true,
        answeredAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      final map = record.toMap();
      expect(map['is_correct'], 1);
    });

    test('toMap converts bool isCorrect false to 0', () {
      final record = ScoreRecord(
        questionId: 10,
        categoryId: 1,
        isCorrect: false,
        answeredAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      final map = record.toMap();
      expect(map['is_correct'], 0);
    });
  });
}
