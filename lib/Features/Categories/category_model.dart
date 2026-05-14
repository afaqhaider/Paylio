import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryModel {
  final String? id;
  final String name;
  final String type; // 'expense' or 'income'
  final String? icon;
  final String? color;
  final bool isDefault;
  final bool isActive;
  final DateTime? createdAt;

  CategoryModel({
    this.id,
    required this.name,
    required this.type,
    this.icon,
    this.color,
    this.isDefault = false,
    this.isActive = true,
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
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id']?.toString(),
      name: map['name'] as String,
      type: map['type'] as String,
      icon: map['icon'] as String?,
      color: map['color'] as String?,
      isDefault: map['isDefault'] == 1 || map['isDefault'] == true,
      isActive: map['isActive'] == 1 || map['isActive'] == true || map['isActive'] == null,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt'] as String) : null,
    );
  }

  static DateTime? parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type,
      'icon': icon,
      'color': color,
      'isDefault': isDefault,
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CategoryModel(
      id: doc.id,
      name: data['name']?.toString() ?? '',
      type: data['type']?.toString() ?? '',
      icon: data['icon']?.toString(),
      color: data['color']?.toString(),
      isDefault: data['isDefault'] == true,
      isActive: data['isActive'] ?? true,
      createdAt: parseDate(data['createdAt']),
    );
  }
}
