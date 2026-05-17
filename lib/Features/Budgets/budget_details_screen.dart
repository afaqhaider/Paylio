import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../Core/settings_provider.dart';
import '../Transactions/transaction_provider.dart';
import 'budget_model.dart';

class BudgetDetailsScreen extends StatelessWidget {
  final BudgetModel budget;
  const BudgetDetailsScreen({super.key, required this.budget});

  @override
  Widget build(BuildContext context) {
    final txProvider = Provider.of<TransactionProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final String currency = settings.currency;
    final theme = Theme.of(context);

    DateTime start;
    DateTime end;
    if (budget.period == 'Weekly') {
      DateTime budgetDate = DateTime(budget.year, budget.month);
      start = budgetDate.subtract(Duration(days: budgetDate.weekday - 1));
      end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    } else {
      start = DateTime(budget.year, budget.month, 1);
      end = DateTime(budget.year, budget.month + 1, 0, 23, 59, 59);
    }

    final filteredTxs = txProvider.transactions.where((t) {
      if (t.status != 'confirmed' && t.status != 'approved') return false;
      if (t.type != 'expense') return false;
      return t.category == budget.category &&
             t.date.isAfter(start.subtract(const Duration(seconds: 1))) &&
             t.date.isBefore(end.add(const Duration(seconds: 1)));
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${budget.category} Transactions'),
      ),
      body: filteredTxs.isEmpty
          ? const Center(child: Text('No transactions for this budget period.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredTxs.length,
              itemBuilder: (context, index) {
                final tx = filteredTxs[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(tx.note.isEmpty ? tx.category : tx.note),
                    subtitle: Text(DateFormat('dd MMM yyyy').format(tx.date)),
                    trailing: Text(
                      '$currency ${NumberFormat('#,##0.00').format(tx.amount)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
