import 'dart:async';
import 'package:flutter/material.dart';
import '../../Core/database_helper.dart';
import 'budget_model.dart';
import 'budget_service.dart';

class BudgetProvider extends ChangeNotifier {
  final BudgetService _service = BudgetService();
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<BudgetModel> _budgets = [];
  bool _isLoading = true;
  StreamSubscription? _subscription;

  List<BudgetModel> get budgets => _budgets;
  bool get isLoading => _isLoading;

  BudgetProvider() {
    _init();
  }

  Future<void> _init() async {
    // 1. Load from local database first
    try {
      _budgets = await _db.getBudgets();
      _isLoading = false;
      notifyListeners();
      debugPrint("Offline-First: Budgets loaded from SQLite (${_budgets.length})");
    } catch (e) {
      debugPrint("Offline-First Error: Failed to load budgets from SQLite: $e");
    }

    // 2. Start cloud sync
    _subscription = _service.streamBudgets().listen((cloudBudgets) {
      _budgets = cloudBudgets;
      _isLoading = false;
      notifyListeners();
      debugPrint("CloudSync: Budgets updated from Firestore (${cloudBudgets.length})");
      _syncToLocal(cloudBudgets);
    }, onError: (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint("CloudSync Error: Budgets stream error: $e");
    });
  }

  Future<void> _syncToLocal(List<BudgetModel> cloudBudgets) async {
    for (var budget in cloudBudgets) {
      await _db.insertBudget(budget);
    }
  }

  Future<void> saveBudget(BudgetModel budget) async {
    // 1. Save to local DB first
    try {
      await _db.insertBudget(budget);
    } catch (e) {
      debugPrint("Offline-First Error: Failed to save budget to local DB: $e");
    }

    // 2. Save to Firestore
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
