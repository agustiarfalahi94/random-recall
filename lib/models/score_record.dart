class ScoreRecord {
  final int? id;
  final int questionId;
  final int categoryId;
  final bool isCorrect;
  final DateTime answeredAt;
  final DateTime updatedAt;

  const ScoreRecord({
    this.id,
    required this.questionId,
    required this.categoryId,
    required this.isCorrect,
    required this.answeredAt,
    required this.updatedAt,
  });

  factory ScoreRecord.fromMap(Map<String, dynamic> map) {
    return ScoreRecord(
      id: map['id'] as int?,
      questionId: map['question_id'] as int,
      categoryId: map['category_id'] as int,
      isCorrect: (map['is_correct'] as int) == 1,
      answeredAt: DateTime.parse(map['answered_at']?.toString() ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at']?.toString() ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'question_id': questionId,
      'category_id': categoryId,
      'is_correct': isCorrect ? 1 : 0,
      'answered_at': answeredAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ScoreRecord copyWith({
    int? id, int? questionId, int? categoryId,
    bool? isCorrect, DateTime? answeredAt, DateTime? updatedAt,
  }) {
    return ScoreRecord(
      id: id ?? this.id,
      questionId: questionId ?? this.questionId,
      categoryId: categoryId ?? this.categoryId,
      isCorrect: isCorrect ?? this.isCorrect,
      answeredAt: answeredAt ?? this.answeredAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'ScoreRecord(id: $id, questionId: $questionId, isCorrect: $isCorrect)';
}
