import 'dart:async';
import 'package:flutter/material.dart';
import '../../Core/database_helper.dart';
import 'transaction_model.dart';
import 'transaction_service.dart';

class TransactionProvider extends ChangeNotifier {
  final TransactionService _service = TransactionService();
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;
  StreamSubscription? _subscription;

  List<TransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;

  TransactionProvider() {
    _init();
  }

  Future<void> _init() async {
    // 1. Load from local database first
    try {
      _transactions = await _db.getTransactions();
      _isLoading = false;
      notifyListeners();
      debugPrint("Offline-First: Transactions loaded from SQLite (${_transactions.length})");
    } catch (e) {
      debugPrint("Offline-First Error: Failed to load from SQLite: $e");
    }

    // 2. Start cloud sync
    _subscription = _service.streamTransactions().listen((cloudTransactions) async {
      _transactions = cloudTransactions;
      _isLoading = false;
      notifyListeners();
      debugPrint("CloudSync: Transactions updated from Firestore (${cloudTransactions.length})");
      
      // Background: Sync Cloud to Local
      _syncToLocal(cloudTransactions);
    }, onError: (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint("CloudSync Error: Transactions stream error: $e");
    });
  }

  Future<void> _syncToLocal(List<TransactionModel> cloudTxs) async {
    for (var tx in cloudTxs) {
      await _db.insertTransaction(tx);
    }
  }

  Future<void> saveTransaction(TransactionModel transaction) async {
    // 1. Save to local DB first for immediate offline availability
    try {
      if (transaction.id == null) {
        await _db.insertTransaction(transaction);
        // We'll update the ID once cloud sync happens
      } else {
        await _db.updateTransaction(transaction);
      }
      // Update local state temporarily if needed, 
      // but Firestore stream will usually handle this.
    } catch (e) {
      debugPrint("Offline-First Error: Failed to save transaction to local DB: $e");
    }

    // 2. Save to Firestore
    await _service.saveTransaction(transaction);
  }

  Future<void> deleteTransaction(String id) async {
    await _service.deleteTransaction(id);
    // Local DB will be updated via stream
  }

  /// Correct Accounting Logic for Monthly Summary
  Map<String, double> getMonthlySummary() {
    final now = DateTime.now();
    double income = 0;
    double expense = 0;

    for (var tx in _transactions) {
      if (tx.status != 'confirmed' && tx.status != 'approved') continue;
      if (tx.date.month != now.month || tx.date.year != now.year) continue;

      final type = tx.type.toLowerCase();
      
      // Corrected Logic:
      // Only 'income' type counts as REAL income.
      // Borrowed money, repayments received, and transfers are NOT income.
      if (type == 'income') {
        income += tx.amount;
      } 
      // Only 'expense' type counts as REAL expense.
      // Lending money, loan repayments, and transfers are NOT expenses.
      else if (type == 'expense') {
        expense += tx.amount;
      }
    }
    return {'income': income, 'expense': expense};
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
