import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../Core/settings_provider.dart';
import '../Accounts/account_model.dart';
import '../Accounts/account_provider.dart';
import '../Categories/category_model.dart';
import '../Categories/category_provider.dart';
import '../People/person_model.dart';
import '../People/person_provider.dart';
import 'add_expense_screen.dart';
import 'import_data_screen.dart';
import 'transaction_model.dart';
import 'transaction_provider.dart';

class TransactionsScreen extends StatefulWidget {
  final String? accountFilter;
  const TransactionsScreen({super.key, this.accountFilter});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  // Filter State
  String selectedPeriod = 'This Month';
  DateTimeRange? customDateRange;
  String? filterAccount;
  String? filterType;
  String? filterCategory;
  String? filterPersonId;

  // Selection State
  Set<String> selectedIds = {};
  bool get isSelectionMode => selectedIds.isNotEmpty;

  void toggleSelection(String? id) {
    if (id == null) return;
    setState(() {
      if (selectedIds.contains(id)) {
        selectedIds.remove(id);
      } else {
        selectedIds.add(id);
      }
    });
  }

  void clearSelection() {
    setState(() {
      selectedIds.clear();
    });
  }

  Future<void> bulkDelete(TransactionProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete ${selectedIds.length} transactions?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (var id in selectedIds) {
        await provider.deleteTransaction(id);
      }
      clearSelection();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transactions deleted')));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    filterAccount = widget.accountFilter;
  }

  List<TransactionModel> getFilteredTransactions(List<TransactionModel> allTransactions) {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end;

    switch (selectedPeriod) {
      case 'Today':
        start = DateTime(now.year, now.month, now.day);
        end = start.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
        break;
      case 'This Week':
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        end = start.add(const Duration(days: 7)).subtract(const Duration(seconds: 1));
        break;
      case 'This Month':
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case 'This Year':
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
      case 'Custom':
        if (customDateRange != null) {
          start = customDateRange!.start;
          end = customDateRange!.end.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
        }
        break;
    }

    return allTransactions.where((t) {
      if (start != null && end != null) {
        if (t.date.isBefore(start) || t.date.isAfter(end)) return false;
      }
      if (filterAccount != null && t.account != filterAccount) return false;
      if (filterType != null && t.type != filterType) return false;
      if (filterCategory != null && t.category != filterCategory) return false;
      if (filterPersonId != null && t.personId != filterPersonId) return false;
      return true;
    }).toList();
  }

