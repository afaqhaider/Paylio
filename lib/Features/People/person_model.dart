import 'package:cloud_firestore/cloud_firestore.dart';

class PersonModel {
  final String? id;
  final String? ledgixId; // For future cross-user sync
  final String name;
  final String? email;
  final String? phone;
  final String? notes;

  PersonModel({
    this.id,
    this.ledgixId,
    required this.name,
    this.email,
    this.phone,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ledgixId': ledgixId,
      'name': name,
      'email': email,
      'phone': phone,
      'notes': notes,
    };
  }

  factory PersonModel.fromMap(Map<String, dynamic> map) {
    return PersonModel(
      id: map['id']?.toString(),
      ledgixId: map['ledgixId'],
      name: map['name'],
      email: map['email'],
      phone: map['phone'],
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ledgixId': ledgixId,
      'name': name,
      'email': email,
      'phone': phone,
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory PersonModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PersonModel(
      id: doc.id,
      ledgixId: data['ledgixId']?.toString(),
      name: data['name']?.toString() ?? '',
      email: data['email']?.toString(),
      phone: data['phone']?.toString(),
      notes: data['notes']?.toString(),
    );
  }
}
