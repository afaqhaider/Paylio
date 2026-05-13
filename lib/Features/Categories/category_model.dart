class CategoryModel {
  final int? id;
  final String name;
  final String type; // 'expense' or 'income'
  final String? icon;
  final String? color;
  final bool isDefault;
  final DateTime? createdAt;

  CategoryModel({
    this.id,
    required this.name,
    required this.type,
    this.icon,
    this.color,
    this.isDefault = false,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'icon': icon,
      'color': color,
      'isDefault': isDefault ? 1 : 0,
      'createdAt': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      icon: map['icon'] as String?,
      color: map['color'] as String?,
      isDefault: (map['isDefault'] as int?) == 1,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt'] as String) : null,
    );
  }
}
