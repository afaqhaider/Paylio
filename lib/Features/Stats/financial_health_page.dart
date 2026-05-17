import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../Core/settings_provider.dart';
import '../Accounts/account_provider.dart';
import '../Transactions/transaction_provider.dart';
import '../Commitments/commitment_provider.dart';
import '../Goals/goal_provider.dart';

class FinancialHealthPage extends StatelessWidget {
  const FinancialHealthPage({super.key});

  @override
  Widget build(BuildContext context) {
    final accProvider = Provider.of<AccountProvider>(context);
    final txProvider = Provider.of<TransactionProvider>(context);
    final commitmentProvider = Provider.of<CommitmentProvider>(context);
    final goalProvider = Provider.of<GoalProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final currency = settings.currency;
    final currencyFormat = NumberFormat('#,##0.00');

    // Assets Calculation
    double bankBalances = 0;
    double cashBalances = 0;
    for (var acc in accProvider.accounts) {
      double bal = accProvider.calculateAccountBalance(acc, txProvider.transactions);
      if (acc.type == 'Bank Account' || acc.type == 'Savings' || acc.type == 'Bank') {
        bankBalances += bal;
      } else if (acc.type == 'Cash') cashBalances += bal;
    }

    double receivables = 0;
    for (var tx in txProvider.transactions) {
      if (tx.status != 'approved' && tx.status != 'confirmed') continue;
      if (tx.type == 'lend' || tx.type == 'loan_given') {
        receivables += tx.amount;
      } else if (tx.type == 'repayment_received') receivables -= tx.amount;
    }

    final totalAssets = bankBalances + cashBalances + receivables;

    // Liabilities Calculation
    double loansPayable = 0;
    for (var tx in txProvider.transactions) {
      if (tx.status != 'approved' && tx.status != 'confirmed') continue;
      if (tx.type == 'borrow' || tx.type == 'loan_received') {
        loansPayable += tx.amount;
      } else if (tx.type == 'repayment_paid' || tx.type == 'repayment_sent' || tx.type == 'liability_payment') loansPayable -= tx.amount;
    }

    double upcomingCommitments = 0;
    for (var c in commitmentProvider.commitments) {
      if (c.status == 'Upcoming') upcomingCommitments += c.amount;
    }

    final totalLiabilities = loansPayable + upcomingCommitments;

    // Savings Calculation
    final double totalSavings = goalProvider.getTotalSaved();

    final balanceInHand = totalAssets - totalLiabilities - totalSavings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Health', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBalanceCard(balanceInHand, currency, theme, currencyFormat),
            const SizedBox(height: 32),
            _buildBarChart(totalAssets, totalLiabilities, totalSavings, theme),
            const SizedBox(height: 40),
            _buildSectionHeader('ASSETS', theme),
            _buildItem('Bank Balances', bankBalances, theme, currencyFormat, currency),
            _buildItem('Cash Balances', cashBalances, theme, currencyFormat, currency),
            _buildItem('Receivables', receivables, theme, currencyFormat, currency),
            const Divider(height: 32),
            _buildSectionHeader('LIABILITIES', theme),
            _buildItem('Loans Payable', loansPayable, theme, currencyFormat, currency, isNegative: true),
            _buildItem('Upcoming Commitments', upcomingCommitments, theme, currencyFormat, currency, isNegative: true),
            const Divider(height: 32),
            _buildSectionHeader('SAVINGS', theme),
            _buildItem('Total Savings', totalSavings, theme, currencyFormat, currency),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(double amount, String currency, ThemeData theme, NumberFormat format) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF218BFF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFF218BFF).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text('BALANCE IN HAND', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1.5, color: const Color(0xFF218BFF))),
          const SizedBox(height: 12),
          Text('$currency ${format.format(amount)}', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFF218BFF))),
        ],
      ),
    );
  }

  Widget _buildBarChart(double assets, double liabilities, double savings, ThemeData theme) {
    final maxVal = [assets, liabilities, savings].reduce((a, b) => a > b ? a : b);
    
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal * 1.2,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  switch (value.toInt()) {
                    case 0: return const Text('Assets', style: TextStyle(fontSize: 10));
                    case 1: return const Text('Liabilities', style: TextStyle(fontSize: 10));
                    case 2: return const Text('Savings', style: TextStyle(fontSize: 10));
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: [
            BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: assets, color: theme.colorScheme.primary, width: 40, borderRadius: BorderRadius.circular(8))]),
            BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: liabilities, color: Colors.redAccent, width: 40, borderRadius: BorderRadius.circular(8))]),
            BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: savings, color: Colors.amber, width: 40, borderRadius: BorderRadius.circular(8))]),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1.5, color: theme.colorScheme.onSurface.withOpacity(0.4))),
    );
  }

  Widget _buildItem(String label, double amount, ThemeData theme, NumberFormat format, String currency, {bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('${isNegative ? "-" : ""} $currency ${format.format(amount)}', style: TextStyle(fontWeight: FontWeight.w800, color: isNegative ? Colors.redAccent : null)),
        ],
      ),
    );
  }
}
