import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../Accounts/account_model.dart';
import '../Accounts/account_provider.dart';
import '../Categories/category_model.dart';
import '../Categories/category_provider.dart';
import 'transaction_model.dart';
import 'transaction_provider.dart';

enum ImportType { transactions, categories, accounts }

class ImportDataScreen extends StatefulWidget {
  const ImportDataScreen({super.key});

  @override
  State<ImportDataScreen> createState() => _ImportDataScreenState();
}

class _ImportDataScreenState extends State<ImportDataScreen> {
  ImportType _selectedType = ImportType.transactions;
  bool _isParsing = false;
  bool _isImporting = false;
  List<List<dynamic>> _csvData = [];
  List<Map<String, dynamic>> _validatedRows = [];
  String? _fileName;

  final List<String> _transactionHeaders = [
    'Date', 'Description', 'Amount', 'Type', 'Category Name', 'Account Name', 'Payment Method', 'Notes'
  ];
  final List<String> _categoryHeaders = [
    'Category Name', 'Type', 'Parent Category', 'Budget Amount', 'Icon', 'Color', 'Is Active'
  ];
  final List<String> _accountHeaders = [
    'Account Name', 'Account Type', 'Opening Balance', 'Currency', 'Bank Name', 'Is Checking Account', 'Has Direct Debit', 'Notes', 'Is Active'
  ];

  Future<void> _downloadTemplate() async {
    List<List<String>> rows = [];
    String fileName = '';

    switch (_selectedType) {
      case ImportType.transactions:
        rows.add(_transactionHeaders);
        rows.add(['2024-05-08', 'Lunch at Waitrose', '125.50', 'Expense', 'Food & Drinks', 'Cash', 'Cash', 'Groceries']);
        fileName = 'paylio_transactions_template.csv';
        break;
      case ImportType.categories:
        rows.add(_categoryHeaders);
        rows.add(['Shopping', 'Expense', '', '500', 'shopping_cart', '0xFF2196F3', 'TRUE']);
        fileName = 'paylio_categories_template.csv';
        break;
      case ImportType.accounts:
        rows.add(_accountHeaders);
        rows.add(['RAKBANK', 'Bank', '5000', 'AED', 'RAKBANK', 'TRUE', 'FALSE', 'Primary Account', 'TRUE']);
        fileName = 'paylio_accounts_template.csv';
        break;
    }

    String csv = const ListToCsvConverter().convert(rows);
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csv);

