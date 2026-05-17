import 'package:cloud_firestore/cloud_firestore.dart';

class SharedTransactionModel {
  final String? id;
  final String creatorUserId;
  final String creatorDisplayName;
  final String targetUserId;
  final String targetDisplayName;
  
  final double originalAmount;
  final String originalCurrency;
  final double convertedAmount;
  final String receiverCurrency;
  final double exchangeRate;
  
  final double proposedAmount; // The initial amount sent by the creator
  final double? finalApprovedAmount; // The amount eventually agreed upon

  final String type; // 'lend', 'borrow', 'repayment_sent', 'repayment_received'
  final String description;
  final String category;
  final String account;
  final String status; // 'pending_approval', 'approved', 'rejected', 'returned_with_changes'
  
  final DateTime createdAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final DateTime? updatedAt;
  
  final String? originalTransactionId;
  final bool editedByReceiver;

  SharedTransactionModel({
    this.id,
    required this.creatorUserId,
    required this.creatorDisplayName,
    required this.targetUserId,
    required this.targetDisplayName,
    required this.originalAmount,
    required this.originalCurrency,
    required this.convertedAmount,
    required this.receiverCurrency,
    required this.exchangeRate,
    required this.proposedAmount,
    this.finalApprovedAmount,
    required this.type,
    required this.description,
    required this.category,
    required this.account,
    this.status = 'pending_receiver_approval',
    required this.createdAt,
    this.approvedAt,
    this.rejectedAt,
    this.updatedAt,
    this.originalTransactionId,
    this.editedByReceiver = false,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'creatorUserId': creatorUserId,
      'creatorDisplayName': creatorDisplayName,
      'targetUserId': targetUserId,
      'targetDisplayName': targetDisplayName,
      'originalAmount': originalAmount,
      'originalCurrency': originalCurrency,
      'convertedAmount': convertedAmount,
      'receiverCurrency': receiverCurrency,
      'exchangeRate': exchangeRate,
      'proposedAmount': proposedAmount,
      'finalApprovedAmount': finalApprovedAmount,
      'type': type,
      'description': description,
      'category': category,
      'account': account,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'rejectedAt': rejectedAt != null ? Timestamp.fromDate(rejectedAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'originalTransactionId': originalTransactionId,
      'editedByReceiver': editedByReceiver,
    };
  }

  factory SharedTransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SharedTransactionModel(
      id: doc.id,
      creatorUserId: data['creatorUserId'] ?? '',
      creatorDisplayName: data['creatorDisplayName'] ?? '',
      targetUserId: data['targetUserId'] ?? '',
      targetDisplayName: data['targetDisplayName'] ?? '',
      originalAmount: (data['originalAmount'] as num?)?.toDouble() ?? 0.0,
      originalCurrency: data['originalCurrency'] ?? '',
      convertedAmount: (data['convertedAmount'] as num?)?.toDouble() ?? 0.0,
      receiverCurrency: data['receiverCurrency'] ?? '',
      exchangeRate: (data['exchangeRate'] as num?)?.toDouble() ?? 1.0,
      proposedAmount: (data['proposedAmount'] as num?)?.toDouble() ?? (data['originalAmount'] as num?)?.toDouble() ?? 0.0,
      finalApprovedAmount: (data['finalApprovedAmount'] as num?)?.toDouble(),
      type: data['type'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      account: data['account'] ?? '',
      status: data['status'] ?? 'pending_approval',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      rejectedAt: (data['rejectedAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      originalTransactionId: data['originalTransactionId'],
      editedByReceiver: data['editedByReceiver'] ?? false,
    );
  }

  SharedTransactionModel copyWith({
    String? id,
    String? status,
    DateTime? approvedAt,
    DateTime? rejectedAt,
    DateTime? updatedAt,
    double? originalAmount,
    double? convertedAmount,
    double? exchangeRate,
    double? proposedAmount,
    double? finalApprovedAmount,
    String? description,
    bool? editedByReceiver,
  }) {
    return SharedTransactionModel(
      id: id ?? this.id,
      creatorUserId: creatorUserId,
      creatorDisplayName: creatorDisplayName,
      targetUserId: targetUserId,
      targetDisplayName: targetDisplayName,
      originalAmount: originalAmount ?? this.originalAmount,
      originalCurrency: originalCurrency,
      convertedAmount: convertedAmount ?? this.convertedAmount,
      receiverCurrency: receiverCurrency,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      proposedAmount: proposedAmount ?? this.proposedAmount,
      finalApprovedAmount: finalApprovedAmount ?? this.finalApprovedAmount,
      type: type,
      description: description ?? this.description,
      category: category,
      account: account,
      status: status ?? this.status,
      createdAt: createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      originalTransactionId: originalTransactionId,
      editedByReceiver: editedByReceiver ?? this.editedByReceiver,
    );
  }
}
