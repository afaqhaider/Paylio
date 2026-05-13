import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../Core/database_helper.dart';
import '../../Core/settings_provider.dart';
import '../Transactions/transaction_model.dart';
import '../Transactions/add_expense_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onTabChange;
  const DashboardScreen({super.key, required this.onTabChange});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double totalBalance = 0;
  double monthlyIncome = 0;
  double monthlyExpense = 0;
  List<TransactionModel> recentTransactions = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadDashboardData();
  }

  Future<void> loadDashboardData() async {
    setState(() => isLoading = true);
    
    try {
      final balance = await DatabaseHelper.instance.getTotalBalance();
      final summary = await DatabaseHelper.instance.getMonthlySummary();
      final recent = await DatabaseHelper.instance.getTransactions(limit: 5);

      setState(() {
        totalBalance = balance;
        monthlyIncome = summary['income'] ?? 0;
        monthlyExpense = summary['expense'] ?? 0;
        recentTransactions = recent;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading dashboard: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0.00');
    final String currency = Provider.of<SettingsProvider>(context).currency;
    final theme = Theme.of(context);

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
              onRefresh: loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$currency ${currencyFormat.format(totalBalance)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(child: summaryMiniItem('Income', monthlyIncome, const Color(0xFF10B981), currency)),
                              Container(width: 1, height: 40, color: Colors.white.withOpacity(0.1)),
                              Expanded(child: summaryMiniItem('Expenses', monthlyExpense, const Color(0xFFEF4444), currency)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Modern Quick Actions
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    const SizedBox(height: 32),

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
              ),
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
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$currency ${NumberFormat('#,##0').format(amount)}',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget actionButton(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
        );
        loadDashboardData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
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
          loadDashboardData();
        },
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
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
            Expanded(child: Text(item.category, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
            if (item.attachmentPath != null && item.attachmentPath!.isNotEmpty)
              const Icon(Icons.attachment_rounded, size: 14, color: Colors.grey),
          ],
        ),
        subtitle: Text(
          isTransfer ? '${item.account} → ${item.toAccount}' : item.account, 
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13)
        ),
        trailing: Text(
          '${isIncome ? '+' : (isExpense ? '-' : '')} $currency ${NumberFormat('#,##0.00').format(item.amount)}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: color,
          ),
        ),
      ),
    );
  }
}
