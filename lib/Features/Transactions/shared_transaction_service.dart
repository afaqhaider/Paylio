import 'package:cloud_firestore/cloud_firestore.dart';
import '../../Core/cloud_service.dart';
import 'shared_transaction_model.dart';

class SharedTransactionService extends CloudService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createSharedTransaction(SharedTransactionModel transaction) async {
    await _firestore.collection('shared_transactions').add(transaction.toFirestore());
  }

  Stream<List<SharedTransactionModel>> streamPendingApprovals(String userId) {
    return _firestore
        .collection('shared_transactions')
        .where('targetUserId', isEqualTo: userId)
        .where('status', whereIn: ['pending_approval', 'returned_with_changes'])
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SharedTransactionModel.fromFirestore(doc))
            .toList());
  }

  Future<void> updateSharedTransaction(SharedTransactionModel transaction) async {
    if (transaction.id == null) return;
    await _firestore.collection('shared_transactions').doc(transaction.id).update(transaction.toFirestore());
  }

  Stream<List<SharedTransactionModel>> streamMySharedTransactions(String userId) {
    return _firestore
        .collection('shared_transactions')
        .where('creatorUserId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SharedTransactionModel.fromFirestore(doc))
            .toList());
  }

  Future<void> updateSharedTransactionStatus(String id, String status, {double? finalAmount}) async {
    final updates = {
      'status': status,
      'approvedAt': status == 'approved' ? FieldValue.serverTimestamp() : null,
      'rejectedAt': status == 'rejected' ? FieldValue.serverTimestamp() : null,
    };
    if (finalAmount != null) {
      updates['finalApprovedAmount'] = finalAmount;
    }
    await _firestore.collection('shared_transactions').doc(id).update(updates);
  }

  Future<void> deleteSharedTransaction(String id) async {
    await _firestore.collection('shared_transactions').doc(id).delete();
  }
}
