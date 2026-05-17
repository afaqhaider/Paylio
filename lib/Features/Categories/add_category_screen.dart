import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'category_model.dart';
import 'category_provider.dart';
import '../../shared/widgets/app_button.dart';

class AddCategoryScreen extends StatefulWidget {
  final String? initialType;
  const AddCategoryScreen({super.key, this.initialType});

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  final nameController = TextEditingController();
  late String selectedType;

  @override
  void initState() {
    super.initState();
    selectedType = widget.initialType ?? 'expense';
  }

  @override
  Widget build(BuildContext context) {
    final catProvider = Provider.of<CategoryProvider>(context, listen: false);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CATEGORY DETAILS',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: nameController,
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'Category Name',
                hintText: 'e.g. Groceries, Freelance',
              ),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: selectedType,
              decoration: const InputDecoration(
                labelText: 'Category Type',
              ),
              items: const [
                DropdownMenuItem(value: 'expense', child: Text('Expense')),
                DropdownMenuItem(value: 'income', child: Text('Income')),
              ],
              onChanged: (val) => setState(() => selectedType = val!),
            ),
            const SizedBox(height: 48),
            AppButton(
              label: 'Save Category',
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a category name')),
                  );
                  return;
                }

                final category = CategoryModel(
                  name: nameController.text.trim(),
                  type: selectedType,
                );

                await catProvider.saveCategory(category);
                if (mounted) Navigator.pop(context, category.name);
              },
            ),
          ],
        ),
      ),
    );
  }
}
