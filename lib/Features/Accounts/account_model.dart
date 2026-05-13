class AccountModel {
  final int? id;
  final String name;
  final String type;
  final double openingBalance;
  final double? creditLimit;

  AccountModel({
    this.id,
    required this.name,
    required this.type,
    required this.openingBalance,
    this.creditLimit,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'openingBalance': openingBalance,
      'creditLimit': creditLimit,
    };
  }

  factory AccountModel.fromMap(Map<String, dynamic> map) {
    return AccountModel(
      id: map['id'] as int?,
      name: map['name'] as String? ?? 'Unnamed Account',
      type: map['type'] as String? ?? 'General',
      openingBalance: (map['openingBalance'] as num?)?.toDouble() ?? 0.0,
      creditLimit: (map['creditLimit'] as num?)?.toDouble(),
    );
  }
}