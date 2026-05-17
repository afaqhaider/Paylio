import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../Core/settings_provider.dart';
import '../Transactions/transactions_screen.dart';
import 'account_provider.dart';
import 'add_account_screen.dart';
import '../Transactions/transaction_provider.dart';
import '../Commitments/commitment_provider.dart';
import '../../shared/widgets/app_fab.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  @override
  Widget build(BuildContext context) {
    final accProvider = Provider.of<AccountProvider>(context);
    final txProvider = Provider.of<TransactionProvider>(context);
    final commitmentProvider = Provider.of<CommitmentProvider>(context);
    final String currency = Provider.of<SettingsProvider>(context).currency;
    final accounts = accProvider.accounts;
    final isLoading = accProvider.isLoading || txProvider.isLoading;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, size: 28),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        title: const Text('Accounts', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : accounts.isEmpty
                ? const Center(child: Text('No accounts yet', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    itemCount: accounts.length,
                    itemBuilder: (context, index) {
                      final account = accounts[index];
                      final balance = accProvider.calculateAccountBalance(account, txProvider.transactions);
                      final linkedCommitments = commitmentProvider.commitments.where((c) => c.linkedAccount == account.name).toList();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: theme.colorScheme.outline),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TransactionsScreen(accountFilter: account.name),
                                  ),
                                );
                              },
                              contentPadding: const EdgeInsets.all(20),
                              leading: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  _getAccountIcon(account.type),
                                  color: theme.colorScheme.primary,
                                  size: 24,
                                ),
                              ),
                              title: Text(account.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(account.type, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '$currency ${NumberFormat('#,##0.00').format(balance)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: balance < 0 ? Colors.redAccent : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  if (account.type == 'Credit Card')
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        'Limit: ${NumberFormat('#,##0').format(account.creditLimit)}',
                                        style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withOpacity(0.4), fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (linkedCommitments.isNotEmpty)
                              _buildLinkedCommitments(linkedCommitments, currency, theme),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  IconData _getAccountIcon(String type) {
    switch (type.toLowerCase()) {
      case 'credit card': return Icons.credit_card_rounded;
      case 'bank account': return Icons.account_balance_rounded;
      case 'cash': return Icons.payments_rounded;
      case 'savings': return Icons.savings_rounded;
      default: return Icons.account_balance_wallet_rounded;
    }
  }

  Widget _buildLinkedCommitments(List<dynamic> commitments, String currency, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: theme.colorScheme.outline.withOpacity(0.5)),
          const SizedBox(height: 12),
          Text('ACTIVE COMMITMENTS', style: theme.textTheme.bodySmall?.copyWith(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1, color: theme.colorScheme.onSurface.withOpacity(0.4))),
          const SizedBox(height: 8),
          ...commitments.take(2).map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(c.name, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                Text('$currency ${NumberFormat('#,##0').format(c.amount)}', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
