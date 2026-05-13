import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../Core/settings_provider.dart';
import '../Transactions/transactions_screen.dart';
import 'account_model.dart';
import 'account_provider.dart';
import 'add_account_screen.dart';
import '../Transactions/transaction_provider.dart';
import '../Commitments/commitment_provider.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('Import'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Automatic via Firestore streams
        },
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : accounts.isEmpty
                ? const Center(child: Text('No accounts yet', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: accounts.length,
                    itemBuilder: (context, index) {
                      final account = accounts[index];
                      final balance = accProvider.calculateAccountBalance(account, txProvider.transactions);
                      final linkedCommitments = commitmentProvider.commitments.where((c) => c.linkedAccount == account.name).toList();

                      return Column(
                        children: [
                          Card(
                            child: ListTile(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TransactionsScreen(accountFilter: account.name),
                                  ),
                                );
                              },
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F766E).withAlpha(20),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.account_balance_wallet_rounded,
                                  color: Color(0xFF0F766E),
                                  size: 20,
                                ),
                              ),
                              title: Text(account.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(account.type, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                  if (account.type == 'Credit Card') ...[
                                    Text(
                                      'Base: $currency ${NumberFormat('#,##0.00').format(account.openingBalance)}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ]
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '$currency ${NumberFormat('#,##0.00').format(balance)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: balance < 0 ? const Color(0xFFDC2626) : const Color(0xFF111827),
                                    ),
                                  ),
                                  if (account.type == 'Credit Card')
                                    Text(
                                      'Limit: ${NumberFormat('#,##0').format(account.creditLimit)}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (linkedCommitments.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 32.0, right: 16.0, bottom: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Linked Commitments:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                                  ...linkedCommitments.take(2).map((c) => Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('${c.name} (${DateFormat('dd MMM').format(c.nextDueDate ?? c.dueDate)})', style: const TextStyle(fontSize: 11)),
                                        Text('$currency ${NumberFormat('#,##0').format(c.amount)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  )),
                                  if (linkedCommitments.length > 2)
                                    const Text('...', style: TextStyle(fontSize: 11)),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'accountsFab',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddAccountScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
