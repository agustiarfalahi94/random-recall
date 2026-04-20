class Question {
  final int? id;
  final String question;
  final String answer;
  final int categoryId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Question({
    this.id,
    required this.question,
    required this.answer,
    required this.categoryId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      id: map['id'] as int?,
      question: map['question'] as String,
      answer: map['answer'] as String,
      categoryId: map['category_id'] as int,
      createdAt: DateTime.parse(
        map['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        map['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'question': question,
      'answer': answer,
      'category_id': categoryId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Question copyWith({
    int? id,
    String? question,
    String? answer,
    int? categoryId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Question(
      id: id ?? this.id,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'Question(id: $id, question: $question, categoryId: $categoryId)';
}
