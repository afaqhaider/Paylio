import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'commitment_model.dart';
import 'commitment_provider.dart';
import 'add_commitment_screen.dart';
import '../Transactions/transaction_provider.dart';
import '../../Core/settings_provider.dart';

class CommitmentsScreen extends StatelessWidget {
  const CommitmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final commitmentProvider = Provider.of<CommitmentProvider>(context);
    final txProvider = Provider.of<TransactionProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final currency = settings.currency;
    final format = NumberFormat('#,##0.00');

    final upcoming = commitmentProvider.getUpcomingCommitments();
    final overdue = commitmentProvider.getOverdueCommitments();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Fixed Commitments'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'Overdue'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildCommitmentList(context, upcoming, currency, format, commitmentProvider, txProvider),
            _buildCommitmentList(context, overdue, currency, format, commitmentProvider, txProvider, isOverdue: true),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddCommitmentScreen()),
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildCommitmentList(
    BuildContext context, 
    List<CommitmentModel> list, 
    String currency, 
    NumberFormat format,
    CommitmentProvider provider,
    TransactionProvider txProvider,
    {bool isOverdue = false}
  ) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          isOverdue ? 'No overdue commitments' : 'No upcoming commitments',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final commitment = list[index];
        final dueDate = commitment.nextDueDate ?? commitment.dueDate;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(commitment.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${commitment.type} • Due: ${DateFormat('dd MMM yyyy').format(dueDate)}'),
                Text('From: ${commitment.linkedAccount}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$currency ${format.format(commitment.amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    color: isOverdue ? Colors.red : const Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(height: 4),
                ElevatedButton(
                  onPressed: () => _confirmPayment(context, commitment, provider, txProvider),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    minimumSize: const Size(60, 30),
                    backgroundColor: const Color(0xFF0F766E),
                  ),
                  child: const Text('Pay', style: TextStyle(fontSize: 12, color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmPayment(BuildContext context, CommitmentModel commitment, CommitmentProvider provider, TransactionProvider txProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Paid?'),
        content: Text('This will create an expense transaction for ${commitment.name} and update the next due date.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await provider.markAsPaid(commitment, txProvider);
              if (context.mounted) Navigator.pop(context);
            }, 
            child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
