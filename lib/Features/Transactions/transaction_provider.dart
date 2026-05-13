import 'dart:async';
import 'package:flutter/material.dart';
import 'transaction_model.dart';
import 'transaction_service.dart';

class TransactionProvider extends ChangeNotifier {
  final TransactionService _service = TransactionService();
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;
  StreamSubscription? _subscription;

  List<TransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;

  TransactionProvider() {
    _init();
  }

  void _init() {
    _subscription = _service.streamTransactions().listen((transactions) {
      _transactions = transactions;
      _isLoading = false;
      notifyListeners();
      debugPrint("CloudSync: Transactions updated (${transactions.length})");
    }, onError: (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint("CloudSync Error: Transactions stream error: $e");
    });
  }

  Future<void> saveTransaction(TransactionModel transaction) async {
    await _service.saveTransaction(transaction);
  }

  Future<void> deleteTransaction(String id) async {
    await _service.deleteTransaction(id);
  }

  Map<String, double> getMonthlySummary() {
    final now = DateTime.now();
    double income = 0;
    double expense = 0;

    for (var tx in _transactions) {
      if (tx.date.month == now.month && tx.date.year == now.year) {
        final type = tx.type.toLowerCase();
        if (type == 'income' || type == 'repayment_received' || type == 'borrow') {
          income += tx.amount;
        } else if (type == 'expense' || type == 'repayment_paid' || type == 'lend') {
          expense += tx.amount;
        }
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
