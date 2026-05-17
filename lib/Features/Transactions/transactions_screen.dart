import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../Core/settings_provider.dart';
import 'transaction_detail_sheet.dart';
import 'transaction_model.dart';
import 'transaction_provider.dart';

class TransactionsScreen extends StatefulWidget {
  final String? accountFilter;
  const TransactionsScreen({super.key, this.accountFilter});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String selectedPeriod = 'This Month';
  final currencyFormat = NumberFormat('#,##0.00');

  List<TransactionModel> _filterTransactions(List<TransactionModel> all) {
    if (widget.accountFilter == null) return all;
    return all.where((t) => t.account == widget.accountFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = Provider.of<TransactionProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final String currency = settings.currency;
    final theme = Theme.of(context);

    final allTransactions = txProvider.transactions;
    final transactions = _filterTransactions(allTransactions);
    final isLoading = txProvider.isLoading;

    // Group transactions by date
    Map<String, List<TransactionModel>> groupedTransactions = {};
    for (var tx in transactions) {
      if (tx.status == 'rejected') continue;
      String dateKey = DateFormat('yyyy-MM-dd').format(tx.date);
      if (!groupedTransactions.containsKey(dateKey)) {
        groupedTransactions[dateKey] = [];
      }
      groupedTransactions[dateKey]!.add(tx);
    }

    var sortedDateKeys = groupedTransactions.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, size: 28),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        title: const Text('Activity', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Search coming soon')));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildPeriodSelector(theme),
                Expanded(
                  child: sortedDateKeys.isEmpty
                      ? _buildEmptyState(theme)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          itemCount: sortedDateKeys.length,
                          itemBuilder: (context, index) {
                            String dateKey = sortedDateKeys[index];
                            List<TransactionModel> dayTxs = groupedTransactions[dateKey]!;
                            return _buildDateGroupCard(dateKey, dayTxs, currency, theme);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text('No transactions found', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5))),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(ThemeData theme) {
    final periods = ['This Week', 'This Month', 'Last Month', 'This Year', 'All Time'];
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: periods.length,
        separatorBuilder: (c, i) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          bool isSelected = selectedPeriod == periods[index];
          return ChoiceChip(
            label: Text(periods[index]),
            selected: isSelected,
            onSelected: (val) => setState(() => selectedPeriod = periods[index]),
            selectedColor: theme.colorScheme.primary,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.6),
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 12,
            ),
            backgroundColor: theme.colorScheme.surface,
            side: BorderSide(color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            showCheckmark: false,
          );
        },
      ),
    );
  }

  Widget _buildDateGroupCard(String dateKey, List<TransactionModel> dayTxs, String currency, ThemeData theme) {
    DateTime date = DateTime.parse(dateKey);
    bool isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == dateKey;
    String displayDate = isToday ? 'Today, ${DateFormat('MMM d').format(date)}' : DateFormat('EEEE, MMM d').format(date);

    double dayIncome = 0;
    double dayExpense = 0;
    for (var tx in dayTxs) {
      if (tx.status == 'pending') continue;
      bool isIncome = tx.type == 'income' || tx.type == 'loan_received';
      if (isIncome) {
        dayIncome += tx.amount;
      } else {
        dayExpense += tx.amount;
      }
    }
    double dailyTotal = dayIncome - dayExpense;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.colorScheme.outline),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  displayDate.toUpperCase(),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.4), fontWeight: FontWeight.w900, letterSpacing: 1.2),
                ),
                Text(
                  '${dailyTotal >= 0 ? "+" : "-"} $currency ${currencyFormat.format(dailyTotal.abs())}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: dailyTotal >= 0 ? theme.colorScheme.secondary : Colors.redAccent.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: dayTxs.length,
            separatorBuilder: (c, i) => Divider(indent: 20, endIndent: 20, color: theme.colorScheme.outline.withOpacity(0.3)),
            itemBuilder: (context, index) {
              final tx = dayTxs[index];
              bool isIncome = tx.type == 'income' || tx.type == 'loan_received';
              return ListTile(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => TransactionDetailSheet(transaction: tx, currency: currency),
                  );
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                title: Text(tx.category, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                subtitle: Text(tx.account, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                trailing: Text(
                  '${isIncome ? "+" : "-"} ${currencyFormat.format(tx.amount)}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isIncome ? theme.colorScheme.secondary : theme.colorScheme.onSurface,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
