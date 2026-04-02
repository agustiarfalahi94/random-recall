class Category {
  final int? id;
  final String name;
  final String icon;
  final DateTime createdAt;
  /// True for the two seeded categories (General, Work).
  /// Default categories are hidden from category management and cannot be deleted.
  final bool isDefault;

  const Category({
    this.id,
    required this.name,
    required this.icon,
    required this.createdAt,
    this.isDefault = false,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      icon: map['icon'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      isDefault: (map['is_default'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'icon': icon,
      'created_at': createdAt.toIso8601String(),
      'is_default': isDefault ? 1 : 0,
    };
  }

  Category copyWith({
    int? id,
    String? name,
    String? icon,
    DateTime? createdAt,
    bool? isDefault,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  String toString() =>
      'Category(id: $id, name: $name, icon: $icon, isDefault: $isDefault, createdAt: $createdAt)';
}
