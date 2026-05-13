import 'dart:async';
import 'package:flutter/material.dart';
import '../Transactions/transaction_model.dart';
import 'account_model.dart';
import 'account_service.dart';

class AccountProvider extends ChangeNotifier {
  final AccountService _service = AccountService();
  List<AccountModel> _accounts = [];
  bool _isLoading = true;
  StreamSubscription? _subscription;

  List<AccountModel> get accounts => _accounts;
  bool get isLoading => _isLoading;

  AccountProvider() {
    _init();
  }

  void _init() {
    _subscription = _service.streamAccounts().listen((accounts) {
      _accounts = accounts;
      _isLoading = false;
      notifyListeners();
      debugPrint("CloudSync: Accounts updated (${accounts.length})");
    }, onError: (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint("CloudSync Error: Accounts stream error: $e");
    });
  }

  Future<void> saveAccount(AccountModel account) async {
    await _service.saveAccount(account);
  }

  Future<void> deleteAccount(String id) async {
    await _service.deleteAccount(id);
  }

  double calculateAccountBalance(AccountModel account, List<TransactionModel> transactions) {
    double balance = account.openingBalance;
    for (var tx in transactions) {
      if (tx.account == account.name) {
        if (['income', 'borrow', 'repayment_received'].contains(tx.type)) {
          balance += tx.amount;
        } else if (['expense', 'lend', 'repayment_paid', 'transfer'].contains(tx.type)) {
          balance -= tx.amount;
        }
      }
      if (tx.type == 'transfer' && tx.toAccount == account.name) {
        balance += tx.amount;
      }
    }
    return balance;
  }

  double getTotalBalance(List<TransactionModel> transactions) {
    double total = 0;
    for (var acc in _accounts) {
      double bal = calculateAccountBalance(acc, transactions);
      if (acc.type == 'Credit Card') {
        // Assuming credit card balance is debt
        total -= bal;
      } else {
        total += bal;
      }
    }
    return total;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
