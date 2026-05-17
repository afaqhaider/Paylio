import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../Core/settings_provider.dart';
import 'shared_transaction_provider.dart';
import 'transaction_provider.dart';
import 'edit_shared_transaction_screen.dart';
import '../Accounts/account_provider.dart';

class ApprovalsScreen extends StatelessWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sharedProvider = Provider.of<SharedTransactionProvider>(context);
    final txProvider = Provider.of<TransactionProvider>(context);
    final currency = Provider.of<SettingsProvider>(context).currency;
    final format = NumberFormat('#,##0.00');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Approvals'),
      ),
      body: sharedProvider.pendingApprovals.isEmpty
          ? const Center(child: Text('No pending approvals', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sharedProvider.pendingApprovals.length,
              itemBuilder: (context, index) {
                final tx = sharedProvider.pendingApprovals[index];
                final isCreator = tx.creatorUserId == sharedProvider.currentUserId;
                final isLend = tx.type == 'lend' || tx.type == 'loan_given'; 

                String displayTitle;
                if (tx.type == 'repayment_sent' || tx.type == 'repayment_paid') {
                  displayTitle = 'Repayment Received';
                } else if (tx.type == 'repayment_received') {
                  displayTitle = 'Repayment Sent';
                } else {
                  displayTitle = isLend ? 'Loan Received' : 'Loan Given';
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (tx.status == 'returned_with_changes')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                            child: const Text('Edited - Waiting for your confirmation', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              displayTitle,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: (tx.type.contains('repayment')) ? Colors.teal : (isLend ? Colors.brown : Colors.orange),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${tx.receiverCurrency} ${format.format(tx.convertedAmount)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                if (tx.originalCurrency != tx.receiverCurrency)
                                  Text(
                                    '(${tx.originalCurrency} ${format.format(tx.originalAmount)})',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(tx.description, style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                          'From: ${tx.creatorDisplayName}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        if (tx.status == 'pending_approval' && !isCreator)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => sharedProvider.rejectTransaction(tx.id!),
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                  child: const Text('Reject'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => EditSharedTransactionScreen(transaction: tx)));
                                  },
                                  child: const Text('Edit'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final account = await _selectReceivingAccount(context);
                                    if (account == null || account.isEmpty) return;
                                    await sharedProvider.approveTransaction(tx, txProvider, approvedAccount: account);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Transaction approved!')),
                                      );
                                    }
                                  },
                                  child: const Text('Approve'),
                                ),
                              ),
                            ],
                          )
                        else if (tx.status == 'returned_with_changes' && isCreator)
                           Row(
                            children: [
                               Expanded(
                                child: OutlinedButton(
                                  onPressed: () => sharedProvider.rejectTransaction(tx.id!),
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                  child: const Text('Reject Changes'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    await sharedProvider.acceptReturnedTransaction(tx);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Changes Accepted!')),
                                      );
                                    }
                                  },
                                  child: const Text('Accept Changes'),
                                ),
                              ),
                            ],
                           )
                        else
                          const Text('Waiting for other party...', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                );
              },
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
                "Choose your own account for this approval. The other user's bank is only their payment channel.",
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selected,
                decoration: const InputDecoration(labelText: 'My account'),
                items: accounts.map((a) => DropdownMenuItem(value: a.name, child: Text(a.name))).toList(),
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

}
