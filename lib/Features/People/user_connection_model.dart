import 'package:cloud_firestore/cloud_firestore.dart';

class UserConnectionModel {
  final String? id;
  final String userId;
  final String connectedUserId;
  final String connectedUserName;
  final String connectedUserEmail;
  final DateTime createdAt;

  UserConnectionModel({
    this.id,
    required this.userId,
    required this.connectedUserId,
    required this.connectedUserName,
    required this.connectedUserEmail,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'connectedUserId': connectedUserId,
      'connectedUserName': connectedUserName,
      'connectedUserEmail': connectedUserEmail,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserConnectionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserConnectionModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      connectedUserId: data['connectedUserId'] ?? '',
      connectedUserName: data['connectedUserName'] ?? '',
      connectedUserEmail: data['connectedUserEmail'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
