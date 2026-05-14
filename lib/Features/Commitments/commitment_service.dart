import 'package:cloud_firestore/cloud_firestore.dart';
import '../../Core/cloud_service.dart';
import 'commitment_model.dart';

class CommitmentService extends CloudService {
  Stream<List<CommitmentModel>> streamCommitments() {
    return stream('commitments').map((snapshot) {
      return snapshot.docs.map((doc) {
        try {
          return CommitmentModel.fromFirestore(doc);
        } catch (e, st) {
          print('Bad commitment doc ${doc.id}: $e');
          print(st);
          return null;
        }
      }).whereType<CommitmentModel>().toList();
    });
  }

  Future<void> saveCommitment(CommitmentModel commitment) async {
    await save('commitments', commitment.id, commitment.toFirestore());
  }

  Future<void> deleteCommitment(String id) async {
    await delete('commitments', id);
  }
}
