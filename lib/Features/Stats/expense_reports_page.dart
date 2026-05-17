import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../Core/settings_provider.dart';
import '../Transactions/transaction_model.dart';
import '../Transactions/transaction_provider.dart';
import '../Categories/category_provider.dart';
import '../Accounts/account_provider.dart';
import '../Transactions/add_expense_screen.dart';

class ExpenseReportsPage extends StatefulWidget {
  const ExpenseReportsPage({super.key});

  @override
  State<ExpenseReportsPage> createState() => _ExpenseReportsPageState();
}

class _ExpenseReportsPageState extends State<ExpenseReportsPage> {
  DateTimeRange? _dateRange;
  String? _selectedCategory;
  String? _selectedAccount;
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
    );
  }

  List<TransactionModel> _getFilteredTransactions(List<TransactionModel> all) {
    return all.where((tx) {
      if (tx.status == 'pending' || tx.status == 'rejected') return false;
      // Accounting-Correct: REAL expenses only. 
      // Lend, repayment_paid, transfer etc. are NOT expenses.
      if (tx.type.toLowerCase() != 'expense') return false;

      if (_dateRange != null) {
        if (tx.date.isBefore(_dateRange!.start) || tx.date.isAfter(_dateRange!.end)) return false;
      }
      if (_selectedCategory != null && tx.category != _selectedCategory) return false;
      if (_selectedAccount != null && tx.account != _selectedAccount) return false;

      return true;
    }).toList();
  }

  Map<String, double> _groupByCategory(List<TransactionModel> txs) {
    Map<String, double> data = {};
    for (var tx in txs) {
      data[tx.category] = (data[tx.category] ?? 0) + tx.amount;
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = Provider.of<TransactionProvider>(context);
    final catProvider = Provider.of<CategoryProvider>(context);
    final accProvider = Provider.of<AccountProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final currency = settings.currency;

    final filteredTxs = _getFilteredTransactions(txProvider.transactions);
    final groupedData = _groupByCategory(filteredTxs);
    final totalExpense = groupedData.values.fold(0.0, (sum, val) => sum + val);

    final sortedKeys = groupedData.keys.toList()..sort((a, b) => groupedData[b]!.compareTo(groupedData[a]!));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Reports', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildFilters(theme, catProvider, accProvider),
            const SizedBox(height: 24),
            if (groupedData.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No data found for selected filters')))
            else ...[
              _buildDonutChart(groupedData, sortedKeys, totalExpense, currency, theme, catProvider),
              const SizedBox(height: 32),
              _buildCategoryList(groupedData, sortedKeys, totalExpense, currency, theme, catProvider, filteredTxs),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(ThemeData theme, CategoryProvider catP, AccountProvider accP) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surface.withOpacity(0.5),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterChip(
              label: Text(_dateRange == null ? 'Date Range' : '${DateFormat('MMM d').format(_dateRange!.start)} - ${DateFormat('MMM d').format(_dateRange!.end)}'),
              selected: _dateRange != null,
              onSelected: (_) async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  initialDateRange: _dateRange,
                );
                if (picked != null) setState(() => _dateRange = picked);
              },
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              hint: const Text('Category'),
              value: _selectedCategory,
              underline: const SizedBox(),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Categories')),
                ...catP.expenseCategories.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))),
              ],
              onChanged: (val) => setState(() => _selectedCategory = val),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              hint: const Text('Account'),
              value: _selectedAccount,
              underline: const SizedBox(),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Accounts')),
                ...accP.accounts.map((a) => DropdownMenuItem(value: a.name, child: Text(a.name))),
              ],
              onChanged: (val) => setState(() => _selectedAccount = val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonutChart(Map<String, double> data, List<String> keys, double total, String currency, ThemeData theme, CategoryProvider catP) {
    List<PieChartSectionData> sections = [];

    for (int i = 0; i < keys.length; i++) {
      final isTouched = i == _touchedIndex;
      final fontSize = isTouched ? 18.0 : 12.0;
      final radius = isTouched ? 60.0 : 50.0;
      final key = keys[i];
      final val = data[key]!;

      sections.add(PieChartSectionData(
        color: catP.getColorForCategory(key, null),
        value: val,
        title: isTouched ? '${(val / total * 100).toStringAsFixed(1)}%' : '',
        radius: radius,
        titleStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          height: 250,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                      _touchedIndex = -1;
                      return;
                    }
                    _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                    
                    if (event is FlTapUpEvent && _touchedIndex != -1) {
                       final tappedCategory = keys[_touchedIndex!];
                       _showTransactionsForCategory(tappedCategory);
                    }
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 2,
              centerSpaceRadius: 60,
              sections: sections,
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('TOTAL', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1.5, color: theme.colorScheme.onSurface.withOpacity(0.4))),
            Text('$currency ${NumberFormat('#,##0').format(total)}', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFF218BFF))),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryList(Map<String, double> data, List<String> keys, double total, String currency, ThemeData theme, CategoryProvider catP, List<TransactionModel> txs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: keys.map((key) {
          final val = data[key]!;
          final percent = (val / total * 100).toStringAsFixed(1);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              onTap: () => _showTransactionsForCategory(key),
              leading: Container(
                width: 12, height: 12,
                decoration: BoxDecoration(color: catP.getColorForCategory(key, null), shape: BoxShape.circle),
              ),
              title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$currency ${NumberFormat('#,##0.00').format(val)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text('$percent%', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withOpacity(0.5))),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showTransactionsForCategory(String category) {
     final txProvider = Provider.of<TransactionProvider>(context, listen: false);
     final filtered = _getFilteredTransactions(txProvider.transactions).where((t) => t.category == category).toList();

     showModalBottomSheet(
       context: context,
       isScrollControlled: true,
       backgroundColor: Theme.of(context).scaffoldBackgroundColor,
       shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
       builder: (context) => DraggableScrollableSheet(
         initialChildSize: 0.7,
         minChildSize: 0.5,
         maxChildSize: 0.95,
         expand: false,
         builder: (context, scrollController) => Column(
           children: [
             Padding(
               padding: const EdgeInsets.all(20),
               child: Text('$category Transactions', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
             ),
             Expanded(
               child: ListView.builder(
                 controller: scrollController,
                 padding: const EdgeInsets.symmetric(horizontal: 16),
                 itemCount: filtered.length,
                 itemBuilder: (context, index) {
                   final tx = filtered[index];
                   return Card(
                     margin: const EdgeInsets.only(bottom: 12),
                     child: ListTile(
                       onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AddExpenseScreen(transaction: tx))),
                       title: Text(tx.note.isEmpty ? tx.category : tx.note),
                       subtitle: Text(DateFormat('dd MMM yyyy').format(tx.date)),
                       trailing: Text('${tx.amount}', style: const TextStyle(fontWeight: FontWeight.bold)),
                     ),
                   );
                 },
               ),
             ),
           ],
         ),
       ),
     );
  }
}
