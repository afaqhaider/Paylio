import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../Core/database_helper.dart';
import '../../Core/settings_provider.dart';
import 'person_model.dart';
import 'person_detail_screen.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  List<PersonModel> people = [];
  Map<int, Map<String, double>> summaries = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadPeople();
  }

  Future<void> loadPeople() async {
    setState(() => isLoading = true);
    try {
      final allPeople = await DatabaseHelper.instance.getPeople();
      Map<int, Map<String, double>> tempSummaries = {};
      for (var p in allPeople) {
        tempSummaries[p.id!] = await DatabaseHelper.instance.getPersonSummary(p.id!);
      }
      setState(() {
        people = allPeople;
        summaries = tempSummaries;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading people: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = Provider.of<SettingsProvider>(context).currency;
    final format = NumberFormat('#,##0.00');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Borrow & Lend'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : people.isEmpty
              ? const Center(child: Text('No contacts added yet', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: people.length,
                  itemBuilder: (context, index) {
                    final person = people[index];
                    final summary = summaries[person.id] ?? {};
                    final netBalance = summary['netBalance'] ?? 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => PersonDetailScreen(person: person)),
                          );
                          loadPeople();
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
