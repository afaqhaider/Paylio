import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../Core/settings_provider.dart';
import '../Transactions/transaction_model.dart';
import '../Transactions/transaction_provider.dart';
import '../Transactions/add_expense_screen.dart';
import 'person_model.dart';

class PersonDetailScreen extends StatelessWidget {
  final PersonModel person;

  const PersonDetailScreen({super.key, required this.person});

  Map<String, double> _calculateSummary(PersonModel person, List<TransactionModel> transactions) {
    double lent = 0;
    double borrowed = 0;
    double repaidReceived = 0;
    double repaidPaid = 0;

    for (var tx in transactions) {
      if (tx.status != 'approved' && tx.status != 'confirmed') continue;
      
      bool matches = false;
      if (person.id != null && tx.personId == person.id) matches = true;
      if (person.ledgixId != null && tx.personId == person.ledgixId) matches = true;

      if (matches) {
        final type = tx.type.toLowerCase();
        if (type == 'lend' || type == 'loan_given') {
          lent += tx.amount;
        } else if (type == 'borrow' || type == 'loan_received') {
          borrowed += tx.amount;
        } else if (type == 'repayment_received') {
          repaidReceived += tx.amount;
        } else if (type == 'repayment_paid' || type == 'repayment_sent') {
          repaidPaid += tx.amount;
        }
      }
    }

    return {
      'lent': lent,
      'borrowed': borrowed,
      'repaidReceived': repaidReceived,
      'repaidPaid': repaidPaid,
      'netBalance': (lent - repaidReceived) - (borrowed - repaidPaid),
    };
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = Provider.of<TransactionProvider>(context);
    final currency = Provider.of<SettingsProvider>(context).currency;
    final theme = Theme.of(context);
    final format = NumberFormat('#,##0.00');

    final personTransactions = txProvider.transactions.where((tx) {
      if (person.id != null && tx.personId == person.id) return true;
      if (person.ledgixId != null && tx.personId == person.ledgixId) return true;
      return false;
    }).toList();
    
    final summary = _calculateSummary(person, txProvider.transactions);
    final netBalance = summary['netBalance'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(person.name, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Column(
        children: [
          _buildHeader(summary, netBalance, currency, format, theme),
          Expanded(
            child: personTransactions.isEmpty
                ? const Center(child: Text('No transactions yet', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: personTransactions.length,
                    itemBuilder: (context, index) {
                      final tx = personTransactions[index];
                      return _buildTransactionCard(context, tx, currency, format, theme);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddExpenseScreen(
              transaction: TransactionModel(
                type: 'loan_given',
                category: 'Loan Given',
                account: '',
                note: '',
                amount: 0,
                date: DateTime.now(),
                personId: person.ledgixId ?? person.id,
              ),
            )),
          );
        },
        backgroundColor: theme.colorScheme.primary,
        label: const Text('New Lending', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add_rounded),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  Widget _buildHeader(Map<String, double> summary, double netBalance, String currency, NumberFormat format, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        children: [
          Text(
            netBalance == 0 ? 'SETTLED' : netBalance > 0 ? 'THEY OWE YOU' : 'YOU OWE THEM',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.4), fontWeight: FontWeight.w900, letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          FittedBox(
            child: Text(
              '$currency ${format.format(netBalance.abs())}',
              style: theme.textTheme.displaySmall?.copyWith(
                color: netBalance == 0 ? theme.colorScheme.onSurface : (netBalance > 0 ? theme.colorScheme.secondary : Colors.redAccent),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem('Lent', summary['lent']! - summary['repaidReceived']!, theme),
              Container(width: 1, height: 30, color: theme.colorScheme.outline),
              _summaryItem('Borrowed', summary['borrowed']! - summary['repaidPaid']!, theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, double amount, ThemeData theme) {
    return Column(
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5), fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(NumberFormat('#,##0').format(amount), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _buildTransactionCard(BuildContext context, TransactionModel tx, String currency, NumberFormat format, ThemeData theme) {
    final type = tx.type.toLowerCase();
    final isPositive = type == 'lend' || type == 'loan_given' || type == 'repayment_paid' || type == 'repayment_sent';
    
    IconData icon;
    Color color;
    if (type.contains('repayment')) {
      icon = Icons.sync_rounded;
      color = Colors.teal;
    } else if (type == 'lend' || type == 'loan_given') {
      icon = Icons.north_east_rounded;
      color = Colors.orange;
    } else {
      icon = Icons.south_west_rounded;
      color = Colors.brown;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: ListTile(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => AddExpenseScreen(transaction: tx)));
        },
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(tx.note.isEmpty ? tx.type.replaceAll('_', ' ').toUpperCase() : tx.note, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        subtitle: Text(DateFormat('dd MMM yyyy').format(tx.date), style: const TextStyle(fontSize: 11)),
        trailing: Text(
          '${isPositive ? '+' : '-'} ${format.format(tx.amount)}',
          style: TextStyle(
            color: isPositive ? theme.colorScheme.secondary : Colors.redAccent,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
