import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'goal_model.dart';
import 'goal_provider.dart';
import '../../shared/widgets/app_button.dart';

class AddGoalScreen extends StatefulWidget {
  final GoalModel? goal;
  const AddGoalScreen({super.key, this.goal});

  @override
  State<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _targetController;
  late TextEditingController _savedController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.goal?.name ?? '');
    _targetController = TextEditingController(text: widget.goal?.targetAmount.toString() ?? '');
    _savedController = TextEditingController(text: widget.goal?.savedAmount.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _savedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.goal == null ? 'Add New Goal' : 'Edit Goal'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Goal Name', hintText: 'e.g. New Car, Vacation'),
              validator: (v) => v == null || v.isEmpty ? 'Please enter a name' : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _targetController,
              decoration: const InputDecoration(labelText: 'Target Amount', prefixText: 'AED '),
              keyboardType: TextInputType.number,
              validator: (v) => double.tryParse(v ?? '') == null ? 'Please enter a valid amount' : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _savedController,
              decoration: const InputDecoration(labelText: 'Already Saved', prefixText: 'AED '),
              keyboardType: TextInputType.number,
              validator: (v) => double.tryParse(v ?? '') == null ? 'Please enter a valid amount' : null,
            ),
            const SizedBox(height: 40),
            AppButton(
              label: widget.goal == null ? 'Create Goal' : 'Update Goal',
              isLoading: _isSaving,
              onPressed: _save,
            ),
            if (widget.goal != null) ...[
              const SizedBox(height: 16),
              AppButton(
                label: 'Delete Goal',
                isOutlined: true,
                color: Colors.redAccent,
                onPressed: _delete,
              ),
            ]
          ],
        ),
      ),
    );
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    final provider = Provider.of<GoalProvider>(context, listen: false);
    
    final goal = (widget.goal ?? GoalModel(name: '', targetAmount: 0, color: '0xFF218BFF', createdAt: DateTime.now())).copyWith(
      name: _nameController.text.trim(),
      targetAmount: double.parse(_targetController.text),
      savedAmount: double.parse(_savedController.text),
    );

    try {
      await provider.saveGoal(goal);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal'),
        content: const Text('Are you sure you want to delete this goal?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true && widget.goal?.id != null) {
      await Provider.of<GoalProvider>(context, listen: false).deleteGoal(widget.goal!.id!);
      if (mounted) Navigator.pop(context);
    }
  }
}
