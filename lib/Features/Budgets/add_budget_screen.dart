import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../Core/database_helper.dart';
import '../../Core/settings_provider.dart';
import '../Categories/category_model.dart';
import '../Categories/add_category_screen.dart';
import 'budget_model.dart';

class AddBudgetScreen extends StatefulWidget {
  final BudgetModel? budget;
  const AddBudgetScreen({super.key, this.budget});

  @override
  State<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends State<AddBudgetScreen> {
  String? selectedCategory;
  List<CategoryModel> categories = [];
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
    loadCategories();
  }

  Future<void> loadCategories([String? newCategoryName]) async {
    final cats = await DatabaseHelper.instance.getCategoriesByType('expense');
    
    final Map<String, CategoryModel> uniqueCats = {};
    for (var cat in cats) {
      uniqueCats[cat.name] = cat;
    }
    final deduplicatedCats = uniqueCats.values.toList();

    setState(() {
      categories = deduplicatedCats;
      if (newCategoryName != null) {
        selectedCategory = newCategoryName;
      } else if (selectedCategory != null) {
        bool exists = categories.any((c) => c.name == selectedCategory);
        if (!exists) {
          try {
            selectedCategory = categories.firstWhere(
              (c) => c.name.toLowerCase() == selectedCategory?.toLowerCase()
            ).name;
          } catch (_) {
            selectedCategory = categories.isNotEmpty ? categories.first.name : null;
          }
        }
      } else {
        selectedCategory = categories.isNotEmpty ? categories.first.name : null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.budget != null;
    final String currency = Provider.of<SettingsProvider>(context).currency;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Budget' : 'Set Budget'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: (selectedCategory != null && categories.any((c) => c.name == selectedCategory))
                  ? selectedCategory
                  : null,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: [
                ...categories.map((cat) => DropdownMenuItem(value: cat.name, child: Text(cat.name))),
                const DropdownMenuItem(
                  value: 'quick_add_category',
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF0F766E)),
                      SizedBox(width: 8),
                      Text('Add Category', style: TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.bold)),
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
                    await loadCategories(result);
                  } else {
                    await loadCategories();
                  }
                } else {
                  setState(() => selectedCategory = val);
                }
              },
            ),
            const SizedBox(height: 20),
            TextField(
              controller: limitController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CurrencyInputFormatter(),
              ],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: 'Limit Amount',
                prefixText: '$currency ',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _quickAmountButton(limitController, '00'),
                const SizedBox(width: 16),
                _quickAmountButton(limitController, '000'),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: selectedPeriod,
              decoration: const InputDecoration(
                labelText: 'Period',
                border: OutlineInputBorder(),
              ),
              items: periods.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (val) => setState(() => selectedPeriod = val!),
            ),
            const SizedBox(height: 20),
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
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(selectedPeriod == 'Monthly'
                        ? DateFormat('MMMM yyyy').format(selectedDate)
                        : 'Week of ${DateFormat('dd MMM yyyy').format(selectedDate.subtract(Duration(days: selectedDate.weekday - 1)))}'),
                    const Icon(Icons.calendar_today),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
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
                    await DatabaseHelper.instance.updateBudget(budget);
                  } else {
                    final existing = await DatabaseHelper.instance.getBudgetByCategoryPeriod(
                      budget.category,
                      budget.period,
                      budget.month,
                      budget.year,
                    );

                    if (existing != null) {
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
                          await DatabaseHelper.instance.updateBudget(updatedBudget);
                        } else {
                          return;
                        }
                      }
                    } else {
                      await DatabaseHelper.instance.insertBudget(budget);
                    }
                  }

                  if (mounted) Navigator.pop(context);
                },
                child: Text(isEditing ? 'Update Budget' : 'Save Budget', style: const TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAmountButton(TextEditingController controller, String label) {
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
        side: const BorderSide(color: Color(0xFF0F766E)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
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
