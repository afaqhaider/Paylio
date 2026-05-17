import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'shared_transaction_model.dart';
import 'shared_transaction_service.dart';
import 'transaction_model.dart';
import 'transaction_provider.dart';

class SharedTransactionProvider extends ChangeNotifier {
  final SharedTransactionService _service = SharedTransactionService();
  List<SharedTransactionModel> _pendingApprovals = [];
  List<SharedTransactionModel> _mySharedTransactions = [];
  
  StreamSubscription? _pendingSub;
  StreamSubscription? _mySub;
  
  List<SharedTransactionModel> get pendingApprovals => _pendingApprovals;
  List<SharedTransactionModel> get mySharedTransactions => _mySharedTransactions;
  String? get currentUserId => _currentUserId;

  String? _currentUserId;

  void updateUserId(String? userId) {
    if (_currentUserId == userId) return;
    _currentUserId = userId;
    _cancelSubs();
    if (userId != null) {
      _init(userId);
    }
  }

  void _init(String userId) {
    _pendingSub = _service.streamPendingApprovals(userId).listen((txs) {
      _pendingApprovals = txs;
      notifyListeners();
    });

    _mySub = _service.streamMySharedTransactions(userId).listen((txs) {
      _mySharedTransactions = txs;
      _syncLocalTransactions(txs);
      notifyListeners();
    });
  }

