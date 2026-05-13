import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../Core/database_helper.dart';
import '../../../Core/settings_provider.dart';
import '../Transactions/transactions_screen.dart';
import 'account_model.dart';
import 'add_account_screen.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  List<AccountModel> accounts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadAccounts();
  }

  Future<void> loadAccounts() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    final data = await DatabaseHelper.instance.getAccounts();
    if (!mounted) return;
    setState(() {
      accounts = data;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String currency = Provider.of<SettingsProvider>(context).currency;

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
        onRefresh: loadAccounts,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : accounts.isEmpty
                ? const Center(child: Text('No accounts yet', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: accounts.length,
                    itemBuilder: (context, index) {
                      final account = accounts[index];

                      return Card(
                        child: ListTile(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TransactionsScreen(accountFilter: account.name),
                              ),
                            );
                            loadAccounts();
                          },
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F766E).withOpacity(0.08),
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
                              if (account.type == 'Credit Card')
                                FutureBuilder<double>(
                                  future: DatabaseHelper.instance.getAccountBalance(account.name),
                                  builder: (context, snapshot) {
                                    final used = snapshot.data ?? 0;
                                    final limit = account.creditLimit ?? 0;
                                    final available = limit - used;
                                    final usagePercent = limit > 0 ? (used / limit) : 0;
                                    
                                    Color warningColor = Colors.transparent;
                                    String warningText = '';
                                    if (usagePercent >= 1.0) {
                                      warningColor = const Color(0xFFEF4444);
                                      warningText = 'Credit card limit exceeded';
                                    } else if (usagePercent >= 0.8) {
                                      warningColor = Colors.orange;
                                      warningText = 'You are near your credit card limit';
                                    }

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Available: $currency ${NumberFormat('#,##0.00').format(available)}',
                                          style: TextStyle(fontSize: 12, color: available < 0 ? const Color(0xFFEF4444) : Colors.grey.shade600),
                                        ),
                                        if (warningText.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              warningText,
                                              style: TextStyle(fontSize: 11, color: warningColor, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                            ],
                          ),
                          trailing: FutureBuilder<double>(
                            future: DatabaseHelper.instance.getAccountBalance(account.name),
                            builder: (context, snapshot) {
                              final balance = snapshot.data ?? account.openingBalance;
                              final isCreditCard = account.type == 'Credit Card';
                              // Red if balance is negative for normal accounts, OR if it's CC (which shows used amount)
                              // Requirement 2: Show balance in red if below 0.
                              final isNegative = balance < 0;

                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '$currency ${NumberFormat('#,##0.00').format(balance)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: (isNegative && !isCreditCard) ? const Color(0xFFEF4444) : const Color(0xFF111827),
                                    ),
                                  ),
                                  if (isCreditCard)
                                    Text(
                                      'Limit: ${NumberFormat('#,##0').format(account.creditLimit)}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
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
          loadAccounts();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
