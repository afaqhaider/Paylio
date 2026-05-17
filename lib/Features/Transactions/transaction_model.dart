import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String? id;
  final String type; // income, expense, transfer, loan_given, loan_received, repayment_received, repayment_paid
  final String category;
  final String account;
  final String? toAccount;
  final String note;
  final double amount;
  final DateTime date;
  final String? attachmentPath;
  final String? personId; 
  final String? parentLoanId; 
  final String status; // 'approved', 'pending_approval', 'rejected'
  final double? proposedAmount; 
  final DateTime? approvedAt;

  TransactionModel({
    this.id,
    required this.type,
    required this.category,
    required this.account,
    this.toAccount,
    required this.note,
    required this.amount,
    required this.date,
    this.attachmentPath,
    this.personId,
    this.parentLoanId,
    this.status = 'approved',
    this.proposedAmount,
    this.approvedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'category': category,
      'account': account,
      'toAccount': toAccount,
      'note': note,
      'amount': amount,
      'date': date.toIso8601String(),
      'attachmentPath': attachmentPath,
      'personId': personId,
      'parentLoanId': parentLoanId,
      'status': status,
      'proposedAmount': proposedAmount,
      'approvedAt': approvedAt?.toIso8601String(),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id']?.toString(),
      type: map['type'],
      category: map['category'],
      account: map['account'],
      toAccount: map['toAccount'],
      note: map['note'],
      amount: (map['amount'] as num).toDouble(),
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      attachmentPath: map['attachmentPath'],
      personId: map['personId']?.toString(),
      parentLoanId: map['parentLoanId']?.toString(),
      status: map['status'] ?? 'approved',
      proposedAmount: (map['proposedAmount'] as num?)?.toDouble(),
      approvedAt: map['approvedAt'] != null ? DateTime.parse(map['approvedAt']) : null,
    );
  }

  static DateTime parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'category': category,
      'account': account,
      'toAccount': toAccount,
      'note': note,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'attachmentPath': attachmentPath,
      'personId': personId,
      'parentLoanId': parentLoanId,
      'status': status,
      'proposedAmount': proposedAmount,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      type: data['type']?.toString() ?? '',
      category: data['category']?.toString() ?? '',
      account: data['account']?.toString() ?? '',
      toAccount: data['toAccount']?.toString(),
      note: data['note']?.toString() ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      date: parseDate(data['date']),
      attachmentPath: data['attachmentPath']?.toString(),
      personId: data['personId']?.toString(),
      parentLoanId: data['parentLoanId']?.toString(),
      status: data['status']?.toString() ?? 'approved',
      proposedAmount: (data['proposedAmount'] as num?)?.toDouble(),
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
    );
  }

  TransactionModel copyWith({
    String? id,
    String? type,
    String? category,
    String? account,
    String? toAccount,
    String? note,
    double? amount,
    DateTime? date,
    String? attachmentPath,
    String? personId,
    String? parentLoanId,
    String? status,
    double? proposedAmount,
    DateTime? approvedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      category: category ?? this.category,
      account: account ?? this.account,
      toAccount: toAccount ?? this.toAccount,
      note: note ?? this.note,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      attachmentPath: attachmentPath ?? this.attachmentPath,
      personId: personId ?? this.personId,
      parentLoanId: parentLoanId ?? this.parentLoanId,
      status: status ?? this.status,
      proposedAmount: proposedAmount ?? this.proposedAmount,
      approvedAt: approvedAt ?? this.approvedAt,
    );
  }
}
