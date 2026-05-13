import 'dart:async';
import 'package:flutter/material.dart';
import 'category_model.dart';
import 'category_service.dart';

class CategoryProvider extends ChangeNotifier {
  final CategoryService _service = CategoryService();
  List<CategoryModel> _incomeCategories = [];
  List<CategoryModel> _expenseCategories = [];
  StreamSubscription? _incomeSub;
  StreamSubscription? _expenseSub;

  List<CategoryModel> get incomeCategories => _incomeCategories;
  List<CategoryModel> get expenseCategories => _expenseCategories;

  CategoryProvider() {
    _init();
  }

  void _init() {
    _incomeSub = _service.streamCategories('income').listen((cats) {
      _incomeCategories = cats;
      notifyListeners();
    });
    _expenseSub = _service.streamCategories('expense').listen((cats) {
      _expenseCategories = cats;
      notifyListeners();
    });
  }

  Future<void> saveCategory(CategoryModel category) async {
    await _service.saveCategory(category);
  }

  Future<void> deleteCategory(String id) async {
    await _service.deleteCategory(id);
  }

  @override
  void dispose() {
    _incomeSub?.cancel();
    _expenseSub?.cancel();
    super.dispose();
  }
}
