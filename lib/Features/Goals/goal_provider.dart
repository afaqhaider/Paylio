import 'dart:async';
import 'package:flutter/material.dart';
import '../../Core/database_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'goal_model.dart';
import 'goal_service.dart';

class GoalProvider extends ChangeNotifier {
  final GoalService _service = GoalService();
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<GoalModel> _goals = [];
  bool _isLoading = true;
  StreamSubscription? _subscription;

  List<GoalModel> get goals => _goals;
  bool get isLoading => _isLoading;

  GoalProvider() {
    _init();
  }

  Future<void> _init() async {
    // 1. Load from local database first
    try {
      final db = await _db.database;
      final result = await db.query('goals', orderBy: 'createdAt DESC');
      _goals = result.map((map) => GoalModel.fromMap(map)).toList();
      _isLoading = false;
      notifyListeners();
      debugPrint("Offline-First: Goals loaded from SQLite (${_goals.length})");
    } catch (e) {
      debugPrint("Offline-First Error: Failed to load goals from SQLite: $e");
    }

    // 2. Start cloud sync
    _subscription = _service.streamGoals().listen((cloudGoals) {
      _goals = cloudGoals;
      _isLoading = false;
      notifyListeners();
      debugPrint("CloudSync: Goals updated from Firestore (${cloudGoals.length})");
      
      // Background: Sync to Local
      _syncToLocal(cloudGoals);
    }, onError: (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint("CloudSync Error: Goals stream error: $e");
    });
  }

  Future<void> _syncToLocal(List<GoalModel> cloudGoals) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      for (var goal in cloudGoals) {
        await txn.insert('goals', goal.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> saveGoal(GoalModel goal) async {
    // 1. Save to local first
    try {
      final db = await _db.database;
      await db.insert('goals', goal.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint("Offline-First Error: Failed to save goal to local DB: $e");
    }
    
    // 2. Save to cloud
    await _service.saveGoal(goal);
  }

  Future<void> deleteGoal(String id) async {
    // Local delete
    try {
      final db = await _db.database;
      await db.delete('goals', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}

    await _service.deleteGoal(id);
  }

  double getTotalSaved() {
    return _goals.fold(0.0, (sum, goal) => sum + goal.savedAmount);
  }

  double getTotalTarget() {
    return _goals.fold(0.0, (sum, goal) => sum + goal.targetAmount);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
