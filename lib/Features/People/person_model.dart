class PersonModel {
  final int? id;
  final String? paylioId; // For future cross-user sync
  final String name;
  final String? email;
  final String? phone;
  final String? notes;

  PersonModel({
    this.id,
    this.paylioId,
    required this.name,
    this.email,
    this.phone,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'paylioId': paylioId,
      'name': name,
      'email': email,
      'phone': phone,
      'notes': notes,
    };
  }

  factory PersonModel.fromMap(Map<String, dynamic> map) {
    return PersonModel(
      id: map['id'],
      paylioId: map['paylioId'],
      name: map['name'],
      email: map['email'],
      phone: map['phone'],
      notes: map['notes'],
    );
  }
}
