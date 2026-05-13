import 'package:cloud_firestore/cloud_firestore.dart';
import '../../Core/cloud_service.dart';
import 'account_model.dart';

class AccountService extends CloudService {
  Stream<List<AccountModel>> streamAccounts() {
    return stream('accounts').map((snapshot) {
      return snapshot.docs.map((doc) => AccountModel.fromFirestore(doc)).toList();
    });
  }

  Future<void> saveAccount(AccountModel account) async {
    await save('accounts', account.id, account.toFirestore());
  }

  Future<void> deleteAccount(String id) async {
    await delete('accounts', id);
  }
}
