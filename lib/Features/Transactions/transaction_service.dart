import 'package:cloud_firestore/cloud_firestore.dart';
import '../../Core/cloud_service.dart';
import 'transaction_model.dart';

class TransactionService extends CloudService {
  Stream<List<TransactionModel>> streamTransactions({int? limit}) {
    Query query = collection('transactions').orderBy('date', descending: true);
    if (limit != null) {
      query = query.limit(limit);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => TransactionModel.fromFirestore(doc)).toList();
    });
  }

  Future<void> saveTransaction(TransactionModel transaction) async {
    await save('transactions', transaction.id, transaction.toFirestore());
  }

  Future<void> deleteTransaction(String id) async {
    await delete('transactions', id);
  }
}
