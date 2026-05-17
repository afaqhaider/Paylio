import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'budget_model.dart';
import 'budget_provider.dart';
import '../Categories/category_provider.dart';
import '../Categories/add_category_screen.dart';
import '../../Core/settings_provider.dart';
import '../../shared/widgets/app_button.dart';

class AddBudgetScreen extends StatefulWidget {
  final BudgetModel? budget;
  const AddBudgetScreen({super.key, this.budget});

  @override
  State<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends State<AddBudgetScreen> {
  String? selectedCategory;
  final limitController = TextEditingController();
  final notesController = TextEditingController();
  String selectedPeriod = 'Monthly';
  DateTime selectedDate = DateTime.now();

  final periods = ['Weekly', 'Monthly'];

  @override
  void initState() {
    super.initState();
    if (widget.budget != null) {
      selectedCategory = widget.budget!.category;
      limitController.text = NumberFormat("#,##0.00", "en_US").format(widget.budget!.amountLimit);
      selectedPeriod = widget.budget!.period;
      selectedDate = DateTime(widget.budget!.year, widget.budget!.month);
      notesController.text = widget.budget!.notes ?? '';
    } else {
      limitController.text = "0.00";
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.budget != null;
    final settings = Provider.of<SettingsProvider>(context);
    final String currency = settings.currency;
    final catProvider = Provider.of<CategoryProvider>(context);
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final theme = Theme.of(context);
    final categories = catProvider.expenseCategories;

    if (selectedCategory == null && categories.isNotEmpty) {
      selectedCategory = categories.first.name;
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Budget' : 'Set Budget', style: const TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BUDGET PARAMETERS',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: (selectedCategory != null && categories.any((c) => c.name == selectedCategory))
                  ? selectedCategory
                  : null,
              decoration: const InputDecoration(
                labelText: 'Category',
              ),
              items: [
                ...categories.map((cat) => DropdownMenuItem(value: cat.name, child: Text(cat.name))),
                DropdownMenuItem(
                  value: 'quick_add_category',
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('Add Category', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
              onChanged: (val) async {
                if (val == 'quick_add_category') {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddCategoryScreen(initialType: 'expense')),
                  );
                  if (result != null && result is String) {
                    setState(() => selectedCategory = result);
                  }
                } else {
                  setState(() => selectedCategory = val);
                }
              },
            ),
            const SizedBox(height: 24),
            TextField(
              controller: limitController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CurrencyInputFormatter(),
              ],
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: 'Limit Amount',
                prefixText: '$currency ',
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _quickAmountButton(limitController, '00', theme),
                const SizedBox(width: 16),
                _quickAmountButton(limitController, '000', theme),
              ],
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: selectedPeriod,
              decoration: const InputDecoration(
                labelText: 'Period',
              ),
              items: periods.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (val) => setState(() => selectedPeriod = val!),
            ),
            const SizedBox(height: 24),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  initialDatePickerMode: DatePickerMode.year,
                );
                if (date != null) {
                  setState(() => selectedDate = date);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Period Date',
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      selectedPeriod == 'Monthly'
                          ? DateFormat('MMMM yyyy').format(selectedDate)
                          : 'Week of ${DateFormat('dd MMM yyyy').format(selectedDate.subtract(Duration(days: selectedDate.weekday - 1)))}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Icon(Icons.calendar_today, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 48),
            AppButton(
              label: isEditing ? 'Update Budget' : 'Save Budget',
              onPressed: () async {
                final limit = double.tryParse(limitController.text.replaceAll(',', '')) ?? 0;
                if (selectedCategory == null || limit <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a category and enter a valid limit.'))
                  );
                  return;
                }

                final budget = BudgetModel(
                  id: widget.budget?.id,
                  category: selectedCategory!,
                  amountLimit: limit,
                  period: selectedPeriod,
                  month: selectedDate.month,
                  year: selectedDate.year,
                  notes: notesController.text.isEmpty ? null : notesController.text,
                );

                if (isEditing) {
                  await budgetProvider.saveBudget(budget);
                } else {
                  final existingList = budgetProvider.budgets.where((b) => 
                    b.category == budget.category && 
                    b.period == budget.period && 
                    b.month == budget.month && 
                    b.year == budget.year
                  ).toList();

                  if (existingList.isNotEmpty) {
                    final existing = existingList.first;
                    if (mounted) {
                      final update = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Budget Already Exists'),
                          content: Text('A budget for $selectedCategory in ${DateFormat('MMMM yyyy').format(selectedDate)} already exists. Would you like to update it instead?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Update Existing'),
                            ),
                          ],
                        ),
                      );

                      if (update == true) {
                        final updatedBudget = budget.copyWith(id: existing.id);
                        await budgetProvider.saveBudget(updatedBudget);
                      } else {
                        return;
                      }
                    }
                  } else {
                    await budgetProvider.saveBudget(budget);
                  }
                }

                if (mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _quickAmountButton(TextEditingController controller, String label, ThemeData theme) {
    return OutlinedButton(
      onPressed: () {
        String currentText = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
        if (currentText.length > 12) return;
        String newText = currentText + label;
        double value = double.tryParse(newText) ?? 0;
        final formatted = NumberFormat("#,##0.00", "en_US").format(value / 100);
        setState(() {
          controller.text = formatted;
          controller.selection = TextSelection.collapsed(offset: formatted.length);
        });
      },
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: theme.colorScheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: Text(
        '+$label',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withOpacity(0.6)),
      ),
    );
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: "0.00", selection: const TextSelection.collapsed(offset: 4));
    }

    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    double value = double.tryParse(digits) ?? 0;
    final formatter = NumberFormat("#,##0.00", "en_US");
    String newText = formatter.format(value / 100);

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
