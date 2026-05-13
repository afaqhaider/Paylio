import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../Core/database_helper.dart';
import '../../Core/settings_provider.dart';
import '../Transactions/transaction_model.dart';
import '../Transactions/add_expense_screen.dart';
import 'person_model.dart';

class PersonDetailScreen extends StatefulWidget {
  final PersonModel person;
  const PersonDetailScreen({super.key, required this.person});

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  List<TransactionModel> transactions = [];
  Map<String, double> summary = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    setState(() => isLoading = true);
    final allTxs = await DatabaseHelper.instance.getTransactions();
    final personTxs = allTxs.where((t) => t.personId == widget.person.id).toList();
    final s = await DatabaseHelper.instance.getPersonSummary(widget.person.id!);
    
    setState(() {
      transactions = personTxs;
      summary = s;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currency = Provider.of<SettingsProvider>(context).currency;
    final format = NumberFormat('#,##0.00');
    final netBalance = summary['netBalance'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.person.name),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary Card
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      Text(
                        netBalance == 0 ? 'Settled' : netBalance > 0 ? 'They Owe You' : 'You Owe Them',
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$currency ${format.format(netBalance.abs())}',
                        style: TextStyle(
                          color: netBalance == 0
                              ? Colors.white
                              : netBalance > 0
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _miniStat('Lent', summary['lent'] ?? 0, Colors.orange),
                          _miniStat('Borrowed', summary['borrowed'] ?? 0, Colors.brown),
                        ],
                      ),
                    ],
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),

                Expanded(
                  child: transactions.isEmpty
                      ? const Center(child: Text('No transactions yet', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: transactions.length,
                          itemBuilder: (context, index) {
                            final t = transactions[index];
                            return _transactionItem(t, currency, format);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddExpenseScreen()));
          loadData();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _miniStat(String label, double amount, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          NumberFormat('#,##0').format(amount),
          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _transactionItem(TransactionModel t, String currency, NumberFormat format) {
    final isPositive = t.type == 'lend' || t.type == 'repayment_paid';
    final color = t.type == 'lend' ? Colors.orange : 
                  t.type == 'borrow' ? Colors.brown :
                  t.type == 'repayment_received' ? const Color(0xFF10B981) : 
                  const Color(0xFFEF4444);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => AddExpenseScreen(transaction: t)));
          loadData();
        },
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
          child: Icon(
            t.type == 'lend' ? Icons.call_made_rounded : 
            t.type == 'borrow' ? Icons.call_received_rounded :
            t.type == 'repayment_received' ? Icons.keyboard_double_arrow_left_rounded : 
            Icons.keyboard_double_arrow_right_rounded,
            color: color, size: 18,
          ),
        ),
        title: Text(t.type.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Text(DateFormat('dd MMM yyyy').format(t.date), style: const TextStyle(fontSize: 11)),
        trailing: Text(
          '$currency ${format.format(t.amount)}',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color),
        ),
      ),
    );
  }
}
