import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../Core/settings_provider.dart';
import '../Transactions/transaction_model.dart';
import '../Transactions/transaction_provider.dart';
import '../Accounts/account_provider.dart';
import '../Categories/category_provider.dart';
import '../Commitments/commitment_provider.dart';
import '../Commitments/commitments_screen.dart';
import '../Goals/goal_provider.dart';
import '../Goals/goals_screen.dart';
import '../Transactions/transaction_detail_sheet.dart';
import '../Stats/expense_reports_page.dart';
import '../Auth/auth_provider.dart' as ledgix_auth;
import '../Transactions/pending_approvals_screen.dart';
import '../Transactions/shared_transaction_provider.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onTabChange;
  final GlobalKey<ScaffoldState> scaffoldKey;
  const DashboardScreen({super.key, required this.onTabChange, required this.scaffoldKey});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final currencyFormat = NumberFormat('#,##0.00');

  @override
  Widget build(BuildContext context) {
    final txProvider = Provider.of<TransactionProvider>(context);
    final accProvider = Provider.of<AccountProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final authProvider = Provider.of<ledgix_auth.LedGixAuthProvider>(context);
    final commitmentProvider = Provider.of<CommitmentProvider>(context);
    final sharedProvider = Provider.of<SharedTransactionProvider>(context);
    final catProvider = Provider.of<CategoryProvider>(context);
    final goalProvider = Provider.of<GoalProvider>(context);
    
    final theme = Theme.of(context);
    final String currency = settings.currency;
    final user = authProvider.user;

    final totalBalance = accProvider.getTotalBalance(txProvider.transactions);
    final monthlySummary = txProvider.getMonthlySummary();
    final recentTransactions = txProvider.transactions.take(5).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(context, sharedProvider),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Welcome Text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good ${DateTime.now().hour < 12 ? "Morning" : "Evening"}, ${user?.name.split(" ").first ?? "User"}',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Financial Overview',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Hero Section - Total Balance
              _buildHeroSection(totalBalance, monthlySummary, currency, theme),
              
              const SizedBox(height: 32),

              // Middle Section - Financial Health & Reminders
              _buildMiddleSection(context, commitmentProvider, goalProvider, currency, theme),

              const SizedBox(height: 32),

              // Charts Section
              _buildChartsSection(txProvider.transactions, currency, theme, catProvider),

              const SizedBox(height: 32),

              // Recent Activity Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Activity', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    TextButton(
                      onPressed: () => widget.onTabChange(1),
                      child: Text('View All', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              _buildRecentGroupedActivity(recentTransactions, currency, theme),
              
              const SizedBox(height: 100), // Bottom spacing for FAB and Nav
            ],
          ),
        ),
      ),
      floatingActionButton: null,
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, SharedTransactionProvider shared) {
    final theme = Theme.of(context);
    final txProvider = Provider.of<TransactionProvider>(context);
    final isSyncing = txProvider.isLoading;

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, size: 28),
        onPressed: () => widget.scaffoldKey.currentState?.openDrawer(),
      ),
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Hero(
            tag: 'logo',
            child: Image.asset(
              'assets/logo/ledgix_logo.png',
              height: 52, // Increased size for visibility
              fit: BoxFit.contain, 
              errorBuilder: (c, e, s) => const Text('LEDGIX', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5))
            ),
          ),
          if (isSyncing) ...[
            const SizedBox(width: 12),
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.5)),
          ]
        ],
      ),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, size: 28),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PendingApprovalsScreen())),
            ),
            if (shared.myActionCount > 0)
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, border: Border.all(color: theme.colorScheme.surface, width: 2)),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildHeroSection(double balance, Map<String, double> summary, String currency, ThemeData theme) {
    return GestureDetector(
      onTap: () => widget.onTabChange(3), // Navigate to Accounts
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: theme.colorScheme.outline),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TOTAL BALANCE',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.4), fontWeight: FontWeight.w900, letterSpacing: 1.5),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$currency ${currencyFormat.format(balance)}',
                      style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                  child: Icon(Icons.account_balance_wallet_rounded, color: theme.colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                _summaryItem('Income', summary['income'] ?? 0, theme.colorScheme.secondary, currency, theme),
                const SizedBox(width: 24),
                _summaryItem('Expenses', summary['expense'] ?? 0, Colors.redAccent, currency, theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, double amount, Color color, String currency, ThemeData theme) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5), fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              '$currency ${currencyFormat.format(amount)}',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiddleSection(BuildContext context, CommitmentProvider provider, GoalProvider goalProvider, String currency, ThemeData theme) {
    final upcoming = provider.getUpcomingCommitments();
    final totalSaved = goalProvider.getTotalSaved();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FINANCIAL HEALTH', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.4), fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => widget.onTabChange(2), // Navigate to Budgets
                  child: _healthCard(
                    'Budget', 
                    '75%', 
                    Icons.pie_chart_rounded, 
                    theme.colorScheme.primary, 
                    theme
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GoalsScreen())),
                  child: _healthCard(
                    'Savings', 
                    '$currency ${currencyFormat.format(totalSaved)}', 
                    Icons.savings_rounded, 
                    theme.colorScheme.secondary, 
                    theme
                  ),
                ),
              ),
            ],
          ),
          if (upcoming.isNotEmpty) ...[
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('UPCOMING REMINDERS', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.4), fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CommitmentsScreen())),
                  child: const Text('Manage', style: TextStyle(color: Color(0xFF218BFF), fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...upcoming.take(2).map((c) => GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CommitmentsScreen())),
              child: _reminderItem(c, currency, theme)
            )),
          ],
        ],
      ),
    );
  }

  Widget _healthCard(String title, String value, IconData icon, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withOpacity(0.6))),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _reminderItem(dynamic commitment, String currency, ThemeData theme) {
    final date = commitment.nextDueDate ?? commitment.dueDate;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.calendar_month_rounded, color: Colors.amber, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(commitment.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                Text(DateFormat('dd MMM yyyy').format(date), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Text('$currency ${currencyFormat.format(commitment.amount)}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildChartsSection(List<TransactionModel> txs, String currency, ThemeData theme, CategoryProvider catP) {
    final expenseData = _getCategoryData(txs, 'expense');
    if (expenseData.isEmpty) return const SizedBox.shrink();

    final total = expenseData.values.fold(0.0, (sum, val) => sum + val);
    final sortedKeys = expenseData.keys.toList()..sort((a, b) => expenseData[b]!.compareTo(expenseData[a]!));
    
    List<PieChartSectionData> sections = [];
    final displayKeys = sortedKeys.take(4).toList();

    for (int i = 0; i < displayKeys.length; i++) {
      final key = displayKeys[i];
      final val = expenseData[key]!;
      sections.add(PieChartSectionData(
        value: val,
        color: catP.getColorForCategory(key, null),
        radius: 35,
        showTitle: false,
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EXPENSE ANALYSIS', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.4), fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ExpenseReportsPage())),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Row(
                children: [
                  SizedBox(
                    height: 120,
                    width: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sections: sections, 
                            centerSpaceRadius: 35, 
                            sectionsSpace: 3,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'TOTAL',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.onSurface.withOpacity(0.4),
                              ),
                            ),
                            FittedBox(
                              child: Text(
                                formatCompact(total),
                                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFF218BFF)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: displayKeys.map((k) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: catP.getColorForCategory(k, null), shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(k, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Text('${(expenseData[k]! / total * 100).toStringAsFixed(0)}%', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900)),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String formatCompact(double value) {
    return NumberFormat.compact().format(value);
  }

  Map<String, double> _getCategoryData(List<TransactionModel> transactions, String targetType) {
    final now = DateTime.now();
    Map<String, double> data = {};
    for (var tx in transactions) {
      if (tx.status == 'pending' || tx.status == 'rejected') continue;
      // Show ONLY current month data
      if (tx.date.month != now.month || tx.date.year != now.year) continue;

      final type = tx.type.toLowerCase();
      if (type == targetType) {
        data[tx.category] = (data[tx.category] ?? 0) + tx.amount;
      }
    }
    return data;
  }

  Widget _buildRecentGroupedActivity(List<TransactionModel> txs, String currency, ThemeData theme) {
    if (txs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No transactions yet')));

    // Group transactions by date
    Map<String, List<TransactionModel>> grouped = {};
    for (var tx in txs) {
      String dateKey = DateFormat('yyyy-MM-dd').format(tx.date);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(tx);
    }

    var sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: sortedKeys.map((dateKey) {
          final date = DateTime.parse(dateKey);
          final dayTxs = grouped[dateKey]!;
          final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == dateKey;
          final displayDate = isToday ? 'Today' : DateFormat('EEEE, MMM d').format(date);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
                child: Text(
                  displayDate.toUpperCase(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              ...dayTxs.map((tx) {
                final isIncome = ['income', 'repayment_received', 'borrow', 'loan_received'].contains(tx.type.toLowerCase());
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: ListTile(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => TransactionDetailSheet(transaction: tx, currency: currency),
                      );
                    },
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.background,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
                        color: isIncome ? theme.colorScheme.primary : Colors.redAccent,
                        size: 18,
                      ),
                    ),
                    title: Text(tx.category, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                    subtitle: Text(tx.account, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                    trailing: Text(
                      '${isIncome ? "+" : "-"} ${currencyFormat.format(tx.amount)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isIncome ? theme.colorScheme.primary : theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        }).toList(),
      ),
    );
  }
}
