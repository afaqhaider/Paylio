import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'shared_transaction_provider.dart';
import 'shared_transaction_model.dart';
import 'transaction_provider.dart';
import '../../Core/settings_provider.dart';
import '../Accounts/account_provider.dart';

class PendingApprovalsScreen extends StatelessWidget {
  const PendingApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sharedProvider = Provider.of<SharedTransactionProvider>(context);
    
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pending Approvals'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'To Action'),
              Tab(text: 'Sent'),
              Tab(text: 'Returned'),
              Tab(text: 'Rejected'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _TransactionList(transactions: sharedProvider.receivedAwaitingAction, showActions: true),
            _TransactionList(transactions: sharedProvider.sentAwaitingApproval, showActions: false),
            _TransactionList(transactions: sharedProvider.returnedToMe, showActions: true, isReturned: true),
            _TransactionList(transactions: sharedProvider.rejectedTransactions, showActions: false),
          ],
        ),
      ),
    );
  }
}

class _TransactionList extends StatelessWidget {
  final List<SharedTransactionModel> transactions;
  final bool showActions;
  final bool isReturned;

  const _TransactionList({
    required this.transactions,
    required this.showActions,
    this.isReturned = false,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Center(child: Text('No transactions found', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final tx = transactions[index];
        return _TransactionCard(tx: tx, showActions: showActions, isReturned: isReturned);
      },
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final SharedTransactionModel tx;
  final bool showActions;
  final bool isReturned;

  const _TransactionCard({
    required this.tx,
    required this.showActions,
    required this.isReturned,
  });

  @override
  Widget build(BuildContext context) {
    final sharedProvider = Provider.of<SharedTransactionProvider>(context, listen: false);
    final localTxProvider = Provider.of<TransactionProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context);
    
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(tx.createdAt);
    final amountStr = '${tx.receiverCurrency} ${tx.convertedAmount.toStringAsFixed(2)}';
    final originalAmountStr = '${tx.originalCurrency} ${tx.originalAmount.toStringAsFixed(2)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tx.type.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: tx.status == 'rejected' ? Colors.red : Colors.blue,
                    fontSize: 12,
                  ),
                ),
                Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tx.description,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  showActions ? 'From: ${tx.creatorDisplayName}' : 'To: ${tx.targetDisplayName}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Amount', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    Text(amountStr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    if (tx.receiverCurrency != tx.originalCurrency)
                      Text('($originalAmountStr)', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                if (showActions)
                  Row(
                    children: [
                      if (!isReturned)
                        IconButton(
                          icon: const Icon(Icons.edit_note, color: Colors.orange),
                          onPressed: () => _showReturnDialog(context, sharedProvider, tx),
                          tooltip: 'Return with changes',
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => sharedProvider.rejectTransaction(tx.id!),
                        tooltip: 'Reject',
                      ),
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () async {
                          if (isReturned) {
                            await sharedProvider.acceptReturnedTransaction(tx);
                          } else {
                            final account = await _selectReceivingAccount(context);
                            if (account == null || account.isEmpty) return;
                            await sharedProvider.approveTransaction(
                              tx,
                              localTxProvider,
                              approvedAccount: account,
                            );
                          }
                        },
                        tooltip: isReturned ? 'Accept' : 'Approve',
                      ),
                    ],
                  )
                else
                  _buildStatusChip(tx.status),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Future<String?> _selectReceivingAccount(BuildContext context) async {
    final accounts = Provider.of<AccountProvider>(context, listen: false).accounts;
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create an account first, then approve the transaction.')),
      );
      return null;
    }

    String selected = accounts.first.name;
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Select your account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Choose the account where this money was paid from or received into. The other user's bank does not affect your books.",
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selected,
                decoration: const InputDecoration(labelText: 'My account'),
                items: accounts
                    .map((a) => DropdownMenuItem(value: a.name, child: Text(a.name)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => selected = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, selected), child: const Text('Approve')),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'approved': color = Colors.green; break;
      case 'rejected': color = Colors.red; break;
      case 'returned_with_changes': color = Colors.orange; break;
      default: color = Colors.blue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(status.replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _showReturnDialog(BuildContext context, SharedTransactionProvider provider, SharedTransactionModel tx) {
    final amountController = TextEditingController(text: tx.originalAmount.toString());
    final noteController = TextEditingController(text: tx.description);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Return with Changes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'New Amount'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'Comment / Reason'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newAmount = double.tryParse(amountController.text) ?? tx.originalAmount;
              // For simplicity, keep converted amount same or recalculate if needed
              // Here we'll just update original and converted to new value if same currency
              provider.returnWithChanges(tx, newAmount, newAmount, noteController.text);
              Navigator.pop(context);
            },
            child: const Text('Return'),
          ),
        ],
      ),
    );
  }
}
