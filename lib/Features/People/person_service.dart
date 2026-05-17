import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../Core/cloud_service.dart';
import '../Auth/user_model.dart';
import 'person_model.dart';
import 'connection_request_model.dart';
import 'user_connection_model.dart';

class PersonService extends CloudService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<PersonModel>> streamPeople() {
    return stream('people').map((snapshot) {
      return snapshot.docs.map((doc) {
        try {
          return PersonModel.fromFirestore(doc);
        } catch (e, st) {
          print('Bad person doc ${doc.id}: $e');
          print(st);
          return null;
        }
      }).whereType<PersonModel>().toList();
    });
  }

  Future<void> savePerson(PersonModel person) async {
    await save('people', person.id, person.toFirestore());
  }

  Future<void> deletePerson(String id) async {
    await delete('people', id);
  }

  // --- Connection System Methods ---

  Future<UserModel?> searchUserByEmail(String email) async {
    final snapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      return UserModel(
        ledgixId: snapshot.docs.first.id,
        name: data['fullName'] ?? '',
        email: data['email'] ?? '',
      );
    }
    return null;
  }

  Future<void> sendConnectionRequest(ConnectionRequestModel request) async {
    await _firestore.collection('connection_requests').add(request.toFirestore());
  }

  Stream<List<ConnectionRequestModel>> streamIncomingRequests(String userId) {
    return _firestore
        .collection('connection_requests')
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              try {
                return ConnectionRequestModel.fromFirestore(doc);
              } catch (e) {
                debugPrint('Bad connection request doc ${doc.id}: $e');
                return null;
              }
            }).whereType<ConnectionRequestModel>().toList());
  }

  Stream<List<ConnectionRequestModel>> streamSentRequests(String userId) {
    return _firestore
        .collection('connection_requests')
        .where('senderId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              try {
                return ConnectionRequestModel.fromFirestore(doc);
              } catch (e) {
                debugPrint('Bad sent request doc ${doc.id}: $e');
                return null;
              }
            }).whereType<ConnectionRequestModel>().toList());
  }

  Stream<List<UserConnectionModel>> streamConnections(String userId) {
    return _firestore
        .collection('user_connections')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              try {
                return UserConnectionModel.fromFirestore(doc);
              } catch (e) {
                debugPrint('Bad connection doc ${doc.id}: $e');
                return null;
              }
            }).whereType<UserConnectionModel>().toList());
  }

  Future<void> acceptConnectionRequest(ConnectionRequestModel request, String receiverName) async {
    final batch = _firestore.batch();

    // 1. Update request status
    final requestRef = _firestore.collection('connection_requests').doc(request.id);
    batch.update(requestRef, {'status': 'accepted'});

    // 2. Create connection for Sender
    final senderConnRef = _firestore.collection('user_connections').doc();
    batch.set(senderConnRef, {
      'userId': request.senderId,
      'connectedUserId': request.receiverId,
      'connectedUserName': receiverName,
      'connectedUserEmail': request.receiverEmail,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 3. Create connection for Receiver
    final receiverConnRef = _firestore.collection('user_connections').doc();
    batch.set(receiverConnRef, {
      'userId': request.receiverId,
      'connectedUserId': request.senderId,
      'connectedUserName': request.senderName,
      'connectedUserEmail': request.senderEmail,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> rejectConnectionRequest(String requestId) async {
    await _firestore.collection('connection_requests').doc(requestId).update({'status': 'rejected'});
  }

  Future<void> removeConnection(String connectionId, String userId, String connectedUserId) async {
    final batch = _firestore.batch();
    
    // Delete connection for both users
    final userConnSnapshot = await _firestore
        .collection('user_connections')
        .where('userId', isEqualTo: userId)
        .where('connectedUserId', isEqualTo: connectedUserId)
        .get();
        
    for (var doc in userConnSnapshot.docs) {
      batch.delete(doc.reference);
    }

    final friendConnSnapshot = await _firestore
        .collection('user_connections')
        .where('userId', isEqualTo: connectedUserId)
        .where('connectedUserId', isEqualTo: userId)
        .get();

    for (var doc in friendConnSnapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}
