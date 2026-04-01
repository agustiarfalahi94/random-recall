class Category {
  final int? id;
  final String name;
  final String icon;
  final DateTime createdAt;

  const Category({
    this.id,
    required this.name,
    required this.icon,
    required this.createdAt,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      icon: map['icon'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'icon': icon,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Category copyWith({int? id, String? name, String? icon, DateTime? createdAt}) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'Category(id: $id, name: $name, icon: $icon, createdAt: $createdAt)';
}
