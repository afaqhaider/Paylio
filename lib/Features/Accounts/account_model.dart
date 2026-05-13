import 'package:cloud_firestore/cloud_firestore.dart';

class AccountModel {
  final String? id;
  final String name;
  final String type;
  final double openingBalance;
  final double? creditLimit;
  final bool hasDirectDebit;

  AccountModel({
    this.id,
    required this.name,
    required this.type,
    required this.openingBalance,
    this.creditLimit,
    this.hasDirectDebit = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'openingBalance': openingBalance,
      'creditLimit': creditLimit,
      'hasDirectDebit': hasDirectDebit,
    };
  }

  factory AccountModel.fromMap(Map<String, dynamic> map) {
    return AccountModel(
      id: map['id']?.toString(),
      name: map['name'] as String? ?? 'Unnamed Account',
      type: map['type'] as String? ?? 'General',
      openingBalance: (map['openingBalance'] as num?)?.toDouble() ?? 0.0,
      creditLimit: (map['creditLimit'] as num?)?.toDouble(),
      hasDirectDebit: map['hasDirectDebit'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type,
      'openingBalance': openingBalance,
      'creditLimit': creditLimit,
      'hasDirectDebit': hasDirectDebit,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory AccountModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AccountModel(
      id: doc.id,
      name: data['name'] ?? '',
      type: data['type'] ?? '',
      openingBalance: (data['openingBalance'] as num?)?.toDouble() ?? 0.0,
      creditLimit: (data['creditLimit'] as num?)?.toDouble(),
      hasDirectDebit: data['hasDirectDebit'] ?? false,
    );
  }

  AccountModel copyWith({
    String? id,
    String? name,
    String? type,
    double? openingBalance,
    double? creditLimit,
    bool? hasDirectDebit,
  }) {
    return AccountModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      openingBalance: openingBalance ?? this.openingBalance,
      creditLimit: creditLimit ?? this.creditLimit,
      hasDirectDebit: hasDirectDebit ?? this.hasDirectDebit,
    );
  }
}
