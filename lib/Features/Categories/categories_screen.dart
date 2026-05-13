import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'category_model.dart';
import 'category_provider.dart';
import 'add_category_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  @override
  Widget build(BuildContext context) {
    final catProvider = Provider.of<CategoryProvider>(context);
    const primaryTeal = Color(0xFF0F766E);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Categories'),
          actions: [
            TextButton(
              onPressed: () {},
              child: const Text('Import'),
            ),
          ],
          bottom: TabBar(
            labelColor: primaryTeal,
            unselectedLabelColor: Colors.grey,
            indicatorColor: primaryTeal,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: const [
              Tab(text: 'Expense'),
              Tab(text: 'Income'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            categoryList(catProvider.expenseCategories, const Color(0xFFEF4444)),
            categoryList(catProvider.incomeCategories, const Color(0xFF10B981)),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'categoriesFab',
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddCategoryScreen()),
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget categoryList(List<CategoryModel> list, Color typeColor) {
    if (list.isEmpty) {
      return const Center(child: Text('No categories added yet', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final category = list[index];
        return Card(
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: typeColor.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                category.type == 'expense' ? Icons.remove_circle_outline : Icons.add_circle_outline,
                color: typeColor,
                size: 20,
              ),
            ),
            title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Category'),
                    content: Text('Are you sure you want to delete "${category.name}"?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true && category.id != null) {
                  final provider = Provider.of<CategoryProvider>(context, listen: false);
                  await provider.deleteCategory(category.id!);
                }
              },
            ),
          ),
        );
      },
    );
  }
}
