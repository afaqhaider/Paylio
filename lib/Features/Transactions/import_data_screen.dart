import 'dart:convert';
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
  final ImportType initialType;
  const ImportDataScreen({super.key, this.initialType = ImportType.transactions});

  @override
  State<ImportDataScreen> createState() => _ImportDataScreenState();
}

class _ImportDataScreenState extends State<ImportDataScreen> {
  late ImportType _selectedType;
  bool _isParsing = false;
  bool _isImporting = false;
  List<List<dynamic>> _csvData = [];
  List<Map<String, dynamic>> _validatedRows = [];
  String? _fileName;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

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
        fileName = 'ledgix_transactions_template.csv';
        break;
      case ImportType.categories:
        rows.add(_categoryHeaders);
        rows.add(['Shopping', 'Expense', '', '500', 'shopping_cart', '0xFF2196F3', 'TRUE']);
        fileName = 'ledgix_categories_template.csv';
        break;
      case ImportType.accounts:
        rows.add(_accountHeaders);
        rows.add(['RAKBANK', 'Bank', '5000', 'AED', 'RAKBANK', 'TRUE', 'FALSE', 'Primary Account', 'TRUE']);
        fileName = 'ledgix_accounts_template.csv';
        break;
    }

    String csv = const ListToCsvConverter().convert(rows);
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csv);

    await Share.shareXFiles([XFile(file.path)], text: 'LedGix Import Template');
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

        setState(() {
          _csvData = rows;
          _validateData();
        });
      } catch (e, stack) {
        debugPrint("CSV Parsing Error: $e");
        debugPrintStack(stackTrace: stack);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        setState(() => _isParsing = false);
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

      final List<String> rowValues = row.map((e) => _normalize(e)).toList();
      debugPrint('Row $i values: $rowValues');

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

    setState(() => _validatedRows = results);
  }

  void _performValidation(Map<String, dynamic> validated, Map<String, String> data, TransactionProvider txP, CategoryProvider catP, AccountProvider accP) {
    List<String> errors = [];

    if (_selectedType == ImportType.transactions) {
      if (data['Date']!.isEmpty) {
        errors.add('Missing Date');
      } else {
        try {
          DateFormat('yyyy-MM-dd').parseStrict(data['Date']!);
        } catch (_) {
          errors.add('Invalid Date Format. Use yyyy-MM-dd');
        }
      }

      double? amount = double.tryParse(data['Amount']!.replaceAll(',', ''));
      if (data['Amount']!.isEmpty) {
        errors.add('Missing Amount');
      } else if (amount == null) {
        errors.add('Invalid Amount');
      }

      String type = data['Type']!.toLowerCase();
      if (!['income', 'expense'].contains(type)) {
        errors.add('Invalid Type. Use Income or Expense');
      }

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

      for (var rowMap in validRows) {
        final List<String> row = rowMap['row'];
        final header = _csvData[0].map((e) => _normalize(e)).toList();
        final normalizedHeader = header.map((h) => _normalizeHeader(h)).toList();

        Map<String, String> data = {};
        List<String> expectedHeaders = _selectedType == ImportType.transactions 
            ? _transactionHeaders : _selectedType == ImportType.categories 
            ? _categoryHeaders : _accountHeaders;

        for (var h in expectedHeaders) {
            String norm = _normalizeHeader(h);
            int idx = normalizedHeader.indexOf(norm);
            data[h] = idx != -1 && idx < row.length ? row[idx] : '';
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
              color: '0xFF218BFF',
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
            color: data['Color']!.isEmpty ? '0xFF218BFF' : data['Color']!,
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
        title: const Text('Import Data', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Column(
        children: [
          _buildTypeSelector(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStep(
                    '1',
                    'Download Template',
                    'Get the standard CSV template for ${_selectedType.name}.',
                    ElevatedButton.icon(
                      onPressed: _downloadTemplate,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Download Template'),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildStep(
                    '2',
                    'Upload Completed File',
                    'Upload your filled CSV file here.',
                    ElevatedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: Text(_fileName ?? 'Select CSV File'),
                    ),
                  ),
                  if (_isParsing)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_validatedRows.isNotEmpty) ...[
                    const SizedBox(height: 40),
                    Text('PREVIEW & VALIDATION', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4))),
                    const SizedBox(height: 16),
                    _buildPreviewList(),
                  ],
                ],
              ),
            ),
          ),
          if (_validatedRows.any((r) => r['isValid']))
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: ElevatedButton(
                onPressed: _isImporting ? null : _executeImport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
                child: _isImporting 
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Import ${_validatedRows.where((r) => r['isValid']).length} Valid Records'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: Theme.of(context).colorScheme.surface,
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
            selectedColor: Theme.of(context).colorScheme.primary,
            labelStyle: TextStyle(color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            showCheckmark: false,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStep(String number, String title, String description, Widget action) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
          child: Center(child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900))),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 4),
              Text(description, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 14)),
              const SizedBox(height: 16),
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
        final List<String> data = row['row'];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isValid ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
          ),
          child: ExpansionTile(
            shape: const Border(),
            leading: Icon(
              isValid ? Icons.check_circle_rounded : Icons.error_rounded,
              color: isValid ? Colors.green : Colors.redAccent,
            ),
            title: Text(data[0].isEmpty ? '(No Primary Key)' : data[0], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            subtitle: Text(isValid ? 'Ready to import' : errors.join(', '), style: TextStyle(color: isValid ? Colors.green : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600)),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ROW DATA', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text(data.join('  |  '), style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                    if (!isValid) ...[
                      const SizedBox(height: 16),
                      const Text('VALIDATION ERRORS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1, color: Colors.redAccent)),
                      const SizedBox(height: 8),
                      ...errors.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $e', style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      )),
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
