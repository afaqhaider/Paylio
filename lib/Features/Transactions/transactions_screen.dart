import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../Core/database_helper.dart';
import '../../Core/settings_provider.dart';
import '../Accounts/account_model.dart';
import '../Categories/category_model.dart';
import '../People/person_model.dart';
import 'add_expense_screen.dart';
import 'transaction_model.dart';

class TransactionsScreen extends StatefulWidget {
  final String? accountFilter;
  const TransactionsScreen({super.key, this.accountFilter});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<TransactionModel> allTransactions = [];
  List<TransactionModel> filteredTransactions = [];
  
  List<AccountModel> accounts = [];
  List<CategoryModel> categories = [];
  List<PersonModel> people = [];

  // Filter State
  String selectedPeriod = 'This Month';
  DateTimeRange? customDateRange;
  String? filterAccount;
  String? filterType;
  String? filterCategory;
  int? filterPersonId;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    filterAccount = widget.accountFilter;
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    setState(() => isLoading = true);
    try {
      final accs = await DatabaseHelper.instance.getAccounts();
      final cats = await DatabaseHelper.instance.getCategories();
      final allPeople = await DatabaseHelper.instance.getPeople();
      final txs = await DatabaseHelper.instance.getTransactions();
      
      setState(() {
        accounts = accs;
        categories = cats;
        people = allPeople;
        allTransactions = txs;
        applyFilters();
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading transactions: $e");
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading data: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void applyFilters() {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end;

    // 1. Time Period Logic
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

    setState(() {
      filteredTransactions = allTransactions.where((t) {
        // Date check
        if (start != null && end != null) {
          if (t.date.isBefore(start) || t.date.isAfter(end)) return false;
        }

        // Account check
        if (filterAccount != null && t.account != filterAccount) return false;

        // Type check
        if (filterType != null && t.type != filterType) return false;

        // Category check
        if (filterCategory != null && t.category != filterCategory) return false;

        // Person check
        if (filterPersonId != null && t.personId != filterPersonId) return false;

        return true;
      }).toList();
    });
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
      applyFilters();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currency = Provider.of<SettingsProvider>(context).currency;

    // Aggregates
    double totalIncome = 0;
    double totalExpense = 0;
    Map<String, List<TransactionModel>> grouped = {};

    for (var t in filteredTransactions) {
      if (t.type == 'income') totalIncome += t.amount;
      if (t.type == 'expense') totalExpense += t.amount;

      String dateKey = DateFormat('yyyy-MM-dd').format(t.date);
      if (!grouped.containsKey(dateKey)) grouped[dateKey] = [];
      grouped[dateKey]!.add(t);
    }

    var sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: loadInitialData,
          ),
        ],
      ),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                summaryCard(totalIncome, totalExpense, currency),
                filterBar(),
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
                              if (t.type == 'income') dayIn += t.amount;
                              else if (t.type == 'expense') dayOut += t.amount;
                            }

                            return Column(
                              children: [
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
          loadInitialData();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget summaryCard(double income, double expense, String currency) {
    final format = NumberFormat('#,##0.00');
    // For summary, let's include borrow/repayment received in income and lend/repayment paid in expense
    double totalIn = 0;
    double totalOut = 0;
    for (var t in filteredTransactions) {
      if (['income', 'borrow', 'repayment_received'].contains(t.type)) totalIn += t.amount;
      if (['expense', 'lend', 'repayment_paid'].contains(t.type)) totalOut += t.amount;
    }
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
    return Container(width: 1, height: 40, margin: const EdgeInsets.symmetric(horizontal: 10), color: Colors.white.withOpacity(0.1));
  }

  Widget summaryItem(String label, double amount, Color color, String currency) {
    final format = NumberFormat('#,##0.00');
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.w500)),
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

  Widget filterBar() {
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
            onTap: () => showAccountPicker(),
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
            onTap: () => showCategoryPicker(),
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
            onTap: () => showPersonPicker(),
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
                applyFilters();
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
          side: BorderSide(color: isActive ? primaryTeal : primaryTeal.withOpacity(0.1)),
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
                applyFilters();
              }
            },
          )).toList(),
        ),
      ),
    );
  }

  void showAccountPicker() {
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
                applyFilters();
                Navigator.pop(context);
              },
            ),
            ...accounts.map((a) => ListTile(
              title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                setState(() => filterAccount = a.name);
                applyFilters();
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
              ListTile(title: const Text('All Types', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { setState(() => filterType = null); applyFilters(); Navigator.pop(context); }),
              ListTile(title: const Text('Income', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { setState(() => filterType = 'income'); applyFilters(); Navigator.pop(context); }),
              ListTile(title: const Text('Expense', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { setState(() => filterType = 'expense'); applyFilters(); Navigator.pop(context); }),
              ListTile(title: const Text('Transfer', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { setState(() => filterType = 'transfer'); applyFilters(); Navigator.pop(context); }),
              ListTile(title: const Text('Borrow', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { setState(() => filterType = 'borrow'); applyFilters(); Navigator.pop(context); }),
              ListTile(title: const Text('Lend', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { setState(() => filterType = 'lend'); applyFilters(); Navigator.pop(context); }),
              ListTile(title: const Text('Repayment Received', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { setState(() => filterType = 'repayment_received'); applyFilters(); Navigator.pop(context); }),
              ListTile(title: const Text('Repayment Paid', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { setState(() => filterType = 'repayment_paid'); applyFilters(); Navigator.pop(context); }),
            ],
          ),
        ),
      ),
    );
  }

  void showPersonPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: const Text('All People', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { setState(() => filterPersonId = null); applyFilters(); Navigator.pop(context); }),
              ...people.map((p) => ListTile(
                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () { setState(() => filterPersonId = p.id); applyFilters(); Navigator.pop(context); },
              )),
            ],
          ),
        ),
      ),
    );
  }

  void showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: const Text('All Categories', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { setState(() => filterCategory = null); applyFilters(); Navigator.pop(context); }),
              ...categories.map((c) => ListTile(
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () { setState(() => filterCategory = c.name); applyFilters(); Navigator.pop(context); },
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
    final isExpense = ['expense', 'lend', 'repayment_paid'].contains(t.type);
    final color = t.type == 'income' || t.type == 'repayment_received' ? const Color(0xFF10B981) : 
                  t.type == 'expense' || t.type == 'repayment_paid' ? const Color(0xFFEF4444) : 
                  t.type == 'lend' ? Colors.orange :
                  t.type == 'borrow' ? Colors.brown :
                  const Color(0xFF7C3AED);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => AddExpenseScreen(transaction: t)));
          loadInitialData();
        },
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
          child: Icon(isIncome ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: color, size: 18),
        ),
        title: Row(
          children: [
            Expanded(child: Text(t.category, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
            if (t.attachmentPath != null && t.attachmentPath!.isNotEmpty)
              const Icon(Icons.attachment_rounded, size: 14, color: Colors.grey),
          ],
        ),
        subtitle: Text(t.account, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
        trailing: Text(
          '${isIncome ? '+' : '-'} $currency ${NumberFormat('#,##0.00').format(t.amount)}',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color),
        ),
      ),
    );
  }
}
