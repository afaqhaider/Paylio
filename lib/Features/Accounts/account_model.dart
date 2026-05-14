import 'package:cloud_firestore/cloud_firestore.dart';

class AccountModel {
  final String? id;
  final String name;
  final String type;
  final double openingBalance;
  final String currency;
  final String? bankName;
  final bool isChecking;
  final bool hasDirectDebit;
  final String? notes;
  final bool isActive;
  final double? creditLimit;

  AccountModel({
    this.id,
    required this.name,
    required this.type,
    required this.openingBalance,
    this.currency = 'AED',
    this.bankName,
    this.isChecking = false,
    this.hasDirectDebit = false,
    this.notes,
    this.isActive = true,
    this.creditLimit,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'openingBalance': openingBalance,
      'currency': currency,
      'bankName': bankName,
      'isChecking': isChecking ? 1 : 0,
      'hasDirectDebit': hasDirectDebit ? 1 : 0,
      'notes': notes,
      'isActive': isActive ? 1 : 0,
      'creditLimit': creditLimit,
    };
  }

  factory AccountModel.fromMap(Map<String, dynamic> map) {
    return AccountModel(
      id: map['id']?.toString(),
      name: map['name'] as String? ?? 'Unnamed Account',
      type: map['type'] as String? ?? 'General',
      openingBalance: (map['openingBalance'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] as String? ?? 'AED',
      bankName: map['bankName'] as String?,
      isChecking: map['isChecking'] == 1 || map['isChecking'] == true,
      hasDirectDebit: map['hasDirectDebit'] == 1 || map['hasDirectDebit'] == true,
      notes: map['notes'] as String?,
      isActive: map['isActive'] == 1 || map['isActive'] == true || map['isActive'] == null,
      creditLimit: (map['creditLimit'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type,
      'openingBalance': openingBalance,
      'currency': currency,
      'bankName': bankName,
      'isChecking': isChecking,
      'hasDirectDebit': hasDirectDebit,
      'notes': notes,
      'isActive': isActive,
      'creditLimit': creditLimit,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory AccountModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AccountModel(
      id: doc.id,
      name: data['name']?.toString() ?? '',
      type: data['type']?.toString() ?? '',
      openingBalance: (data['openingBalance'] as num?)?.toDouble() ?? 0.0,
      currency: data['currency']?.toString() ?? 'AED',
      bankName: data['bankName']?.toString(),
      isChecking: data['isChecking'] == true,
      hasDirectDebit: data['hasDirectDebit'] == true,
      notes: data['notes']?.toString(),
      isActive: data['isActive'] ?? true,
      creditLimit: (data['creditLimit'] as num?)?.toDouble(),
    );
  }

  AccountModel copyWith({
    String? id,
    String? name,
    String? type,
    double? openingBalance,
    String? currency,
    String? bankName,
    bool? isChecking,
    bool? hasDirectDebit,
    String? notes,
    bool? isActive,
    double? creditLimit,
  }) {
    return AccountModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      openingBalance: openingBalance ?? this.openingBalance,
      currency: currency ?? this.currency,
      bankName: bankName ?? this.bankName,
      isChecking: isChecking ?? this.isChecking,
      hasDirectDebit: hasDirectDebit ?? this.hasDirectDebit,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      creditLimit: creditLimit ?? this.creditLimit,
    );
  }
}
