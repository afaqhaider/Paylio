import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../Core/settings_provider.dart';
import '../Transactions/transaction_provider.dart';
import '../Transactions/transaction_model.dart';
import 'person_model.dart';
import 'person_provider.dart';
import 'person_detail_screen.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  Map<String, double> _calculatePersonSummary(String personId, List<TransactionModel> transactions) {
    double lent = 0;
    double borrowed = 0;
    double repaidReceived = 0;
    double repaidPaid = 0;
    
    for (var tx in transactions) {
      if (tx.personId == personId) {
        if (tx.type == 'lend') lent += tx.amount;
        else if (tx.type == 'borrow') borrowed += tx.amount;
        else if (tx.type == 'repayment_received') repaidReceived += tx.amount;
        else if (tx.type == 'repayment_paid') repaidPaid += tx.amount;
      }
    }
    
    return {
      'lent': lent,
      'borrowed': borrowed,
      'repaidReceived': repaidReceived,
      'repaidPaid': repaidPaid,
      'netBalance': (lent - repaidReceived) - (borrowed - repaidPaid),
    };
  }

  @override
  Widget build(BuildContext context) {
    final currency = Provider.of<SettingsProvider>(context).currency;
    final personProvider = Provider.of<PersonProvider>(context);
    final txProvider = Provider.of<TransactionProvider>(context);
    
    final format = NumberFormat('#,##0.00');
    final people = personProvider.people;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Borrow & Lend'),
      ),
      body: txProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : people.isEmpty
              ? const Center(child: Text('No contacts added yet', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: people.length,
                  itemBuilder: (context, index) {
                    final person = people[index];
                    final summary = _calculatePersonSummary(person.id ?? '', txProvider.transactions);
                    final netBalance = summary['netBalance'] ?? 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => PersonDetailScreen(person: person)),
                          );
                        },
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF0F766E).withOpacity(0.1),
                          child: Text(
                            person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                            style: const TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(person.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          netBalance == 0
                              ? 'Settled'
                              : netBalance > 0
                                  ? 'Owes you $currency ${format.format(netBalance)}'
                                  : 'You owe $currency ${format.format(netBalance.abs())}',
                          style: TextStyle(
                            color: netBalance == 0
                                ? Colors.grey
                                : netBalance > 0
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                      ),
                    );
                  },
                ),
    );
  }
}