  void _syncLocalTransactions(List<SharedTransactionModel> txs) async {
    for (var tx in txs) {
      if (tx.status == 'approved' && tx.originalTransactionId != null) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUserId)
              .collection('transactions')
              .doc(tx.originalTransactionId)
              .get();
          
          if (doc.exists && (doc.data()?['status'] == 'pending' || doc.data()?['status'] == 'pending_approval')) {
            // Using FINAL approved amount (tx.originalAmount at approval time)
            await FirebaseFirestore.instance
                .collection('users')
                .doc(_currentUserId)
                .collection('transactions')
                .doc(tx.originalTransactionId)
                .update({
                  'status': 'approved',
                  'amount': tx.originalAmount, 
                  'note': tx.description,
                  'approvedAt': FieldValue.serverTimestamp(),
                  'proposedAmount': tx.proposedAmount,
                });
            debugPrint("Auto-confirmed local transaction: ${tx.originalTransactionId} with amount ${tx.originalAmount}");
          }
        } catch (e) {
          debugPrint("Sync Error: $e");
        }
      } else if (tx.status == 'rejected' && tx.originalTransactionId != null) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUserId)
              .collection('transactions')
              .doc(tx.originalTransactionId)
              .get();
          
          if (doc.exists && (doc.data()?['status'] == 'pending' || doc.data()?['status'] == 'pending_approval')) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(_currentUserId)
                .collection('transactions')
                .doc(tx.originalTransactionId)
                .update({'status': 'rejected'});
            debugPrint("Marked local transaction as rejected: ${tx.originalTransactionId}");
          }
        } catch (e) {
          debugPrint("Sync Error: $e");
        }
      }
    }
  }

  void _cancelSubs() {
    _pendingSub?.cancel();
    _mySub?.cancel();
  }

  List<SharedTransactionModel> get sentAwaitingApproval => _mySharedTransactions.where((tx) => tx.status == 'pending_approval').toList();
  List<SharedTransactionModel> get receivedAwaitingAction => _pendingApprovals.where((tx) => tx.status == 'pending_approval').toList();
  List<SharedTransactionModel> get returnedToMe => _mySharedTransactions.where((tx) => tx.status == 'returned_with_changes').toList();
  List<SharedTransactionModel> get rejectedTransactions {
    final mine = _mySharedTransactions.where((tx) => tx.status == 'rejected').toList();
    final theirs = _pendingApprovals.where((tx) => tx.status == 'rejected').toList();
    return [...mine, ...theirs]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  int get myActionCount => receivedAwaitingAction.length + returnedToMe.length;

  Future<void> createSharedTransaction(SharedTransactionModel tx) async {
    await _service.createSharedTransaction(tx.copyWith(status: 'pending_approval'));
    _notifyUser(tx.targetUserId, 'New Approval Request', '${tx.creatorDisplayName} sent a ${tx.type} request for ${tx.receiverCurrency} ${tx.convertedAmount.toStringAsFixed(2)}');
  }

  Future<void> approveTransaction(SharedTransactionModel tx, TransactionProvider localTxProvider, {String? approvedAccount}) async {
    // 1. Update shared transaction status with FINAL amount
    await _service.updateSharedTransactionStatus(tx.id!, 'approved', finalAmount: tx.originalAmount);

    // 2. Create local transaction for the target user (the one who is approving)
    // ... logic remains same but using tx.convertedAmount (which is the corrected one if edits occurred)
    String localType;
    if (tx.type == 'lend') {
      localType = 'borrow';
    } else if (tx.type == 'borrow') {
      localType = 'lend';
    } else if (tx.type == 'repayment_sent') {
      localType = 'repayment_received';
    } else if (tx.type == 'repayment_received') {
      localType = 'repayment_paid';
    } else {
      localType = tx.type;
    }
    
    final receiverAccount = approvedAccount?.trim().isNotEmpty == true
        ? approvedAccount!.trim()
        : 'Shared with ${tx.creatorDisplayName}';

    final localTx = TransactionModel(
      type: localType,
      category: tx.category,
      account: receiverAccount,
      note: tx.description,
      amount: tx.convertedAmount, // This is the corrected amount for the receiver
      date: DateTime.now(),
      personId: tx.creatorUserId, 
      status: 'approved',
      proposedAmount: tx.proposedAmount * tx.exchangeRate, // Approximately if currencies differ
      approvedAt: DateTime.now(),
    );
    
    await localTxProvider.saveTransaction(localTx);

    _notifyUser(tx.creatorUserId, 'Transaction Approved', '${tx.targetDisplayName} approved your ${tx.type} request.');
  }

  Future<void> editAndApprove(SharedTransactionModel tx, double newConvertedAmount, double newRate, String newNote) async {
    final newOriginalAmount = newConvertedAmount / newRate;
    await returnWithChanges(tx, newOriginalAmount, newConvertedAmount, newNote);
  }

  Future<void> returnWithChanges(SharedTransactionModel tx, double newOriginalAmount, double newConvertedAmount, String newNote) async {
    final updatedTx = tx.copyWith(
      originalAmount: newOriginalAmount,
      convertedAmount: newConvertedAmount,
      description: newNote,
      status: 'returned_with_changes',
      editedByReceiver: true,
    );
    await _service.updateSharedTransaction(updatedTx);
    _notifyUser(tx.creatorUserId, 'Transaction Returned', '${tx.targetDisplayName} suggested changes to your ${tx.type} request.');
  }

  Future<void> acceptReturnedTransaction(SharedTransactionModel tx) async {
    await _service.updateSharedTransactionStatus(tx.id!, 'approved', finalAmount: tx.originalAmount);
    _notifyUser(tx.targetUserId, 'Changes Accepted', '${tx.creatorDisplayName} accepted suggested changes for ${tx.type}.');
  }

  Future<void> rejectTransaction(String id) async {
    final tx = [..._pendingApprovals, ..._mySharedTransactions].firstWhere((t) => t.id == id);
    await _service.updateSharedTransactionStatus(id, 'rejected');
    
    String notifyTo = (_currentUserId == tx.creatorUserId) ? tx.targetUserId : tx.creatorUserId;
    String fromName = (_currentUserId == tx.creatorUserId) ? tx.creatorDisplayName : tx.targetDisplayName;
    
    _notifyUser(notifyTo, 'Transaction Rejected', '$fromName rejected the ${tx.type} request.');
  }

  Future<void> _notifyUser(String userId, String title, String body) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'recipientId': userId,
        'title': title,
        'body': body,
        'senderId': _currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending', // A Cloud Function can pick this up and send FCM
      });
    } catch (e) {
      debugPrint("Notification Error: $e");
    }
  }

  @override
  void dispose() {
    _cancelSubs();
    super.dispose();
  }
}
