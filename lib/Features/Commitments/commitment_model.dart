import 'package:cloud_firestore/cloud_firestore.dart';

class CommitmentModel {
  final String? id;
  final String name;
  final String type; // Rent, Utility, EMI, Insurance, Subscription, etc.
  final double amount;
  final String linkedAccount;
  final DateTime dueDate;
  final String frequency; // Monthly, Weekly, Quarterly, Yearly, One-time
  final int reminderDays;
  final String? notes;
  final List<String> attachments;
  final String status; // Upcoming, Paid, Overdue, Skipped
  final DateTime? nextDueDate;
  
  // Rent specific
  final String? propertyName;
  final String? landlordName;
  final int? numberOfCheques;
  final List<Map<String, dynamic>>? rentCheques; // [{amount, dueDate, status, chequeNumber}]

  // Utility specific
  final String? providerName;
  final String? accountNumber;

  // EMI specific
  final String? bankName;
  final double? originalLoanAmount;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool autoDebit;

  CommitmentModel({
    this.id,
    required this.name,
    required this.type,
    required this.amount,
    required this.linkedAccount,
    required this.dueDate,
    required this.frequency,
    this.reminderDays = 3,
    this.notes,
    this.attachments = const [],
    this.status = 'Upcoming',
    this.nextDueDate,
    this.propertyName,
    this.landlordName,
    this.numberOfCheques,
    this.rentCheques,
    this.providerName,
    this.accountNumber,
    this.bankName,
    this.originalLoanAmount,
    this.startDate,
    this.endDate,
    this.autoDebit = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'amount': amount,
      'linkedAccount': linkedAccount,
      'dueDate': dueDate.toIso8601String(),
      'frequency': frequency,
      'reminderDays': reminderDays,
      'notes': notes,
      'attachments': attachments,
      'status': status,
      'nextDueDate': nextDueDate?.toIso8601String(),
      'propertyName': propertyName,
      'landlordName': landlordName,
      'numberOfCheques': numberOfCheques,
      'rentCheques': rentCheques,
      'providerName': providerName,
      'accountNumber': accountNumber,
      'bankName': bankName,
      'originalLoanAmount': originalLoanAmount,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'autoDebit': autoDebit,
    };
  }

  factory CommitmentModel.fromMap(Map<String, dynamic> map) {
    return CommitmentModel(
      id: map['id'],
      name: map['name'],
      type: map['type'],
      amount: (map['amount'] as num).toDouble(),
      linkedAccount: map['linkedAccount'],
      dueDate: DateTime.parse(map['dueDate']),
      frequency: map['frequency'],
      reminderDays: map['reminderDays'] ?? 3,
      notes: map['notes'],
      attachments: (map['attachments'] as List?)?.map((e) => e.toString()).toList() ?? [],
      status: map['status'] ?? 'Upcoming',
      nextDueDate: map['nextDueDate'] != null ? DateTime.parse(map['nextDueDate']) : null,
      propertyName: map['propertyName'],
      landlordName: map['landlordName'],
      numberOfCheques: map['numberOfCheques'],
      rentCheques: (map['rentCheques'] as List?)
          ?.whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      providerName: map['providerName'],
      accountNumber: map['accountNumber'],
      bankName: map['bankName'],
      originalLoanAmount: map['originalLoanAmount'] != null ? (map['originalLoanAmount'] as num).toDouble() : null,
      startDate: map['startDate'] != null ? DateTime.parse(map['startDate']) : null,
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
      autoDebit: map['autoDebit'] ?? false,
    );
  }

  static DateTime parseDate(dynamic value, {DateTime? fallback}) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? fallback ?? DateTime.now();
    return fallback ?? DateTime.now();
  }

  static DateTime? parseOptionalDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Map<String, dynamic> toFirestore() {
    final map = toMap();
    map.remove('id');
    map['dueDate'] = Timestamp.fromDate(dueDate);
    if (nextDueDate != null) map['nextDueDate'] = Timestamp.fromDate(nextDueDate!);
    if (startDate != null) map['startDate'] = Timestamp.fromDate(startDate!);
    if (endDate != null) map['endDate'] = Timestamp.fromDate(endDate!);
    map['updatedAt'] = FieldValue.serverTimestamp();
    return map;
  }

  factory CommitmentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommitmentModel(
      id: doc.id,
      name: data['name']?.toString() ?? '',
      type: data['type']?.toString() ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      linkedAccount: data['linkedAccount']?.toString() ?? '',
      dueDate: parseDate(data['dueDate']),
      frequency: data['frequency']?.toString() ?? 'Monthly',
      reminderDays: data['reminderDays'] ?? 3,
      notes: data['notes']?.toString(),
      attachments: (data['attachments'] as List?)?.map((e) => e.toString()).toList() ?? [],
      status: data['status']?.toString() ?? 'Upcoming',
      nextDueDate: parseOptionalDate(data['nextDueDate']),
      propertyName: data['propertyName']?.toString(),
      landlordName: data['landlordName']?.toString(),
      numberOfCheques: data['numberOfCheques'] as int?,
      rentCheques: (data['rentCheques'] as List?)
          ?.whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      providerName: data['providerName']?.toString(),
      accountNumber: data['accountNumber']?.toString(),
      bankName: data['bankName']?.toString(),
      originalLoanAmount: (data['originalLoanAmount'] as num?)?.toDouble(),
      startDate: parseOptionalDate(data['startDate']),
      endDate: parseOptionalDate(data['endDate']),
      autoDebit: data['autoDebit'] == true,
    );
  }

  CommitmentModel copyWith({
    String? id,
    String? name,
    String? type,
    double? amount,
    String? linkedAccount,
    DateTime? dueDate,
    String? frequency,
    int? reminderDays,
    String? notes,
    List<String>? attachments,
    String? status,
    DateTime? nextDueDate,
    String? propertyName,
    String? landlordName,
    int? numberOfCheques,
    List<Map<String, dynamic>>? rentCheques,
    String? providerName,
    String? accountNumber,
    String? bankName,
    double? originalLoanAmount,
    DateTime? startDate,
    DateTime? endDate,
    bool? autoDebit,
  }) {
    return CommitmentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      linkedAccount: linkedAccount ?? this.linkedAccount,
      dueDate: dueDate ?? this.dueDate,
      frequency: frequency ?? this.frequency,
      reminderDays: reminderDays ?? this.reminderDays,
      notes: notes ?? this.notes,
      attachments: attachments ?? this.attachments,
      status: status ?? this.status,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      propertyName: propertyName ?? this.propertyName,
      landlordName: landlordName ?? this.landlordName,
      numberOfCheques: numberOfCheques ?? this.numberOfCheques,
      rentCheques: rentCheques ?? this.rentCheques,
      providerName: providerName ?? this.providerName,
      accountNumber: accountNumber ?? this.accountNumber,
      bankName: bankName ?? this.bankName,
      originalLoanAmount: originalLoanAmount ?? this.originalLoanAmount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      autoDebit: autoDebit ?? this.autoDebit,
    );
  }
}
