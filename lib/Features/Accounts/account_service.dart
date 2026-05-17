import '../../Core/cloud_service.dart';
import 'account_model.dart';

class AccountService extends CloudService {
  Stream<List<AccountModel>> streamAccounts() {
    return stream('accounts').map((snapshot) {
      return snapshot.docs.map((doc) {
        try {
          return AccountModel.fromFirestore(doc);
        } catch (e, st) {
          print('Bad account doc ${doc.id}: $e');
          print(st);
          return null;
        }
      }).whereType<AccountModel>().toList();
    });
  }

  Future<void> saveAccount(AccountModel account) async {
    await save('accounts', account.id, account.toFirestore());
  }

  Future<void> deleteAccount(String id) async {
    await delete('accounts', id);
  }
}