  Future<void> pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: customDateRange,
    );
    if (picked != null) {
      setState(() {
        customDateRange = picked;
        selectedPeriod = 'Custom';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = Provider.of<TransactionProvider>(context);
    final accProvider = Provider.of<AccountProvider>(context);
    final catProvider = Provider.of<CategoryProvider>(context);
    final personProvider = Provider.of<PersonProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final String currency = settings.currency;

    final filteredTransactions = getFilteredTransactions(txProvider.transactions);
    final isLoading = txProvider.isLoading;

    // Aggregates
    double totalIn = 0;
    double totalOut = 0;
    Map<String, List<TransactionModel>> grouped = {};

    for (var t in filteredTransactions) {
      if (['income', 'borrow', 'repayment_received'].contains(t.type)) totalIn += t.amount;
      if (['expense', 'lend', 'repayment_paid'].contains(t.type)) totalOut += t.amount;

      String dateKey = DateFormat('yyyy-MM-dd').format(t.date);
      if (!grouped.containsKey(dateKey)) grouped[dateKey] = [];
      grouped[dateKey]!.add(t);
    }

    var sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        leading: isSelectionMode 
            ? IconButton(icon: const Icon(Icons.close), onPressed: clearSelection)
            : null,
        title: isSelectionMode 
            ? Text('${selectedIds.length} Selected') 
            : const Text('Activity'),
        actions: isSelectionMode ? [
          if (selectedIds.length == 1)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final id = selectedIds.first;
                final tx = txProvider.transactions.firstWhere((t) => t.id == id);
                await Navigator.push(context, MaterialPageRoute(builder: (context) => AddExpenseScreen(transaction: tx)));
                clearSelection();
              },
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => bulkDelete(txProvider),
          ),
        ] : [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ImportDataScreen()),
              );
            },
            tooltip: 'Import Data',
          ),
        ],
      ),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!isSelectionMode) summaryCard(totalIn, totalOut, currency),
                if (!isSelectionMode) filterBar(accProvider.accounts, catProvider.expenseCategories + catProvider.incomeCategories, personProvider.people),
                Expanded(
                  child: filteredTransactions.isEmpty
                      ? const Center(child: Text('No transactions found', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: sortedDates.length,
                          itemBuilder: (context, index) {
                            String dateKey = sortedDates[index];
                            List<TransactionModel> txs = grouped[dateKey]!;
                            DateTime date = DateTime.parse(dateKey);

                            double dayIn = 0;
                            double dayOut = 0;
                            for (var t in txs) {
                              if (['income', 'borrow', 'repayment_received'].contains(t.type)) {
                                dayIn += t.amount;
                              } else if (['expense', 'lend', 'repayment_paid'].contains(t.type)) {
                                dayOut += t.amount;
                              }
                            }

                            return Column(
                              children: [
                                if (!isSelectionMode)
                                  dateHeader(date, dayIn, dayOut, currency),
                                ...txs.map((t) => transactionItem(t, currency)),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'transactionsFab',
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddExpenseScreen()));
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget summaryCard(double totalIn, double totalOut, String currency) {
    final netBalance = totalIn - totalOut;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF1F2937)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          summaryItem('Total In', totalIn, const Color(0xFF10B981), currency),
          _divider(),
          summaryItem('Total Out', totalOut, const Color(0xFFEF4444), currency),
          _divider(),
          summaryItem('Net Balance', netBalance, netBalance >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444), currency),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 40, margin: const EdgeInsets.symmetric(horizontal: 10), color: Colors.white.withAlpha(25));
  }

  Widget summaryItem(String label, double amount, Color color, String currency) {
    final format = NumberFormat('#,##0.00');
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withAlpha(153), fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${amount < 0 ? '-' : ''}$currency ${format.format(amount.abs())}',
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget filterBar(List<AccountModel> accounts, List<CategoryModel> categories, List<PersonModel> people) {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Period Filter
          filterChip(
            label: selectedPeriod == 'Custom' && customDateRange != null 
                ? '${DateFormat('MMM d').format(customDateRange!.start)} - ${DateFormat('MMM d').format(customDateRange!.end)}'
                : selectedPeriod,
            icon: Icons.calendar_today_rounded,
            onTap: () => showPeriodPicker(),
            isActive: true,
          ),
          
          // Account Filter
          filterChip(
            label: filterAccount ?? 'All Accounts',
            icon: Icons.account_balance_wallet_rounded,
            onTap: () => showAccountPicker(accounts),
            isActive: filterAccount != null,
          ),

          // Type Filter
          filterChip(
            label: filterType != null ? filterType![0].toUpperCase() + filterType!.substring(1) : 'All Types',
            icon: Icons.swap_vert_rounded,
            onTap: () => showTypePicker(),
            isActive: filterType != null,
          ),

          // Category Filter
          filterChip(
            label: filterCategory ?? 'All Categories',
            icon: Icons.category_rounded,
            onTap: () => showCategoryPicker(categories),
            isActive: filterCategory != null,
          ),

          // Person Filter
          filterChip(
            label: filterPersonId != null 
                ? (people.any((p) => p.id == filterPersonId) 
                    ? people.firstWhere((p) => p.id == filterPersonId).name 
                    : 'Unknown') 
                : 'All People',
            icon: Icons.person_rounded,
            onTap: () => showPersonPicker(people),
            isActive: filterPersonId != null,
          ),

          // Clear Filter
          if (filterAccount != null || filterType != null || filterCategory != null || filterPersonId != null || selectedPeriod != 'This Month')
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Color(0xFFDC2626)),
              onPressed: () {
                setState(() {
                  selectedPeriod = 'This Month';
                  filterAccount = null;
                  filterType = null;
                  filterCategory = null;
                  filterPersonId = null;
                  customDateRange = null;
                });
              },
            ),
        ],
      ),
    );
  }

  Widget filterChip({required String label, required IconData icon, required VoidCallback onTap, bool isActive = false}) {
    const primaryTeal = Color(0xFF0F766E);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        onPressed: onTap,
        avatar: Icon(icon, size: 14, color: isActive ? Colors.white : primaryTeal),
        label: Text(label),
        backgroundColor: isActive ? primaryTeal : Colors.white,
        labelStyle: TextStyle(
          color: isActive ? Colors.white : primaryTeal,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isActive ? primaryTeal : primaryTeal.withAlpha(25)),
        ),
      ),
    );
  }

  void showPeriodPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Today', 'This Week', 'This Month', 'This Year', 'Custom'].map((p) => ListTile(
            title: Text(p, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: selectedPeriod == p ? const Icon(Icons.check, color: Color(0xFF0F766E)) : null,
            onTap: () {
              Navigator.pop(context);
              if (p == 'Custom') {
                pickCustomRange();
              } else {
                setState(() => selectedPeriod = p);
              }
            },
          )).toList(),
        ),
      ),
    );
  }

  void showAccountPicker(List<AccountModel> accounts) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Accounts', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                setState(() => filterAccount = null);
                Navigator.pop(context);
              },
            ),
            ...accounts.map((a) => ListTile(
              title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                setState(() => filterAccount = a.name);
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  void showTypePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: const Text('All Types', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { setState(() => filterType = null); Navigator.pop(context); }),
              ListTile(title: const Text('Income', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { setState(() => filterType = 'income'); Navigator.pop(context); }),
              ListTile(title: const Text('Expense', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { setState(() => filterType = 'expense'); Navigator.pop(context); }),
              ListTile(title: const Text('Transfer', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { setState(() => filterType = 'transfer'); Navigator.pop(context); }),
              ListTile(title: const Text('Borrow', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { setState(() => filterType = 'borrow'); Navigator.pop(context); }),
              ListTile(title: const Text('Lend', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { setState(() => filterType = 'lend'); Navigator.pop(context); }),
              ListTile(title: const Text('Repayment Received', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { setState(() => filterType = 'repayment_received'); Navigator.pop(context); }),
              ListTile(title: const Text('Repayment Paid', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { setState(() => filterType = 'repayment_paid'); Navigator.pop(context); }),
            ],
          ),
        ),
      ),
    );
  }

  void showPersonPicker(List<PersonModel> people) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: const Text('All People', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { setState(() => filterPersonId = null); Navigator.pop(context); }),
              ...people.map((p) => ListTile(
                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () { setState(() => filterPersonId = p.id); Navigator.pop(context); },
              )),
            ],
          ),
        ),
      ),
    );
  }

  void showCategoryPicker(List<CategoryModel> categories) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: const Text('All Categories', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { setState(() => filterCategory = null); Navigator.pop(context); }),
              ...categories.map((c) => ListTile(
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () { setState(() => filterCategory = c.name); Navigator.pop(context); },
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget dateHeader(DateTime date, double income, double expense, String currency) {
    final format = NumberFormat('#,##0.00');
    final net = income - expense;
    final isToday = DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isToday ? 'Today' : DateFormat('EEEE, d MMMM').format(date),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF111827)),
              ),
              Text(
                '${net >= 0 ? '+' : '-'}$currency ${format.format(net.abs())}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: net >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (income > 0) ...[
                Text('In: $currency ${format.format(income)}', style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
              ],
              if (expense > 0)
                Text('Out: $currency ${format.format(expense)}', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          const Divider(height: 20, thickness: 1),
        ],
      ),
    );
  }

  Widget transactionItem(TransactionModel t, String currency) {
    final isIncome = ['income', 'borrow', 'repayment_received'].contains(t.type);
    final color = t.type == 'income' || t.type == 'repayment_received' ? const Color(0xFF10B981) : 
                  t.type == 'expense' || t.type == 'repayment_paid' ? const Color(0xFFEF4444) : 
                  t.type == 'lend' ? Colors.orange :
                  t.type == 'borrow' ? Colors.brown :
                  const Color(0xFF7C3AED);

    final isSelected = selectedIds.contains(t.id);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: isSelected ? 4 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? const Color(0xFF0F766E) : Colors.transparent, width: 2),
      ),
      child: ListTile(
        onTap: () async {
          if (isSelectionMode) {
            toggleSelection(t.id);
          } else {
            await Navigator.push(context, MaterialPageRoute(builder: (context) => AddExpenseScreen(transaction: t)));
          }
        },
        onLongPress: () => toggleSelection(t.id),
        leading: isSelectionMode 
            ? Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: isSelected ? const Color(0xFF0F766E) : Colors.grey)
            : Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                child: Icon(isIncome ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: color, size: 18),
              ),
        title: Row(
          children: [
            Expanded(child: Text(t.category, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
            if (t.attachmentPath != null && t.attachmentPath!.isNotEmpty)
              const Icon(Icons.attachment_rounded, size: 14, color: Colors.grey),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.account, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
            if (isSelectionMode) Text(DateFormat('dd MMM yyyy').format(t.date), style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        trailing: Text(
          '${isIncome ? '+' : '-'} $currency ${NumberFormat('#,##0.00').format(t.amount)}',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color),
        ),
      ),
    );
  }
}
