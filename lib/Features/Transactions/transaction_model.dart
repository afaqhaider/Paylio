class TransactionModel {
  final int? id;
  final String type; // income, expense, transfer, borrow, lend, repayment_received, repayment_paid
  final String category;
  final String account;
  final String? toAccount;
  final String note;
  final double amount;
  final DateTime date;
  final String? attachmentPath;
  final int? personId; // Linked person for borrow/lend

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
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      type: map['type'],
      category: map['category'],
      account: map['account'],
      toAccount: map['toAccount'],
      note: map['note'],
      amount: (map['amount'] as num).toDouble(),
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      attachmentPath: map['attachmentPath'],
      personId: map['personId'],
    );
  }

  TransactionModel copyWith({
    int? id,
    String? type,
    String? category,
    String? account,
    String? toAccount,
    String? note,
    double? amount,
    DateTime? date,
    String? attachmentPath,
    int? personId,
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
    );
  }
}
