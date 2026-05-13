import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Transactions/transaction_model.dart';
import '../Transactions/transaction_provider.dart';
import '../Accounts/account_provider.dart';
import '../Accounts/account_model.dart';
import '../Categories/category_model.dart';
import '../../Core/database_helper.dart';

class ImportCsvScreen extends StatefulWidget {
  const ImportCsvScreen({super.key});

  @override
  State<ImportCsvScreen> createState() => _ImportCsvScreenState();
}

class _ImportCsvScreenState extends State<ImportCsvScreen> {
  File? _selectedFile;
  List<List<dynamic>> _csvData = [];
  List<TransactionModel> _previewTransactions = [];
  Set<int> _duplicateIndices = {};
  AccountModel? _targetAccount;
  bool _isParsing = false;
  bool _isImporting = false;

  final Map<String, String> _categoryKeywords = {
    'ADNOC': 'Transportation',
    'ENOC': 'Transportation',
    'EMARAT': 'Transportation',
    'TALABAT': 'Food & Drinks',
    'ZOMATO': 'Food & Drinks',
    'SALARY': 'Salary',
    'WPS': 'Salary',
    'NETFLIX': 'Entertainment',
    'SPOTIFY': 'Entertainment',
    'AMAZON': 'Shopping',
    'NOON': 'Shopping',
    'CARREFOUR': 'Food & Drinks',
    'LULU': 'Food & Drinks',
    'METRO': 'Transportation',
    'UBER': 'Transportation',
    'CAREEM': 'Transportation',
  };

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _csvData = [];
        _previewTransactions = [];
      });
      _parseCsv();
    }
  }

  Future<void> _parseCsv() async {
    if (_selectedFile == null) return;

    setState(() => _isParsing = true);

    try {
      final input = _selectedFile!.openRead();
      final fields = await input
          .transform(utf8.decoder)
          .transform(const CsvToListConverter())
          .toList();

      if (fields.isEmpty) {
        throw Exception('CSV file is empty');
      }

      setState(() {
        _csvData = fields;
        _generatePreview();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error parsing CSV: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isParsing = false);
    }
  }

  void _generatePreview() {
    if (_csvData.length < 2) return; // Need header + at least one row

    final header = _csvData[0].map((e) => e.toString().toLowerCase()).toList();
    
    // Detect column indices
    int dateIdx = header.indexWhere((h) => h.contains('date'));
    int descIdx = header.indexWhere((h) => h.contains('desc') || h.contains('narrat') || h.contains('particular'));
    int debitIdx = header.indexWhere((h) => h.contains('debit') || h.contains('withdraw'));
    int creditIdx = header.indexWhere((h) => h.contains('credit') || h.contains('deposit'));
    int amountIdx = header.indexWhere((h) => h.contains('amount'));
    int refIdx = header.indexWhere((h) => h.contains('ref') || h.contains('cheque') || h.contains('txn id'));

    List<TransactionModel> tempTxs = [];
    Set<int> duplicates = {};
    final existingTxs = Provider.of<TransactionProvider>(context, listen: false).transactions;

    for (int i = 1; i < _csvData.length; i++) {
      final row = _csvData[i];
      if (row.isEmpty) continue;

      try {
        String dateStr = (dateIdx != -1 && dateIdx < row.length) ? row[dateIdx].toString() : '';
        DateTime date = _parseDate(dateStr);

        String description = (descIdx != -1 && descIdx < row.length) ? row[descIdx].toString() : 'Imported Transaction';
        String ref = (refIdx != -1 && refIdx < row.length) ? row[refIdx].toString() : '';
        
        double debit = 0;
        double credit = 0;
        double amount = 0;

        if (debitIdx != -1 && debitIdx < row.length && row[debitIdx] != null && row[debitIdx].toString().isNotEmpty) {
          debit = _parseAmount(row[debitIdx].toString());
        }
        if (creditIdx != -1 && creditIdx < row.length && row[creditIdx] != null && row[creditIdx].toString().isNotEmpty) {
          credit = _parseAmount(row[creditIdx].toString());
        }
        if (amountIdx != -1 && amountIdx < row.length && row[amountIdx] != null && row[amountIdx].toString().isNotEmpty) {
          amount = _parseAmount(row[amountIdx].toString());
        }

        String type = 'expense';
        double finalAmount = 0;

        if (debit > 0) {
          type = 'expense';
          finalAmount = debit;
        } else if (credit > 0) {
          type = 'income';
          finalAmount = credit;
        } else if (amount != 0) {
          type = amount < 0 ? 'expense' : 'income';
          finalAmount = amount.abs();
        } else {
          continue;
        }

        String category = _suggestCategory(description);
        String note = description + (ref.isNotEmpty ? ' (Ref: $ref)' : '');

        // Check for duplicates
        bool isDuplicate = existingTxs.any((e) =>
          e.date.year == date.year &&
          e.date.month == date.month &&
          e.date.day == date.day &&
          e.amount == finalAmount &&
          e.note == note &&
          (_targetAccount == null || e.account == _targetAccount!.name));

        if (isDuplicate) {
          duplicates.add(tempTxs.length);
        }

        tempTxs.add(TransactionModel(
          type: type,
          category: category,
          account: _targetAccount?.name ?? 'Unknown',
          note: note,
          amount: finalAmount,
          date: date,
        ));
      } catch (e) {
        debugPrint('Error parsing row $i: $e');
      }
    }

    setState(() {
      _previewTransactions = tempTxs;
      _duplicateIndices = duplicates;
    });
  }

  DateTime _parseDate(String dateStr) {
    if (dateStr.isEmpty) return DateTime.now();
    
    // Try common formats
    List<String> formats = [
      'dd/MM/yyyy',
      'dd-MM-yyyy',
      'yyyy-MM-dd',
      'MM/dd/yyyy',
      'dd MMM yyyy',
    ];

    for (var format in formats) {
      try {
        return DateFormat(format).parse(dateStr);
      } catch (_) {}
    }

    try {
      return DateTime.parse(dateStr);
    } catch (_) {}

    return DateTime.now();
  }

  double _parseAmount(String amountStr) {
    String clean = amountStr.replaceAll(',', '').replaceAll(' ', '').trim();
    if (clean.startsWith('(') && clean.endsWith(')')) {
      clean = '-' + clean.substring(1, clean.length - 1);
    }
    return double.tryParse(clean) ?? 0;
  }

  String _suggestCategory(String description) {
    final descUpper = description.toUpperCase();
    for (var entry in _categoryKeywords.entries) {
      if (descUpper.contains(entry.key)) {
        return entry.value;
      }
    }
    return 'Uncategorized';
  }

  Future<void> _importTransactions() async {
    if (_previewTransactions.isEmpty) return;
    if (_targetAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a target account')),
      );
      return;
    }

    setState(() => _isImporting = true);

    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    int importedCount = 0;
    int duplicateCount = 0;

    for (var tx in _previewTransactions) {
      // Duplicate check: date, amount, note, account
      final isDuplicate = txProvider.transactions.any((existing) =>
          existing.date.year == tx.date.year &&
          existing.date.month == tx.date.month &&
          existing.date.day == tx.date.day &&
          existing.amount == tx.amount &&
          existing.account == _targetAccount!.name &&
          existing.note == tx.note);

      if (isDuplicate) {
        duplicateCount++;
        continue;
      }

      await txProvider.saveTransaction(tx.copyWith(account: _targetAccount!.name));
      importedCount++;
    }

    // Log import to Firestore
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).collection('imports').add({
        'fileName': _selectedFile!.path.split('/').last,
        'account': _targetAccount!.name,
        'importedCount': importedCount,
        'duplicateCount': duplicateCount,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    setState(() => _isImporting = false);

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Complete'),
          content: Text('Successfully imported $importedCount transactions.\n$duplicateCount duplicates skipped.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Back to settings
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accProvider = Provider.of<AccountProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Bank Statement'),
      ),
      body: Column(
        children: [
          // File & Account Selection
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ListTile(
                  tileColor: Colors.grey[200],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: const Icon(Icons.file_present),
                  title: Text(_selectedFile == null ? 'Select CSV File' : _selectedFile!.path.split('/').last),
                  trailing: const Icon(Icons.upload_file),
                  onTap: _pickFile,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AccountModel>(
                  decoration: InputDecoration(
                    labelText: 'Target Account',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[200],
                  ),
                  value: _targetAccount,
                  items: accProvider.accounts.map((acc) {
                    return DropdownMenuItem(
                      value: acc,
                      child: Text(acc.name),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _targetAccount = val;
                      _generatePreview(); // Re-generate to update account name in preview
                    });
                  },
                ),
              ],
            ),
          ),

          if (_isParsing)
            const Expanded(child: Center(child: CircularProgressIndicator())),

          if (!_isParsing && _previewTransactions.isNotEmpty)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Preview (${_previewTransactions.length} rows)', 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('${_duplicateIndices.length} duplicates', style: const TextStyle(fontSize: 12, color: Colors.orange)),
                          ],
                        ),
                        if (_duplicateIndices.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 4.0),
                            child: Text('⚠️ Possible duplicate transactions detected.', 
                              style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _previewTransactions.length,
                        itemBuilder: (context, index) {
                          final tx = _previewTransactions[index];
                          final isExpense = tx.type == 'expense';
                          final isDuplicate = _duplicateIndices.contains(index);
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            color: isDuplicate ? Colors.orange[50] : null,
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                                color: isExpense ? Colors.red : Colors.green,
                              ),
                              title: Row(
                                children: [
                                  Expanded(child: Text(tx.note, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  if (isDuplicate)
                                    const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                                ],
                              ),
                              subtitle: Text('${DateFormat('dd MMM yyyy').format(tx.date)} • ${tx.category}'),
                              trailing: Text(
                                '${isExpense ? '-' : '+'} ${tx.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isExpense ? Colors.red : Colors.green,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

          if (!_isParsing && _selectedFile != null && _previewTransactions.isEmpty)
            const Expanded(child: Center(child: Text('No valid transactions found in CSV'))),

          if (_selectedFile == null)
            const Expanded(child: Center(child: Text('Select a bank CSV to start import'))),

          // Import Button
          if (_previewTransactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isImporting ? null : _importTransactions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isImporting 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Import Transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
