import 'dart:async';
import 'package:flutter/material.dart';
import 'budget_model.dart';
import 'budget_service.dart';

class BudgetProvider extends ChangeNotifier {
  final BudgetService _service = BudgetService();
  List<BudgetModel> _budgets = [];
  bool _isLoading = true;
  StreamSubscription? _subscription;

  List<BudgetModel> get budgets => _budgets;
  bool get isLoading => _isLoading;

  BudgetProvider() {
    _init();
  }

  void _init() {
    _subscription = _service.streamBudgets().listen((budgets) {
      _budgets = budgets;
      _isLoading = false;
      notifyListeners();
      debugPrint("CloudSync: Budgets updated (${budgets.length})");
    }, onError: (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint("CloudSync Error: Budgets stream error: $e");
    });
  }

  Future<void> saveBudget(BudgetModel budget) async {
    await _service.saveBudget(budget);
  }

  Future<void> deleteBudget(String id) async {
    await _service.deleteBudget(id);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
