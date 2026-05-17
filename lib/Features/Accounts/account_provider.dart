import 'dart:async';
import 'package:flutter/material.dart';
import '../../Core/database_helper.dart';
import '../Transactions/transaction_model.dart';
import 'account_model.dart';
import 'account_service.dart';

class AccountProvider extends ChangeNotifier {
  final AccountService _service = AccountService();
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<AccountModel> _accounts = [];
  bool _isLoading = true;
  StreamSubscription? _subscription;

  List<AccountModel> get accounts => _accounts;
  bool get isLoading => _isLoading;

  AccountProvider() {
    _init();
  }

  Future<void> _init() async {
    // 1. Load from local database first
    try {
      _accounts = await _db.getAccounts();
      _isLoading = false;
      notifyListeners();
      debugPrint("Offline-First: Accounts loaded from SQLite (${_accounts.length})");
    } catch (e) {
      debugPrint("Offline-First Error: Failed to load accounts from SQLite: $e");
    }

    // 2. Start cloud sync
    _subscription = _service.streamAccounts().listen((cloudAccounts) {
      _accounts = cloudAccounts;
      _isLoading = false;
      notifyListeners();
      debugPrint("CloudSync: Accounts updated from Firestore (${cloudAccounts.length})");
      _syncToLocal(cloudAccounts);
    }, onError: (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint("CloudSync Error: Accounts stream error: $e");
    });
  }

  Future<void> _syncToLocal(List<AccountModel> cloudAccounts) async {
    for (var acc in cloudAccounts) {
      await _db.insertAccount(acc);
    }
  }

  Future<void> saveAccount(AccountModel account) async {
    // 1. Save to local DB first
    try {
      await _db.insertAccount(account);
    } catch (e) {
      debugPrint("Offline-First Error: Failed to save account to local DB: $e");
    }

    // 2. Save to Firestore
    await _service.saveAccount(account);
  }

  Future<void> deleteAccount(String id) async {
    await _service.deleteAccount(id);
  }

  double calculateAccountBalance(AccountModel account, List<TransactionModel> transactions) {
    double balance = account.openingBalance;
    for (var tx in transactions) {
      if (tx.status != 'confirmed' && tx.status != 'approved') continue;

      if (tx.account == account.name) {
        // Types that INCREASE balance
        if (['income', 'borrow', 'repayment_received', 'loan_received'].contains(tx.type)) {
          balance += tx.amount;
        } 
        // Types that DECREASE balance
        else if (['expense', 'lend', 'repayment_paid', 'repayment_sent', 'loan_given', 'transfer', 'savings_transfer', 'liability_payment'].contains(tx.type)) {
          balance -= tx.amount;
        }
      }
      // Special case for transfer into this account
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
        // Credit card balance is usually a debt (negative in total net worth)
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
