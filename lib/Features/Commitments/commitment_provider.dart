import 'dart:async';
import 'package:flutter/material.dart';
import 'commitment_model.dart';
import 'commitment_service.dart';
import '../Transactions/transaction_model.dart';
import '../Transactions/transaction_provider.dart';

class CommitmentProvider extends ChangeNotifier {
  final CommitmentService _service = CommitmentService();
  List<CommitmentModel> _commitments = [];
  bool _isLoading = true;
  StreamSubscription? _subscription;

  List<CommitmentModel> get commitments => _commitments;
  bool get isLoading => _isLoading;

  CommitmentProvider() {
    _init();
  }

  Future<void> _init() async {
    // For now, load from cloud, but we can add SQLite if table exists
    // DatabaseHelper has 'commitments' table? No, it only has transactions, accounts, categories, budgets, users, people.
    // I should add commitments to SQLite if needed, but the user said "do not block app launch".

    _subscription = _service.streamCommitments().listen((commitments) {
      _commitments = commitments;
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint("CommitmentProvider Error: $e");
    });
  }

  Future<void> saveCommitment(CommitmentModel commitment) async {
    await _service.saveCommitment(commitment);
  }

  Future<void> deleteCommitment(String id) async {
    await _service.deleteCommitment(id);
  }

  Future<void> markAsPaid(CommitmentModel commitment, TransactionProvider txProvider) async {
    // 1. Create transaction
    final tx = TransactionModel(
      type: 'expense',
      category: commitment.type,
      account: commitment.linkedAccount,
      note: 'Payment for: ${commitment.name}',
      amount: commitment.amount,
      date: DateTime.now(),
    );
    await txProvider.saveTransaction(tx);

    // 2. Update commitment next due date
    if (commitment.frequency == 'One-time') {
      final updatedCommitment = commitment.copyWith(status: 'Paid');
      await saveCommitment(updatedCommitment);
    } else {
      DateTime nextDate = _calculateNextDueDate(commitment.nextDueDate ?? commitment.dueDate, commitment.frequency);
      final updatedCommitment = commitment.copyWith(
        status: 'Upcoming',
        nextDueDate: nextDate,
      );
      await saveCommitment(updatedCommitment);
    }
  }

  DateTime _calculateNextDueDate(DateTime current, String frequency) {
    switch (frequency) {
      case 'Weekly':
        return current.add(const Duration(days: 7));
      case 'Monthly':
        return DateTime(current.year, current.month + 1, current.day);
      case 'Quarterly':
        return DateTime(current.year, current.month + 3, current.day);
      case 'Yearly':
        return DateTime(current.year + 1, current.month, current.day);
      case 'One-time':
      default:
        return current;
    }
  }

  List<CommitmentModel> getUpcomingCommitments() {
    final now = DateTime.now();
    return _commitments.where((c) {
      final date = c.nextDueDate ?? c.dueDate;
      return date.isAfter(now) || (date.year == now.year && date.month == now.month && date.day == now.day);
    }).toList()..sort((a, b) => (a.nextDueDate ?? a.dueDate).compareTo(b.nextDueDate ?? b.dueDate));
  }

  List<CommitmentModel> getOverdueCommitments() {
    final now = DateTime.now();
    return _commitments.where((c) {
      final date = c.nextDueDate ?? c.dueDate;
      return date.isBefore(DateTime(now.year, now.month, now.day));
    }).toList();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
