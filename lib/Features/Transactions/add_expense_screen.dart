import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:open_filex/open_filex.dart';

import '../Accounts/account_provider.dart';
import '../Accounts/add_account_screen.dart';
import '../../Core/settings_provider.dart';
import '../Categories/category_provider.dart';
import '../Categories/add_category_screen.dart';
import '../Auth/auth_provider.dart' as ledgix_auth;
import '../People/person_model.dart';
import '../People/person_provider.dart';
import 'shared_transaction_model.dart';
import 'shared_transaction_provider.dart';
import 'transaction_model.dart';
import 'transaction_provider.dart';
import '../../shared/widgets/app_button.dart';

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
              primary: Theme.of(context).colorScheme.primary,
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
    final theme = Theme.of(context);
    
    final accProvider = Provider.of<AccountProvider>(context);
    final txProvider = Provider.of<TransactionProvider>(context);
    final catProvider = Provider.of<CategoryProvider>(context);
    final personProvider = Provider.of<PersonProvider>(context);
    final sharedProvider = Provider.of<SharedTransactionProvider>(context);
    final authProvider = Provider.of<ledgix_auth.LedGixAuthProvider>(context);

    final accounts = accProvider.accounts;
    final people = personProvider.people;
    final connections = personProvider.connections;
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
      try {
        final acc = accounts.firstWhere((a) => a.name == selectedAccount);
        selectedAccountBalance = acc.openingBalance; 
      } catch (_) {}
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Transaction' : 'New Transaction', style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
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
                        child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
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
          padding: const EdgeInsets.all(24),
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
                  typeButton('transfer', 'Transfer', const Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  typeButton('lend', 'Lend', Colors.orange),
                  const SizedBox(width: 8),
                  typeButton('borrow', 'Borrow', Colors.brown),
                  const SizedBox(width: 8),
                  typeButton('repayment_received', 'Recv Back', Colors.teal),
                  const SizedBox(width: 8),
                  typeButton('repayment_paid', 'Paid Back', Colors.blueGrey),
                  const SizedBox(width: 8),
                  typeButton('savings_transfer', 'Savings', Colors.blue),
                  const SizedBox(width: 8),
                  typeButton('liability_payment', 'Liability', Colors.red),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Amount Input
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                AmountInputFormatter(),
              ],
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: theme.colorScheme.primary),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '$currency ',
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
            ),
            const SizedBox(height: 32),

            // Date Picker Card
            GestureDetector(
              onTap: pickDate,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('MMMM d, yyyy').format(selectedDate),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Category Dropdown
            if (!['transfer', 'borrow', 'lend', 'repayment_received', 'repayment_paid'].contains(selectedType)) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: (selectedCategory != null && (categories.any((c) => c.name == selectedCategory) || true)) ? selectedCategory : null,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        ...categories.map((cat) => DropdownMenuItem(value: cat.name, child: Text(cat.name))),
                        if (selectedCategory != null && !categories.any((c) => c.name == selectedCategory))
                          DropdownMenuItem(value: selectedCategory, child: Text(selectedCategory!)),
                      ],
                      onChanged: (val) => setState(() => selectedCategory = val),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 58,
                    width: 58,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.add_rounded, color: theme.colorScheme.primary),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AddCategoryScreen()),
                        );
                        if (result != null && result is String) {
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: (selectedAccount != null && (accounts.any((a) => a.name == selectedAccount) || true)) ? selectedAccount : null,
                    decoration: InputDecoration(
                      labelText: selectedType == 'transfer' ? 'From Account' : 'Account',
                    ),
                    items: [
                      ...accounts.map((acc) => DropdownMenuItem(value: acc.name, child: Text(acc.name))),
                      if (selectedAccount != null && !accounts.any((a) => a.name == selectedAccount))
                        DropdownMenuItem(value: selectedAccount, child: Text(selectedAccount!)),
                    ],
                    onChanged: (val) => setState(() => selectedAccount = val),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 58,
                  width: 58,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.add_rounded, color: theme.colorScheme.primary),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: (selectedToAccount != null && (accounts.any((a) => a.name == selectedToAccount) || true)) ? selectedToAccount : null,
                      decoration: const InputDecoration(labelText: 'To Account'),
                      items: [
                        ...accounts.map((acc) => DropdownMenuItem(value: acc.name, child: Text(acc.name))),
                        if (selectedToAccount != null && !accounts.any((a) => a.name == selectedToAccount))
                          DropdownMenuItem(value: selectedToAccount, child: Text(selectedToAccount!)),
                      ],
                      onChanged: (val) => setState(() => selectedToAccount = val),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 58,
                    width: 58,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.add_rounded, color: theme.colorScheme.primary),
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
              Text('CONNECTED ENTITY', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: connections.any((c) => c.connectedUserId == selectedPersonId) ? selectedPersonId : null,
                decoration: const InputDecoration(labelText: 'Select Connected User'),
                items: connections.map((c) => DropdownMenuItem(value: c.connectedUserId, child: Text(c.connectedUserName))).toList(),
                onChanged: (val) => setState(() {
                  selectedPersonId = val;
                }),
              ),
              const SizedBox(height: 16),
              const Center(child: Text('-- OR --', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold))),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: people.any((p) => p.id == selectedPersonId) ? selectedPersonId : null,
                      decoration: const InputDecoration(labelText: 'Local Contact'),
                      items: people.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                      onChanged: (val) => setState(() {
                        selectedPersonId = val;
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 58,
                    width: 58,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.add_rounded, color: theme.colorScheme.primary),
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
              decoration: const InputDecoration(labelText: 'Description / Note'),
            ),
            const SizedBox(height: 32),

            // Attachment Section
            Text('ATTACHMENTS', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.4), fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 16),
            _attachmentSection(theme),
            const SizedBox(height: 48),

            // Save Button
            AppButton(
              label: isEditing ? 'Update Transaction' : 'Save Transaction',
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

                // Check if it's a shared transaction with a connected user
                final isShared = ['borrow', 'lend', 'repayment_received', 'repayment_paid'].contains(selectedType) && 
                               connections.any((c) => c.connectedUserId == selectedPersonId);

                if (isShared && authProvider.user != null) {
                  final connection = connections.firstWhere((c) => c.connectedUserId == selectedPersonId);
                  
                  String targetCurrency = 'AED'; 
                  if (connection.connectedUserName.toLowerCase().contains('hassan')) {
                    targetCurrency = 'PKR';
                  }

                  final rate = settings.rates[targetCurrency] ?? 1.0;
                  final convertedAmount = settings.convert(amount, settings.currency, targetCurrency);

                  final localTx = TransactionModel(
                    type: selectedType,
                    category: selectedType.replaceAll('_', ' ').toUpperCase(),
                    account: selectedAccount!,
                    note: noteController.text.isEmpty ? 'Shared $selectedType (Pending Approval)' : noteController.text,
                    amount: amount,
                    date: selectedDate,
                    personId: selectedPersonId,
                    status: 'pending_approval',
                    proposedAmount: amount,
                  );
                  
                  final docRef = FirebaseFirestore.instance.collection('users').doc(authProvider.user!.ledgixId).collection('transactions').doc();
                  final localTxWithId = localTx.copyWith(id: docRef.id);
                  await txProvider.saveTransaction(localTxWithId);

                  final sharedTx = SharedTransactionModel(
                    creatorUserId: authProvider.user!.ledgixId,
                    creatorDisplayName: authProvider.user!.name,
                    targetUserId: selectedPersonId!,
                    targetDisplayName: connection.connectedUserName,
                    originalAmount: amount,
                    originalCurrency: settings.currency,
                    convertedAmount: convertedAmount,
                    receiverCurrency: targetCurrency,
                    exchangeRate: rate,
                    proposedAmount: amount,
                    type: selectedType,
                    description: noteController.text.isEmpty ? 'Shared $selectedType' : noteController.text,
                    category: selectedType.replaceAll('_', ' ').toUpperCase(),
                    account: selectedAccount!,
                    createdAt: DateTime.now(),
                    status: 'pending_approval',
                    originalTransactionId: localTxWithId.id,
                  );
                  
                  await sharedProvider.createSharedTransaction(sharedTx);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Shared transaction sent for approval!')),
                    );
                    Navigator.pop(context);
                  }
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
            ),
            const SizedBox(height: 40),
          ],
          ),
        ),
      ),
    );
  }

  Widget typeButton(String type, String label, Color color) {
    final bool isSelected = selectedType == type;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedType = type;
          selectedCategory = null; 
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: label.length > 8 ? 128 : 100,
        height: 46,
        decoration: BoxDecoration(
          color: isSelected ? color : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? color : theme.colorScheme.outline, width: 1.5),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _attachmentSection(ThemeData theme) {
    if (attachmentPath != null && attachmentPath!.isNotEmpty) {
      final file = File(attachmentPath!);
      final isPdf = p.extension(attachmentPath!).toLowerCase() == '.pdf';

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outline),
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
                borderRadius: BorderRadius.circular(12),
                child: isPdf
                    ? Container(
                        width: 60, height: 60,
                        color: Colors.red.withOpacity(0.1),
                        child: const Icon(Icons.picture_as_pdf, color: Colors.red),
                      )
                    : Image.file(file, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.basename(attachmentPath!), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(isPdf ? 'PDF Document' : 'Image Receipt', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.sync_rounded, color: theme.colorScheme.primary),
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
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => setState(() => attachmentPath = null),
              tooltip: 'Remove attachment',
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        _attachmentOption(theme, Icons.camera_alt_outlined, 'Camera', () => _pickImage(ImageSource.camera)),
        const SizedBox(width: 16),
        _attachmentOption(theme, Icons.photo_library_outlined, 'Gallery', () => _pickImage(ImageSource.gallery)),
        const SizedBox(width: 16),
        _attachmentOption(theme, Icons.description_outlined, 'PDF/File', _pickFile),
      ],
    );
  }

  Widget _attachmentOption(ThemeData theme, IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Column(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
    if (oldValue.text == "0.00" && newText.length > oldValue.text.length) {
      final addedChar = newText.substring(newText.length - 1);
      if (RegExp(r'[0-9]').hasMatch(addedChar)) {
        return TextEditingValue(
          text: addedChar,
          selection: TextSelection.collapsed(offset: addedChar.length),
        );
      }
    }
    if (newText.isEmpty) {
      return newValue.copyWith(text: "0.00", selection: const TextSelection.collapsed(offset: 4));
    }
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
