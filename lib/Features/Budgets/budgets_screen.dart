import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../Core/database_helper.dart';
import '../../Core/settings_provider.dart';
import 'budget_model.dart';
import 'add_budget_screen.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  List<BudgetModel> budgets = [];
  Map<int, double> spendingMap = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadBudgets();
  }

  Future<void> loadBudgets() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    final data = await DatabaseHelper.instance.getBudgets();
    
    Map<int, double> tempSpending = {};
    
    for (var budget in data) {
      DateTime start;
      DateTime end;
      if (budget.period == 'Weekly') {
        DateTime budgetDate = DateTime(budget.year, budget.month);
        start = budgetDate.subtract(Duration(days: budgetDate.weekday - 1));
        end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      } else {
        start = DateTime(budget.year, budget.month, 1);
        end = DateTime(budget.year, budget.month + 1, 0, 23, 59, 59);
      }
      final spent = await DatabaseHelper.instance.getCategorySpending(
        budget.category,
        start,
        end,
      );
      tempSpending[budget.id!] = spent;
    }

    if (!mounted) return;
    setState(() {
      budgets = data;
      spendingMap = tempSpending;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0.00');
    final String currency = Provider.of<SettingsProvider>(context).currency;
    const primaryTeal = Color(0xFF0F766E);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
      ),
      body: RefreshIndicator(
        onRefresh: loadBudgets,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : budgets.isEmpty
                ? const Center(child: Text('No budgets set yet', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: budgets.length,
                    itemBuilder: (context, index) {
                      final budget = budgets[index];
                      final spent = spendingMap[budget.id] ?? 0;
                      final percent = budget.amountLimit > 0 ? (spent / budget.amountLimit).clamp(0.0, 1.1) : 0.0;
                      final remaining = budget.amountLimit - spent;
                      
                      Color statusColor = primaryTeal;
                      String statusText = "Safe";
                      
                      if (percent >= 1.0) {
                        statusColor = const Color(0xFFDC2626);
                        statusText = "Exceeded";
                      } else if (percent >= 0.7) {
                        statusColor = Colors.orange;
                        statusText = "Warning";
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (context) => AddBudgetScreen(budget: budget)));
                            loadBudgets();
                          },
                          onLongPress: () async {
                            showModalBottomSheet(
                              context: context,
                              builder: (context) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.edit_outlined),
                                      title: const Text('Edit Budget'),
                                      onTap: () async {
                                        Navigator.pop(context);
                                        await Navigator.push(context, MaterialPageRoute(builder: (context) => AddBudgetScreen(budget: budget)));
                                        loadBudgets();
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                                      title: const Text('Delete Budget', style: TextStyle(color: Color(0xFFDC2626))),
                                      onTap: () async {
                                        Navigator.pop(context);
                                        await DatabaseHelper.instance.deleteBudget(budget.id!);
                                        loadBudgets();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(budget.category, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                          Text(
                                            budget.period == 'Monthly'
                                                ? DateFormat('MMMM yyyy').format(DateTime(budget.year, budget.month))
                                                : 'Week of ${DateFormat('dd MMM yyyy').format(DateTime(budget.year, budget.month).subtract(Duration(days: DateTime(budget.year, budget.month).weekday - 1)))}',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        statusText,
                                        style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    budgetMetric('Budget', '$currency ${currencyFormat.format(budget.amountLimit)}'),
                                    budgetMetric('Spent', '$currency ${currencyFormat.format(spent)}'),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    budgetMetric('Remaining', '$currency ${currencyFormat.format(remaining < 0 ? 0 : remaining)}'),
                                    budgetMetric('Used', '${(percent * 100).toStringAsFixed(0)}%'),
                                  ],
                                ),
                                if (budget.notes != null && budget.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    budget.notes!,
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: percent > 1.0 ? 1.0 : percent,
                                    backgroundColor: Colors.grey[100],
                                    color: statusColor,
                                    minHeight: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'budgetsFab',
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddBudgetScreen()));
          loadBudgets();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget budgetMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}
