import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../Core/settings_provider.dart';
import '../Transactions/transaction_model.dart';
import '../Transactions/transaction_provider.dart';
import '../Accounts/account_provider.dart';
import '../Categories/category_provider.dart';
import '../Transactions/add_expense_screen.dart';
import '../Commitments/commitment_provider.dart';
import '../Commitments/commitments_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onTabChange;
  const DashboardScreen({super.key, required this.onTabChange});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String selectedPeriod = 'Current Month';
  DateTimeRange? customDateRange;

  List<TransactionModel> _getFilteredTransactions(List<TransactionModel> all) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (selectedPeriod) {
      case 'Current Month':
        start = DateTime(now.year, now.month, 1);
        break;
      case 'Last Month':
        start = DateTime(now.year, now.month - 1, 1);
        end = DateTime(now.year, now.month, 0, 23, 59, 59);
        break;
      case 'Last 3 Months':
        start = DateTime(now.year, now.month - 2, 1);
        break;
      case 'This Year':
        start = DateTime(now.year, 1, 1);
        break;
      case 'Custom':
        if (customDateRange != null) {
          start = customDateRange!.start;
          end = customDateRange!.end.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
        } else {
          start = DateTime(now.year, now.month, 1);
        }
        break;
      case 'All Time':
      default:
        return all;
    }

    return all.where((t) => t.date.isAfter(start.subtract(const Duration(seconds: 1))) && t.date.isBefore(end.add(const Duration(seconds: 1)))).toList();
  }

  Map<String, double> _calculateSummary(List<TransactionModel> txs) {
    double income = 0;
    double expense = 0;
    for (var tx in txs) {
      final type = tx.type.toLowerCase();
      if (['income', 'repayment_received', 'borrow'].contains(type)) {
        income += tx.amount;
      } else if (['expense', 'repayment_paid', 'lend'].contains(type)) {
        expense += tx.amount;
      }
    }
    return {'income': income, 'expense': expense};
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = Provider.of<TransactionProvider>(context);
    final accProvider = Provider.of<AccountProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final commitmentProvider = Provider.of<CommitmentProvider>(context);
    
    final currencyFormat = NumberFormat('#,##0.00');
    final String currency = settings.currency;
    final theme = Theme.of(context);

    final filteredTransactions = _getFilteredTransactions(txProvider.transactions);
    final summary = _calculateSummary(filteredTransactions);
    final totalBalance = accProvider.getTotalBalance(txProvider.transactions); // Balance is always All Time
    final recentTransactions = txProvider.transactions.take(5).toList();

    final isLoading = txProvider.isLoading || accProvider.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PAYLIO'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {},
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Period Selector
                        _buildPeriodSelector(),

                        // Premium Balance Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Balance',
                                style: TextStyle(
                                  color: Colors.white.withAlpha(178),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              FittedBox(
                                child: Text(
                                  '$currency ${currencyFormat.format(totalBalance)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              Row(
                                children: [
                                  Expanded(child: summaryMiniItem('Income', summary['income'] ?? 0, const Color(0xFF10B981), currency)),
                                  Container(width: 1, height: 40, color: Colors.white.withAlpha(25)),
                                  Expanded(child: summaryMiniItem('Expenses', summary['expense'] ?? 0, const Color(0xFFEF4444), currency)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Charts Section
                        _buildCharts(filteredTransactions, currency, theme),

                        // Upcoming Commitments Card
                        _buildCommitmentsSummary(commitmentProvider, currency, currencyFormat, theme),

                        // Modern Quick Actions
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          child: Row(
                            children: [
                              Expanded(child: actionButton(Icons.add_rounded, 'Expense', const Color(0xFFEF4444))),
                              const SizedBox(width: 12),
                              Expanded(child: actionButton(Icons.arrow_downward_rounded, 'Income', const Color(0xFF10B981))),
                              const SizedBox(width: 12),
                              Expanded(child: actionButton(Icons.swap_horiz_rounded, 'Transfer', const Color(0xFF7C3AED))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Recent Activity Header
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Recent Activity',
                                style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
                              ),
                              TextButton(
                                onPressed: () => widget.onTabChange(1),
                                child: const Text('See All'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        recentTransactions.isEmpty
                            ? const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No recent activity')))
                            : Column(
                                children: recentTransactions.map((item) => transactionListItem(item, currency, context)).toList(),
                              ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    final periods = ['Current Month', 'Last Month', 'Last 3 Months', 'This Year', 'All Time', 'Custom'];
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: periods.length,
        itemBuilder: (context, index) {
          final p = periods[index];
          final isSelected = selectedPeriod == p;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(p, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              selected: isSelected,
              onSelected: (val) async {
                if (p == 'Custom') {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (range != null) {
                    setState(() {
                      customDateRange = range;
                      selectedPeriod = p;
                    });
                  }
                } else {
                  setState(() => selectedPeriod = p);
                }
              },
              selectedColor: const Color(0xFF0F766E),
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCommitmentsSummary(CommitmentProvider provider, String currency, NumberFormat format, ThemeData theme) {
    final upcoming = provider.getUpcomingCommitments();
    if (upcoming.isEmpty) return const SizedBox.shrink();

    final nextThree = upcoming.take(3).toList();
    final totalDue = upcoming.fold(0.0, (sum, item) => sum + item.amount);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withAlpha(25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Upcoming Commitments', style: theme.textTheme.titleMedium),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CommitmentsScreen())),
                child: Text('See All', style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...nextThree.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: theme.colorScheme.primary.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.calendar_today, size: 16, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(DateFormat('dd MMM').format(c.nextDueDate ?? c.dueDate), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                Text('$currency ${format.format(c.amount)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          )),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total due this month', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('$currency ${format.format(totalDue)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget summaryMiniItem(String label, double amount, Color color, String currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: Colors.white.withAlpha(153), fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          child: Text(
            '$currency ${NumberFormat('#,##0').format(amount)}',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget actionButton(IconData icon, String label, Color color) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withAlpha(25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
          ],
        ),
      ),
    );
  }

  Widget _buildCharts(List<TransactionModel> transactions, String currency, ThemeData theme) {
    final catProvider = Provider.of<CategoryProvider>(context, listen: false);
    final expenseData = _getCategoryData(transactions, 'expense');
    final incomeData = _getCategoryData(transactions, 'income');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _chartCard('Expense Breakdown', expenseData, const Color(0xFFEF4444), currency, theme, catProvider),
          const SizedBox(height: 16),
          _chartCard('Income Breakdown', incomeData, const Color(0xFF10B981), currency, theme, catProvider),
        ],
      ),
    );
  }

  Map<String, double> _getCategoryData(List<TransactionModel> transactions, String targetType) {
    Map<String, double> data = {};
    for (var tx in transactions) {
      final type = tx.type.toLowerCase();
      bool matches = false;
      if (targetType == 'expense') {
        matches = ['expense', 'repayment_paid', 'lend'].contains(type);
      } else if (targetType == 'income') {
        matches = ['income', 'repayment_received', 'borrow'].contains(type);
      }

      if (matches) {
        data[tx.category] = (data[tx.category] ?? 0) + tx.amount;
      }
    }
    return data;
  }

  Widget _chartCard(String title, Map<String, double> data, Color baseColor, String currency, ThemeData theme, CategoryProvider catP) {
    if (data.isEmpty) {
      return Card(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 20),
              Text('No ${title.toLowerCase()} data yet', style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final total = data.values.fold(0.0, (sum, val) => sum + val);
    final sortedKeys = data.keys.toList()..sort((a, b) => data[b]!.compareTo(data[a]!));
    
    List<PieChartSectionData> sections = [];
    final displayKeys = sortedKeys.take(5).toList();
    double otherSum = 0;
    if (sortedKeys.length > 5) {
      otherSum = sortedKeys.skip(5).fold(0.0, (sum, k) => sum + data[k]!);
    }

    for (int i = 0; i < displayKeys.length; i++) {
      final key = displayKeys[i];
      final val = data[key]!;
      final percentage = (val / total * 100).toStringAsFixed(1);
      
      // Get consistent color for category
      final catColor = catP.getColorForCategory(key, null);

      sections.add(PieChartSectionData(
        value: val,
        title: '$percentage%',
        color: catColor,
        radius: 50,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }

    if (otherSum > 0) {
      sections.add(PieChartSectionData(
        value: otherSum,
        title: '${(otherSum / total * 100).toStringAsFixed(1)}%',
        color: Colors.grey.withOpacity(0.5),
        radius: 50,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                Text('$currency ${NumberFormat('#,##0').format(total)}', style: TextStyle(color: baseColor, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Legend
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ...displayKeys.map((key) {
                  final catColor = catP.getColorForCategory(key, null);
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: catColor, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(key, style: const TextStyle(fontSize: 11)),
                    ],
                  );
                }),
                if (otherSum > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      const Text('Others', style: TextStyle(fontSize: 11)),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget transactionListItem(TransactionModel item, String currency, BuildContext context) {
    final isIncome = item.type == 'income' || item.type == 'repayment_received' || item.type == 'borrow';
    final isExpense = item.type == 'expense' || item.type == 'repayment_paid' || item.type == 'lend';
    final isTransfer = item.type == 'transfer';
    
    final color = isIncome 
        ? const Color(0xFF10B981) 
        : isExpense 
            ? const Color(0xFFEF4444) 
            : const Color(0xFF7C3AED);

    IconData iconData = Icons.swap_horiz_rounded;
    if (isIncome) iconData = Icons.arrow_upward_rounded;
    if (isExpense) iconData = Icons.arrow_downward_rounded;

    return Card(
      child: ListTile(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddExpenseScreen(transaction: item)),
          );
        },
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            iconData,
            color: color,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(item.category, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
            if (item.attachmentPath != null && item.attachmentPath!.isNotEmpty)
              const Icon(Icons.attachment_rounded, size: 14, color: Colors.grey),
          ],
        ),
        subtitle: Text(
          isTransfer ? '${item.account} → ${item.toAccount}' : item.account, 
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: FittedBox(
          child: Text(
            '${isIncome ? '+' : (isExpense ? '-' : '')} $currency ${NumberFormat('#,##0.00').format(item.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
