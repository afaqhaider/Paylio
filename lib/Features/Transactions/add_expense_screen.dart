import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:open_filex/open_filex.dart';

import '../Accounts/account_model.dart';
import '../Accounts/account_provider.dart';
import '../Accounts/add_account_screen.dart';
import '../../Core/settings_provider.dart';
import '../Categories/category_model.dart';
import '../Categories/category_provider.dart';
import '../Categories/add_category_screen.dart';
import '../People/person_model.dart';
import '../People/person_provider.dart';
import 'transaction_model.dart';
import 'transaction_provider.dart';

class AddExpenseScreen extends StatefulWidget {
  final TransactionModel? transaction;
  const AddExpenseScreen({super.key, this.transaction});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  DateTime selectedDate = DateTime.now();
  String selectedType = 'expense';
  String? selectedAccount;
  String? selectedToAccount;
  String? selectedCategory;
  String? selectedPersonId;
  String? attachmentPath;

  final amountController = TextEditingController();
  final noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      selectedDate = widget.transaction!.date;
      selectedType = widget.transaction!.type;
      amountController.text = widget.transaction!.amount.toStringAsFixed(2);
      selectedCategory = widget.transaction!.category;
      noteController.text = widget.transaction!.note;
      selectedAccount = widget.transaction!.account;
      selectedToAccount = widget.transaction!.toAccount;
      attachmentPath = widget.transaction!.attachmentPath;
      selectedPersonId = widget.transaction!.personId;
    } else {
      amountController.text = "0.00";
    }
  }

  Future<void> pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: const Color(0xFF0F766E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.transaction != null;
    final settings = Provider.of<SettingsProvider>(context);
    final String currency = settings.currency;
    
    final accProvider = Provider.of<AccountProvider>(context);
    final txProvider = Provider.of<TransactionProvider>(context);
    final catProvider = Provider.of<CategoryProvider>(context);
    final personProvider = Provider.of<PersonProvider>(context);

    final accounts = accProvider.accounts;
    final people = personProvider.people;
    final categories = selectedType == 'income' || selectedType == 'repayment_received' 
        ? catProvider.incomeCategories 
        : catProvider.expenseCategories;

    // Ensure initial selections if not set
    if (selectedAccount == null && accounts.isNotEmpty) {
      selectedAccount = accounts.first.name;
    }
    if (selectedToAccount == null && accounts.isNotEmpty) {
      selectedToAccount = accounts.length > 1 ? accounts[1].name : accounts.first.name;
    }
    if (selectedCategory == null && categories.isNotEmpty && !['transfer', 'borrow', 'lend', 'repayment_received', 'repayment_paid'].contains(selectedType)) {
      selectedCategory = categories.first.name;
    }

    double selectedAccountBalance = 0;
    if (selectedAccount != null) {
      // For simplicity, we can calculate balance from transactions + account opening balance
      // Or just use the account's current total if we track it.
      // Current requirement is just to show it.
      try {
        final acc = accounts.firstWhere((a) => a.name == selectedAccount);
        selectedAccountBalance = acc.openingBalance; 
        // In a real app, we'd add/subtract transactions here.
      } catch (_) {}
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Transaction' : 'New Transaction'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete'),
                    content: const Text('Delete this transaction?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true), 
                        child: const Text('Delete', style: TextStyle(color: Color(0xFFDC2626))),
                      ),
                    ],
                  ),
                );

                if (confirm == true && widget.transaction?.id != null) {
                  await txProvider.deleteTransaction(widget.transaction!.id!);
                  if (mounted) Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type Selector
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  typeButton('income', 'Income', const Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  typeButton('expense', 'Expense', const Color(0xFFEF4444)),
                  const SizedBox(width: 8),
                  typeButton('transfer', 'Transfer', const Color(0xFF7C3AED)),
                  const SizedBox(width: 8),
                  typeButton('lend', 'Lend', Colors.orange),
                  const SizedBox(width: 8),
                  typeButton('borrow', 'Borrow', Colors.brown),
                  const SizedBox(width: 8),
                  typeButton('repayment_received', 'Received', Colors.teal),
                  const SizedBox(width: 8),
                  typeButton('repayment_paid', 'Paid Back', Colors.blueGrey),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Amount Input
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                AmountInputFormatter(),
              ],
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '$currency ',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF0F766E), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Date Picker Card
            GestureDetector(
              onTap: pickDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withAlpha(25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 20, color: Color(0xFF0F766E)),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('MMMM d, yyyy').format(selectedDate),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Category Dropdown
            if (!['transfer', 'borrow', 'lend', 'repayment_received', 'repayment_paid'].contains(selectedType)) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: (selectedCategory != null && (categories.any((c) => c.name == selectedCategory) || true)) ? selectedCategory : null,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        ...categories.map((cat) => DropdownMenuItem(value: cat.name, child: Text(cat.name))),
                        if (selectedCategory != null && !categories.any((c) => c.name == selectedCategory))
                          DropdownMenuItem(value: selectedCategory, child: Text(selectedCategory!)),
                      ],
                      onChanged: (val) => setState(() => selectedCategory = val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add_rounded, color: Color(0xFF0F766E)),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AddCategoryScreen()),
                        );
                        if (result != null && result is String) {
                          // Category list updates via Provider stream
                          setState(() => selectedCategory = result);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Account Selectors
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: (selectedAccount != null && (accounts.any((a) => a.name == selectedAccount) || true)) ? selectedAccount : null,
                    decoration: InputDecoration(
                      labelText: selectedType == 'transfer' ? 'From Account' : 'Account',
                      helperText: 'Base Balance: $currency ${NumberFormat('#,##0.00').format(selectedAccountBalance)}',
                      helperStyle: const TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.bold),
                    ),
                    items: [
                      ...accounts.map((acc) => DropdownMenuItem(value: acc.name, child: Text(acc.name))),
                      if (selectedAccount != null && !accounts.any((a) => a.name == selectedAccount))
                        DropdownMenuItem(value: selectedAccount, child: Text(selectedAccount!)),
                    ],
                    onChanged: (val) => setState(() => selectedAccount = val),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 56,
                  margin: const EdgeInsets.only(bottom: 22), // Align with input field without helper text
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add_rounded, color: Color(0xFF0F766E)),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AddAccountScreen()),
                      );
                      if (result != null && result is String) {
                        setState(() => selectedAccount = result);
                      }
                    },
                  ),
                ),
              ],
            ),
            
            if (selectedType == 'transfer') ...[
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                    Expanded(
                    child: DropdownButtonFormField<String>(
                      value: (selectedToAccount != null && (accounts.any((a) => a.name == selectedToAccount) || true)) ? selectedToAccount : null,
                      decoration: const InputDecoration(labelText: 'To Account'),
                      items: [
                        ...accounts.map((acc) => DropdownMenuItem(value: acc.name, child: Text(acc.name))),
                        if (selectedToAccount != null && !accounts.any((a) => a.name == selectedToAccount))
                          DropdownMenuItem(value: selectedToAccount, child: Text(selectedToAccount!)),
                      ],
                      onChanged: (val) => setState(() => selectedToAccount = val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add_rounded, color: Color(0xFF0F766E)),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AddAccountScreen()),
                        );
                        if (result != null && result is String) {
                          setState(() => selectedToAccount = result);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),

            // Person Selector (for Borrow/Lend)
            if (['borrow', 'lend', 'repayment_received', 'repayment_paid'].contains(selectedType)) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: people.any((p) => p.id == selectedPersonId) ? selectedPersonId : null,
                      decoration: const InputDecoration(labelText: 'Person / Contact'),
                      items: people.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                      onChanged: (val) => setState(() => selectedPersonId = val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add_rounded, color: Color(0xFF0F766E)),
                      onPressed: () async {
                        final nameController = TextEditingController();
                        final result = await showDialog<String>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Add New Person'),
                            content: TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(context, nameController.text), child: const Text('Add')),
                            ],
                          ),
                        );
                        if (result != null && result.isNotEmpty) {
                          await personProvider.savePerson(PersonModel(name: result));
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Note Input
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'Note (Optional)'),
            ),
            const SizedBox(height: 24),

            // Attachment Section
            const Text('Receipt / Bill', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _attachmentSection(),
            const SizedBox(height: 40),

            // Save Button
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text.replaceAll(',', '')) ?? 0;
                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid amount')),
                  );
                  return;
                }
                if (selectedAccount == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select or create an account first')),
                  );
                  return;
                }

                final transaction = TransactionModel(
                  id: widget.transaction?.id,
                  type: selectedType,
                  category: ['transfer', 'borrow', 'lend', 'repayment_received', 'repayment_paid'].contains(selectedType) 
                      ? (selectedType[0].toUpperCase() + selectedType.substring(1).replaceAll('_', ' ')) 
                      : (selectedCategory ?? 'Uncategorized'),
                  account: selectedAccount!,
                  toAccount: selectedType == 'transfer' ? selectedToAccount : null,
                  note: noteController.text,
                  amount: amount,
                  date: selectedDate,
                  attachmentPath: attachmentPath,
                  personId: ['borrow', 'lend', 'repayment_received', 'repayment_paid'].contains(selectedType) ? selectedPersonId : null,
                );

                await txProvider.saveTransaction(transaction);
                if (mounted) Navigator.pop(context);
              },
              child: Text(isEditing ? 'Update Transaction' : 'Save Transaction'),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget typeButton(String type, String label, Color color) {
    final bool isSelected = selectedType == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedType = type;
          selectedCategory = null; // Reset category to force re-selection or default
        });
      },
      child: Container(
        width: label.length > 8 ? 128 : 96,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? color : Colors.grey.withAlpha(51)),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _attachmentSection() {
    if (attachmentPath != null && attachmentPath!.isNotEmpty) {
      final file = File(attachmentPath!);
      final isPdf = p.extension(attachmentPath!).toLowerCase() == '.pdf';

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                if (isPdf && attachmentPath != null) {
                  OpenFilex.open(attachmentPath!);
                } else if (attachmentPath != null) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ReceiptViewer(path: attachmentPath!)));
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: isPdf
                    ? Container(
                        width: 60, height: 60,
                        color: Colors.red.shade50,
                        child: const Icon(Icons.picture_as_pdf, color: Colors.red),
                      )
                    : Image.file(file, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.basename(attachmentPath!), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(isPdf ? 'PDF Document' : 'Image Receipt', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.sync_rounded, color: Color(0xFF0F766E)),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.camera_alt_outlined),
                          title: const Text('Camera'),
                          onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo_library_outlined),
                          title: const Text('Gallery'),
                          onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
                        ),
                        ListTile(
                          leading: const Icon(Icons.description_outlined),
                          title: const Text('PDF/File'),
                          onTap: () { Navigator.pop(context); _pickFile(); },
                        ),
                      ],
                    ),
                  ),
                );
              },
              tooltip: 'Replace attachment',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
              onPressed: () => setState(() => attachmentPath = null),
              tooltip: 'Remove attachment',
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        _attachmentOption(Icons.camera_alt_outlined, 'Camera', () => _pickImage(ImageSource.camera)),
        const SizedBox(width: 12),
        _attachmentOption(Icons.photo_library_outlined, 'Gallery', () => _pickImage(ImageSource.gallery)),
        const SizedBox(width: 12),
        _attachmentOption(Icons.description_outlined, 'PDF/File', _pickFile),
      ],
    );
  }

  Widget _attachmentOption(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFF0F766E)),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        _saveFileLocally(pickedFile.path);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Permission denied or error: $e')));
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']);
      if (result != null && result.files.single.path != null) {
        _saveFileLocally(result.files.single.path!);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
    }
  }

  Future<void> _saveFileLocally(String originalPath) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final extension = p.extension(originalPath);
      final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}$extension';
      final newPath = p.join(directory.path, fileName);
      final File newFile = await File(originalPath).copy(newPath);
      
      setState(() => attachmentPath = newFile.path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save attachment locally')));
    }
  }
}

class AmountInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final newText = newValue.text;

    // Handle initial zero value replacement
    if (oldValue.text == "0.00" && newText.length > oldValue.text.length) {
      final addedChar = newText.substring(newText.length - 1);
      if (RegExp(r'[0-9]').hasMatch(addedChar)) {
        return TextEditingValue(
          text: addedChar,
          selection: TextSelection.collapsed(offset: addedChar.length),
        );
      }
    }

    // Standard numeric and decimal logic
    if (newText.isEmpty) {
      return newValue.copyWith(text: "0.00", selection: const TextSelection.collapsed(offset: 4));
    }

    // Allow only digits and a single decimal point
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(newText)) {
      return oldValue;
    }

    return newValue;
  }
}

class ReceiptViewer extends StatelessWidget {
  final String path;
  const ReceiptViewer({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Receipt View', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.file(File(path), errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.white, size: 50)),
        ),
      ),
    );
  }
}
