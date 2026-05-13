import 'package:cloud_firestore/cloud_firestore.dart';

class BudgetModel {
  final String? id;
  final String category;
  final double amountLimit;
  final String period; // 'Monthly', 'Weekly'
  final int month;
  final int year;
  final String? notes;

  BudgetModel({
    this.id,
    required this.category,
    required this.amountLimit,
    required this.period,
    required this.month,
    required this.year,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'amountLimit': amountLimit,
      'period': period,
      'month': month,
      'year': year,
      'notes': notes,
    };
  }

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      id: map['id']?.toString(),
      category: map['category'] as String? ?? 'Uncategorized',
      amountLimit: (map['amountLimit'] as num?)?.toDouble() ?? 0.0,
      period: map['period'] as String? ?? 'Monthly',
      month: map['month'] as int? ?? DateTime.now().month,
      year: map['year'] as int? ?? DateTime.now().year,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'category': category,
      'amountLimit': amountLimit,
      'period': period,
      'month': month,
      'year': year,
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory BudgetModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BudgetModel(
      id: doc.id,
      category: data['category'] ?? '',
      amountLimit: (data['amountLimit'] as num?)?.toDouble() ?? 0.0,
      period: data['period'] ?? 'Monthly',
      month: data['month'] ?? 1,
      year: data['year'] ?? 2024,
      notes: data['notes'],
    );
  }

  BudgetModel copyWith({
    String? id,
    String? category,
    double? amountLimit,
    String? period,
    int? month,
    int? year,
    String? notes,
  }) {
    return BudgetModel(
      id: id ?? this.id,
      category: category ?? this.category,
      amountLimit: amountLimit ?? this.amountLimit,
      period: period ?? this.period,
      month: month ?? this.month,
      year: year ?? this.year,
      notes: notes ?? this.notes,
    );
  }
}
