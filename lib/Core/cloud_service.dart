import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class CloudService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference _userDoc() {
    if (_uid.isEmpty) throw Exception("User not authenticated");
    return _firestore.collection('users').doc(_uid).collection('data');
  }

  // Generic collection reference for a specific sub-collection
  CollectionReference collection(String path) {
    if (_uid.isEmpty) throw Exception("User not authenticated");
    return _firestore.collection('users').doc(_uid).collection(path);
  }

  Future<void> save(String path, String? id, Map<String, dynamic> data) async {
    try {
      if (id == null || id.isEmpty) {
        await collection(path).add(data);
        debugPrint("CloudSync: Added new document to $path");
      } else {
        await collection(path).doc(id).set(data, SetOptions(merge: true));
        debugPrint("CloudSync: Updated document $id in $path");
      }
    } catch (e) {
      debugPrint("CloudSync Error: Failed to save to $path: $e");
      rethrow;
    }
  }

  Future<void> delete(String path, String id) async {
    try {
      await collection(path).doc(id).delete();
      debugPrint("CloudSync: Deleted document $id from $path");
    } catch (e) {
      debugPrint("CloudSync Error: Failed to delete from $path: $e");
      rethrow;
    }
  }

  Stream<QuerySnapshot> stream(String path) {
    return collection(path).snapshots();
  }
}
