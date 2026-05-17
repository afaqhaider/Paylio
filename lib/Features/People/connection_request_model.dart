import 'package:cloud_firestore/cloud_firestore.dart';

class ConnectionRequestModel {
  final String? id;
  final String senderId;
  final String receiverId;
  final String senderEmail;
  final String receiverEmail;
  final String senderName;
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime createdAt;

  ConnectionRequestModel({
    this.id,
    required this.senderId,
    required this.receiverId,
    required this.senderEmail,
    required this.receiverEmail,
    required this.senderName,
    this.status = 'pending',
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'senderEmail': senderEmail,
      'receiverEmail': receiverEmail,
      'senderName': senderName,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ConnectionRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ConnectionRequestModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      senderEmail: data['senderEmail'] ?? '',
      receiverEmail: data['receiverEmail'] ?? '',
      senderName: data['senderName'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
