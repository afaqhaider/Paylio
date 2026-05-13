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
import '../Accounts/add_account_screen.dart';
import '../../Core/database_helper.dart';
import '../../Core/settings_provider.dart';
import '../Categories/category_model.dart';
import '../Categories/add_category_screen.dart';
import '../People/person_model.dart';
import 'transaction_model.dart';

class AddExpenseScreen extends StatefulWidget {
  final TransactionModel? transaction;
  const AddExpenseScreen({super.key, this.transaction});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  DateTime selectedDate = DateTime.now();
  String selectedType = 'expense';
  List<AccountModel> accounts = [];
  List<CategoryModel> categories = [];
  List<PersonModel> people = [];
  String? selectedAccount;
  String? selectedToAccount;
  String? selectedCategory;
  int? selectedPersonId;
  double selectedAccountBalance = 0;
  String? attachmentPath;

  final amountController = TextEditingController();
  final noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      selectedDate = widget.transaction!.date;
      selectedType = widget.transaction!.type;
      // Format existing amount to POS style with commas
      amountController.text = NumberFormat("#,##0.00", "en_US").format(widget.transaction!.amount);
      selectedCategory = widget.transaction!.category;
      noteController.text = widget.transaction!.note;
      selectedAccount = widget.transaction!.account;
      selectedToAccount = widget.transaction!.toAccount;
      attachmentPath = widget.transaction!.attachmentPath;
      selectedPersonId = widget.transaction!.personId;
    } else {
      amountController.text = "0.00";
    }
    loadData();
  }

  Future<void> loadData() async {
    final accs = await DatabaseHelper.instance.getAccounts();
    final allPeople = await DatabaseHelper.instance.getPeople();
    await loadCategories();
    
    setState(() {
      accounts = accs;
      people = allPeople;
      if (accounts.isNotEmpty) {
        if (selectedAccount == null) {
          selectedAccount = accounts.first.name;
        }
        if (selectedToAccount == null) {
          selectedToAccount = accounts.length > 1 ? accounts[1].name : accounts.first.name;
        }
        loadSelectedAccountBalance();
      }
    });
  }

  Future<void> loadCategories([String? newCategoryName]) async {
    if (selectedType == 'transfer') {
      setState(() {
        categories = [];
        selectedCategory = 'Transfer';
      });
      return;
    }
    
    if (['borrow', 'lend', 'repayment_received', 'repayment_paid'].contains(selectedType)) {
      setState(() {
        categories = [];
        selectedCategory = selectedType[0].toUpperCase() + selectedType.substring(1).replaceAll('_', ' ');
      });
      return;
    }

    final cats = await DatabaseHelper.instance.getCategoriesByType(selectedType == 'income' || selectedType == 'repayment_received' ? 'income' : 'expense');
    
    // De-duplicate categories by name to prevent dropdown crashes
    final Map<String, CategoryModel> uniqueCats = {};
    for (var cat in cats) {
      uniqueCats[cat.name] = cat;
    }
    final deduplicatedCats = uniqueCats.values.toList();

    setState(() {
      categories = deduplicatedCats;
      if (newCategoryName != null) {
        selectedCategory = newCategoryName;
      } else if (categories.isNotEmpty) {
        // Ensure selectedCategory exists in the deduplicated list
        bool exists = categories.any((c) => c.name == selectedCategory);
        if (!exists) {
          // Try case-insensitive fallback for "fuel" vs "Fuel"
          try {
            selectedCategory = categories.firstWhere(
              (c) => c.name.toLowerCase() == selectedCategory?.toLowerCase()
            ).name;
          } catch (_) {
            selectedCategory = categories.first.name;
          }
        }
      } else {
        selectedCategory = null;
      }
    });
  }

  Future<void> loadSelectedAccountBalance() async {
    if (selectedAccount == null) return;
    final balance = await DatabaseHelper.instance.getAccountBalance(selectedAccount!);
    setState(() {
      selectedAccountBalance = balance;
    });
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
    final String currency = Provider.of<SettingsProvider>(context).currency;

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

                if (confirm == true) {
                  final id = widget.transaction?.id;
                  if (id == null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cannot delete: transaction ID is missing')),
                      );
                    }
                    return;
                  }
                  await DatabaseHelper.instance.deleteTransaction(id);
                  if (mounted) Navigator.pop(context, true);
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
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CurrencyInputFormatter(),
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
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _quickAmountButton('00'),
                const SizedBox(width: 16),
                _quickAmountButton('000'),
              ],
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
                  border: Border.all(color: Colors.grey.withOpacity(0.1)),
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
              DropdownButtonFormField<String>(
                value: (selectedCategory != null && categories.any((c) => c.name == selectedCategory)) 
                    ? selectedCategory 
                    : (categories.isNotEmpty ? categories.first.name : null),
                decoration: const InputDecoration(labelText: 'Category'),
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
                      MaterialPageRoute(builder: (context) => const AddCategoryScreen()),
                    );
                    // AddCategoryScreen should return the name of the new category
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
              const SizedBox(height: 24),
            ],

            // Account Selectors
            DropdownButtonFormField<String>(
              value: (selectedAccount != null && accounts.any((a) => a.name == selectedAccount))
                  ? selectedAccount
                  : (accounts.isNotEmpty ? accounts.first.name : null),
              decoration: InputDecoration(
                labelText: selectedType == 'transfer' ? 'From Account' : 'Account',
                helperText: 'Balance: $currency ${NumberFormat('#,##0.00').format(selectedAccountBalance)}',
                helperStyle: const TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.bold),
              ),
              items: [
                ...accounts.map((acc) => DropdownMenuItem(value: acc.name, child: Text(acc.name))),
                const DropdownMenuItem(
                  value: 'quick_add_account',
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF0F766E)),
                      SizedBox(width: 8),
                      Text('Add Account', style: TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
              onChanged: (val) async {
                if (val == 'quick_add_account') {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddAccountScreen()),
                  );
                  // AddAccountScreen should return the name of the new account
                  if (result != null && result is String) {
                    final accs = await DatabaseHelper.instance.getAccounts();
                    setState(() {
                      accounts = accs;
                      selectedAccount = result;
                    });
                    loadSelectedAccountBalance();
                  } else {
                    final accs = await DatabaseHelper.instance.getAccounts();
                    setState(() => accounts = accs);
                  }
                } else {
                  setState(() => selectedAccount = val);
                  loadSelectedAccountBalance();
                }
              },
            ),
            
            if (selectedType == 'transfer') ...[
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: (selectedToAccount != null && accounts.any((a) => a.name == selectedToAccount))
                    ? selectedToAccount
                    : (accounts.length > 1 ? accounts[1].name : (accounts.isNotEmpty ? accounts.first.name : null)),
                decoration: const InputDecoration(labelText: 'To Account'),
                items: [
                  ...accounts.map((acc) => DropdownMenuItem(value: acc.name, child: Text(acc.name))),
                  const DropdownMenuItem(
                    value: 'quick_add_account',
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF0F766E)),
                        SizedBox(width: 8),
                        Text('Add Account', style: TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
                onChanged: (val) async {
                  if (val == 'quick_add_account') {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddAccountScreen()),
                    );
                    if (result != null && result is String) {
                      final accs = await DatabaseHelper.instance.getAccounts();
                      setState(() {
                        accounts = accs;
                        selectedToAccount = result;
                      });
                    } else {
                      final accs = await DatabaseHelper.instance.getAccounts();
                      setState(() => accounts = accs);
                    }
                  } else {
                    setState(() => selectedToAccount = val);
                  }
                },
              ),
            ],
            const SizedBox(height: 24),

            // Person Selector (for Borrow/Lend)
            if (['borrow', 'lend', 'repayment_received', 'repayment_paid'].contains(selectedType)) ...[
              DropdownButtonFormField<int>(
                value: (selectedPersonId != null && people.any((p) => p.id == selectedPersonId))
                    ? selectedPersonId
                    : null,
                decoration: const InputDecoration(labelText: 'Person / Contact'),
                items: [
                  ...people.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                  const DropdownMenuItem(
                    value: -1,
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF0F766E)),
                        SizedBox(width: 8),
                        Text('Add New Person', style: TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
                onChanged: (val) async {
                  if (val == -1) {
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
                      final id = await DatabaseHelper.instance.insertPerson(PersonModel(name: result));
                      final allPeople = await DatabaseHelper.instance.getPeople();
                      setState(() {
                        people = allPeople;
                        selectedPersonId = id;
                      });
                    }
                  } else {
                    setState(() => selectedPersonId = val);
                  }
                },
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
                if (isEditing && widget.transaction?.id == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cannot update: transaction ID is missing')),
                  );
                  return;
                }

                // Credit Card Limit Check
                final accountObj = accounts.firstWhere((a) => a.name == selectedAccount);
                if (accountObj.type == 'Credit Card' && (selectedType == 'expense' || selectedType == 'lend' || selectedType == 'repayment_paid' || selectedType == 'transfer')) {
                  final limit = accountObj.creditLimit ?? 0;
                  final used = await DatabaseHelper.instance.getAccountBalance(selectedAccount!);
                  
                  // Calculate potential new used amount (if editing, subtract old amount first)
                  double oldAmount = isEditing ? widget.transaction!.amount : 0;
                  if (used - oldAmount + amount > limit) {
                    final proceed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Limit Exceeded'),
                        content: Text('This transaction will exceed your credit card limit of $currency ${NumberFormat('#,##0').format(limit)}. Do you still want to save?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save Anyway')),
                        ],
                      ),
                    );
                    if (proceed != true || !mounted) return;
                  }
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

                if (isEditing) {
                  await DatabaseHelper.instance.updateTransaction(transaction);
                } else {
                  // Simplified insertion: handle transfer as one record or maintain previous logic
                  // Re-evaluating: Requirement says "Transfers excluded from income/expense totals".
                  // If we use the unified 'transfer' type in getAccountBalance, we should insert only ONE record.
                  await DatabaseHelper.instance.insertTransaction(transaction);
                }
                if (mounted) Navigator.pop(context, true);
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

    // IMPORTANT:
    // This button is used inside a horizontal SingleChildScrollView.
    // Do not wrap it with Expanded/Flexible here, because horizontal scroll views
    // provide unbounded width and Flutter will throw RenderBox was not laid out.
    return GestureDetector(
      onTap: () {
        setState(() => selectedType = type);
        loadCategories();
      },
      child: Container(
        width: label.length > 8 ? 128 : 96,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? color : Colors.grey.withOpacity(0.2)),
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

  Widget _quickAmountButton(String label) {
    return OutlinedButton(
      onPressed: () {
        String currentText = amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
        if (currentText.length > 12) return;
        String newText = currentText + label;
        double value = double.tryParse(newText) ?? 0;
        final formatted = NumberFormat("#,##0.00", "en_US").format(value / 100);
        setState(() {
          amountController.text = formatted;
          amountController.selection = TextSelection.collapsed(offset: formatted.length);
        });
      },
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFF0F766E)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
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
      
      // Future: Trigger OCR scan here
      // _processReceiptWithAI(newFile.path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save attachment locally')));
    }
  }

  // Placeholder for future AI/OCR integration
  Future<void> _processReceiptWithAI(String path) async {
    // 1. Send path to OCR service
    // 2. Extract amount, date, category
    // 3. Update controllers with extracted data
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