    await Share.shareXFiles([XFile(file.path)], text: 'Paylio Import Template');
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _fileName = result.files.single.name;
        _isParsing = true;
        _csvData = [];
        _validatedRows = [];
      });

      try {
        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        String content;
        try {
          content = utf8.decode(bytes);
        } catch (_) {
          content = latin1.decode(bytes);
        }

        final rows = const CsvToListConverter(shouldParseNumbers: false).convert(content);
        if (rows.isEmpty) throw Exception('File is empty');

        if (mounted) {
          setState(() {
            _csvData = rows;
          });

          // Call validation outside of setState
          _validateData();
        }
      } catch (e, stack) {
        debugPrint("CSV Parsing Error: $e");
        debugPrintStack(stackTrace: stack);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        if (mounted) {
          setState(() => _isParsing = false);
        }
      }
    }
  }

  String _normalize(dynamic e) {
    return e?.toString().trim() ?? '';
  }

  String _normalizeHeader(dynamic h) {
    return _normalize(h).toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
  }

  void _validateData() {
    if (_csvData.isEmpty) return;
    
    try {
      debugPrint('CSV Data raw type: ${_csvData[0].runtimeType}');
      final List<String> rawHeader = _csvData[0].map((e) => _normalize(e)).toList();
      final List<String> normalizedHeader = rawHeader.map((h) => _normalizeHeader(h)).toList();
      
      debugPrint('Converted Headers: $rawHeader');
      debugPrint('Normalized Headers: $normalizedHeader');

      List<Map<String, dynamic>> results = [];

      // Verify headers with normalization
      List<String> expectedHeaders = _selectedType == ImportType.transactions 
          ? _transactionHeaders : _selectedType == ImportType.categories 
          ? _categoryHeaders : _accountHeaders;

      List<String> normalizedExpected = expectedHeaders.map((h) => _normalizeHeader(h)).toList();

      bool headersMatch = true;
      for (var h in normalizedExpected) {
        if (!normalizedHeader.contains(h)) {
          headersMatch = false;
          debugPrint('Missing expected header: $h');
          break;
        }
      }

      if (!headersMatch) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid template. Headers do not match.')));
        }
        return;
      }

      final txProvider = Provider.of<TransactionProvider>(context, listen: false);
      final catProvider = Provider.of<CategoryProvider>(context, listen: false);
      final accProvider = Provider.of<AccountProvider>(context, listen: false);

      for (int i = 1; i < _csvData.length; i++) {
        final List<dynamic> row = _csvData[i];
        if (row.isEmpty || (row.length == 1 && _normalize(row[0]).isEmpty)) continue;

        // Safe conversion of row values
        final List<String> rowValues = row.map((e) => _normalize(e)).toList();

        Map<String, dynamic> validated = {'row': rowValues, 'isValid': true, 'errors': []};
        Map<String, String> data = {};
        
        for (int j = 0; j < expectedHeaders.length; j++) {
          String expectedNorm = _normalizeHeader(expectedHeaders[j]);
          int actualIdx = normalizedHeader.indexOf(expectedNorm);
          if (actualIdx != -1 && actualIdx < rowValues.length) {
            data[expectedHeaders[j]] = rowValues[actualIdx];
          } else {
            data[expectedHeaders[j]] = '';
          }
        }

        _performValidation(validated, data, txProvider, catProvider, accProvider);
        results.add(validated);
      }

      if (mounted) {
        setState(() {
          _validatedRows = results;
        });
      }
    } catch (e, stack) {
      log("Validation Error", error: e, stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Validation failed: $e')));
      }
    }
  }

  void _performValidation(Map<String, dynamic> validated, Map<String, String> data, TransactionProvider txP, CategoryProvider catP, AccountProvider accP) {
    List<String> errors = [];

    if (_selectedType == ImportType.transactions) {
      // Date
      if (data['Date']!.isEmpty) {
        errors.add('Missing Date');
      } else {
        try {
          DateFormat('yyyy-MM-dd').parseStrict(data['Date']!);
        } catch (_) {
          errors.add('Invalid Date Format. Use yyyy-MM-dd');
        }
      }

      // Amount
      double? amount = double.tryParse(data['Amount']!.replaceAll(',', ''));
      if (data['Amount']!.isEmpty) {
        errors.add('Missing Amount');
      } else if (amount == null) {
        errors.add('Invalid Amount');
      }

      // Type
      String type = data['Type']!.toLowerCase();
      if (!['income', 'expense'].contains(type)) {
        errors.add('Invalid Type. Use Income or Expense');
      }

      // Duplicate Check
      if (errors.isEmpty) {
        DateTime date = DateFormat('yyyy-MM-dd').parse(data['Date']!);
        bool isDuplicate = txP.transactions.any((e) =>
          e.date.year == date.year &&
          e.date.month == date.month &&
          e.date.day == date.day &&
          e.amount == amount &&
          e.note == data['Description'] &&
          e.account == data['Account Name']);
        if (isDuplicate) errors.add('Duplicate transaction');
      }

    } else if (_selectedType == ImportType.categories) {
      if (data['Category Name']!.isEmpty) errors.add('Missing Category Name');
      String type = data['Type']!.toLowerCase();
      if (!['income', 'expense'].contains(type)) errors.add('Invalid Type. Use Income or Expense');
      
      // Duplicate
      if (catP.expenseCategories.any((c) => c.name == data['Category Name'] && type == 'expense') ||
          catP.incomeCategories.any((c) => c.name == data['Category Name'] && type == 'income')) {
        errors.add('Duplicate Category');
      }

    } else if (_selectedType == ImportType.accounts) {
      if (data['Account Name']!.isEmpty) errors.add('Missing Account Name');
      if (data['Account Type']!.isEmpty) errors.add('Missing Account Type');
      if (data['Account Type']!.toLowerCase() == 'bank' && data['Bank Name']!.isEmpty) {
        errors.add('Bank Name required for Bank type');
      }
      if (double.tryParse(data['Opening Balance']!.replaceAll(',', '')) == null && data['Opening Balance']!.isNotEmpty) {
        errors.add('Invalid Opening Balance');
      }
      
      // Duplicate
      if (accP.accounts.any((a) => a.name == data['Account Name'])) {
        errors.add('Duplicate Account Name');
      }
    }

    if (errors.isNotEmpty) {
      validated['isValid'] = false;
      validated['errors'] = errors;
    }
  }

  Future<void> _executeImport() async {
    final validRows = _validatedRows.where((r) => r['isValid']).toList();
    if (validRows.isEmpty) return;

    setState(() => _isImporting = true);

    try {
      final txProvider = Provider.of<TransactionProvider>(context, listen: false);
      final catProvider = Provider.of<CategoryProvider>(context, listen: false);
      final accProvider = Provider.of<AccountProvider>(context, listen: false);

      int importedCount = 0;

      final List<String> rawHeader = _csvData[0].map((e) => _normalize(e)).toList();
      final List<String> normalizedHeader = rawHeader.map((h) => _normalizeHeader(h)).toList();

      List<String> expectedHeaders = _selectedType == ImportType.transactions 
          ? _transactionHeaders : _selectedType == ImportType.categories 
          ? _categoryHeaders : _accountHeaders;

      for (var rowMap in validRows) {
        final row = rowMap['row'] as List<String>;
        Map<String, String> data = {};
        
        for (int j = 0; j < expectedHeaders.length; j++) {
          String expectedNorm = _normalizeHeader(expectedHeaders[j]);
          int actualIdx = normalizedHeader.indexOf(expectedNorm);
          if (actualIdx != -1 && actualIdx < row.length) {
            data[expectedHeaders[j]] = row[actualIdx];
          } else {
            data[expectedHeaders[j]] = '';
          }
        }

        if (_selectedType == ImportType.transactions) {
          String accountName = data['Account Name']!;
          if (!accProvider.accounts.any((a) => a.name == accountName)) {
            await accProvider.saveAccount(AccountModel(
              name: accountName,
              type: 'Cash',
              openingBalance: 0,
              currency: 'AED',
              isActive: true,
            ));
          }

          String categoryName = data['Category Name']!;
          String type = data['Type']!.toLowerCase();
          bool catExists = (type == 'expense' 
              ? catProvider.expenseCategories.any((c) => c.name == categoryName)
              : catProvider.incomeCategories.any((c) => c.name == categoryName));
          
          if (!catExists) {
            await catProvider.saveCategory(CategoryModel(
              name: categoryName,
              type: type,
              icon: 'category',
              color: '0xFF0F766E',
              isActive: true,
            ));
          }

          await txProvider.saveTransaction(TransactionModel(
            type: type,
            category: categoryName,
            account: accountName,
            note: data['Description']!,
            amount: double.parse(data['Amount']!.replaceAll(',', '')),
            date: DateFormat('yyyy-MM-dd').parse(data['Date']!),
          ));

        } else if (_selectedType == ImportType.categories) {
          await catProvider.saveCategory(CategoryModel(
            name: data['Category Name']!,
            type: data['Type']!.toLowerCase(),
            icon: data['Icon']!.isEmpty ? 'category' : data['Icon']!,
            color: data['Color']!.isEmpty ? '0xFF0F766E' : data['Color']!,
            isActive: data['Is Active']!.toUpperCase() != 'FALSE',
          ));
        } else if (_selectedType == ImportType.accounts) {
          await accProvider.saveAccount(AccountModel(
            name: data['Account Name']!,
            type: data['Account Type']!,
            openingBalance: double.tryParse(data['Opening Balance']!.replaceAll(',', '')) ?? 0,
            currency: data['Currency']!.isEmpty ? 'AED' : data['Currency']!,
            bankName: data['Bank Name'],
            isChecking: data['Is Checking Account']!.toUpperCase() == 'TRUE',
            hasDirectDebit: data['Has Direct Debit']!.toUpperCase() == 'TRUE',
            notes: data['Notes'],
            isActive: data['Is Active']!.toUpperCase() != 'FALSE',
          ));
        }
        importedCount++;
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Import Complete'),
            content: Text('$importedCount records imported successfully. ${_validatedRows.length - importedCount} rows skipped.'),
            actions: [
              TextButton(onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              }, child: const Text('OK')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    } finally {
      setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Data'),
      ),
      body: Column(
        children: [
          _buildTypeSelector(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStep(
                    '1',
                    'Download Template',
                    'Download the standard CSV template for ${_selectedType.name}.',
                    ElevatedButton.icon(
                      onPressed: _downloadTemplate,
                      icon: const Icon(Icons.download),
                      label: const Text('Download Template'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildStep(
                    '2',
                    'Upload Completed File',
                    'Fill the CSV and upload it here.',
                    ElevatedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.upload_file),
                      label: Text(_fileName ?? 'Select CSV File'),
                    ),
                  ),
                  if (_isParsing)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_validatedRows.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('Preview & Validation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _buildPreviewList(),
                  ],
                ],
              ),
            ),
          ),
          if (_validatedRows.any((r) => r['isValid']))
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _isImporting ? null : _executeImport,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: const Color(0xFF0F766E),
                ),
                child: _isImporting 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('Import ${_validatedRows.where((r) => r['isValid']).length} Valid Records'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Theme.of(context).cardColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: ImportType.values.map((type) {
          bool isSelected = _selectedType == type;
          return ChoiceChip(
            label: Text(type.name[0].toUpperCase() + type.name.substring(1)),
            selected: isSelected,
            onSelected: (val) {
              if (val) {
                setState(() {
                  _selectedType = type;
                  _fileName = null;
                  _csvData = [];
                  _validatedRows = [];
                });
              }
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStep(String number, String title, String description, Widget action) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: const Color(0xFF0F766E),
          child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(description, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 12),
              action,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _validatedRows.length,
      itemBuilder: (context, index) {
        final row = _validatedRows[index];
        final bool isValid = row['isValid'];
        final List<String> errors = row['errors'];
        final data = row['row'];

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            leading: Icon(
              isValid ? Icons.check_circle : Icons.error,
              color: isValid ? Colors.green : Colors.red,
            ),
            title: Text(data[0].toString().isEmpty ? '(Empty Name/Date)' : data[0].toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: Text(isValid ? 'Ready to import' : errors.join(', '), style: TextStyle(color: isValid ? Colors.green : Colors.red, fontSize: 12)),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Row Data:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(data.join(' | ')),
                    if (!isValid) ...[
                      const SizedBox(height: 8),
                      const Text('Validation Errors:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      ...errors.map((e) => Text('• $e', style: const TextStyle(color: Colors.red))),
                    ]
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
