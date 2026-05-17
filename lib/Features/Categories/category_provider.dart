import 'dart:async';
import 'package:flutter/material.dart';
import '../../Core/database_helper.dart';
import 'category_model.dart';
import 'category_service.dart';

class CategoryProvider extends ChangeNotifier {
  final CategoryService _service = CategoryService();
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<CategoryModel> _incomeCategories = [];
  List<CategoryModel> _expenseCategories = [];
  StreamSubscription? _incomeSub;
  StreamSubscription? _expenseSub;

  static const List<Color> categoryPalette = [
    Color(0xFF0F766E), // Original Teal
    Color(0xFFEF4444), // Red
    Color(0xFFF59E0B), // Amber
    Color(0xFF3B82F6), // Blue
    Color(0xFF8B5CF6), // Purple
    Color(0xFF10B981), // Green
    Color(0xFFEC4899), // Pink
    Color(0xFF6366F1), // Indigo
    Color(0xFFF97316), // Orange
    Color(0xFF218BFF), // Blue
    Color(0xFF84CC16), // Lime
    Color(0xFF06B6D4), // Cyan
  ];

  Color getColorForCategory(String name, String? hexColor) {
    if (hexColor != null && hexColor.isNotEmpty) {
      try {
        if (hexColor.startsWith('0xFF')) {
          return Color(int.parse(hexColor));
        }
        return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }

    final n = name.toLowerCase();
    if (n.contains('food') || n.contains('drink') || n.contains('restau')) return Colors.orange;
    if (n.contains('fuel') || n.contains('car') || n.contains('transport')) return Colors.red;
    if (n.contains('medi') || n.contains('health') || n.contains('doctor')) return Colors.pink;
    if (n.contains('shop') || n.contains('buy')) return Colors.purple;
    if (n.contains('bill') || n.contains('utilit') || n.contains('rent')) return Colors.amber;
    if (n.contains('travel') || n.contains('flight') || n.contains('hotel')) return Colors.blueGrey;
    
    if (n.contains('salary') || n.contains('wage')) return Colors.green;
    if (n.contains('bonus') || n.contains('gift')) return Colors.teal;
    if (n.contains('invest') || n.contains('stock')) return Colors.blue;
    if (n.contains('refund')) return Colors.cyan;

    final int hash = n.hashCode.abs();
    return categoryPalette[hash % categoryPalette.length];
  }

  List<CategoryModel> get incomeCategories => _incomeCategories;
  List<CategoryModel> get expenseCategories => _expenseCategories;

  CategoryProvider() {
    _init();
  }

  Future<void> _init() async {
    // 1. Load from local database first
    try {
      final allCats = await _db.getCategories();
      _incomeCategories = allCats.where((c) => c.type == 'income').toList();
      _expenseCategories = allCats.where((c) => c.type == 'expense').toList();
      notifyListeners();
      debugPrint("Offline-First: Categories loaded from SQLite (${allCats.length})");
    } catch (e) {
      debugPrint("Offline-First Error: Failed to load categories from SQLite: $e");
    }

    // 2. Start cloud sync
    _incomeSub = _service.streamCategories('income').listen((cats) {
      _incomeCategories = cats;
      notifyListeners();
    }, onError: (e) {
      debugPrint("CategoryProvider (Income) Error: $e");
    });
    _expenseSub = _service.streamCategories('expense').listen((cats) {
      _expenseCategories = cats;
      notifyListeners();
    }, onError: (e) {
      debugPrint("CategoryProvider (Expense) Error: $e");
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
