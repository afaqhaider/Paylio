import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../Transactions/transaction_model.dart';
import '../Transactions/transaction_provider.dart';
import '../Accounts/account_provider.dart';
import '../Accounts/account_model.dart';

class SkippedRow {
  final int index;
  final String reason;
  final List<dynamic> data;

  SkippedRow(this.index, this.reason, this.data);
}

class ImportCsvScreen extends StatefulWidget {
  const ImportCsvScreen({super.key});

  @override
  State<ImportCsvScreen> createState() => _ImportCsvScreenState();
}

class _ImportCsvScreenState extends State<ImportCsvScreen> {
  File? _selectedFile;
  List<List<dynamic>> _csvData = [];
  List<TransactionModel> _previewTransactions = [];
  List<SkippedRow> _skippedRows = [];
  Set<int> _duplicateIndices = {};
  AccountModel? _targetAccount;
  bool _isParsing = false;
  bool _isImporting = false;
  String _parseError = '';

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
    'ETISALAT': 'Bills',
    'DU': 'Bills',
    'DEWA': 'Bills',
    'SEWA': 'Bills',
    'FEWA': 'Bills',
    'IKEA': 'Home',
    'ACE': 'Home',
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
        _skippedRows = [];
        _duplicateIndices = {};
        _parseError = '';
      });
      _parseCsv();
    }
  }

  Future<void> _parseCsv() async {
    if (_selectedFile == null) return;

    setState(() => _isParsing = true);

    try {
      final bytes = await _selectedFile!.readAsBytes();
      String content;
      try {
        content = utf8.decode(bytes);
      } catch (e) {
        content = latin1.decode(bytes);
      }

      // Try different delimiters
      List<String> delimiters = [',', ';', '\t', '|'];
      List<List<dynamic>> bestFields = [];
      int maxCols = 0;

      for (var d in delimiters) {
        final fields = CsvToListConverter(
          fieldDelimiter: d,
          shouldParseNumbers: false,
          allowInvalid: true,
        ).convert(content);
        
        if (fields.isNotEmpty) {
          int currentMax = fields.map((r) => r.length).reduce((a, b) => a > b ? a : b);
          if (currentMax > maxCols) {
            maxCols = currentMax;
            bestFields = fields;
          }
        }
      }

      if (bestFields.isEmpty) {
        throw Exception('Could not parse CSV with any standard delimiter');
      }

      setState(() {
        _csvData = bestFields;
        _generatePreview();
      });
    } catch (e) {
      debugPrint('CSV Parse Error: $e');
      if (mounted) {
        setState(() {
          _parseError = 'Error reading CSV: $e';
        });
      }
    } finally {
      setState(() => _isParsing = false);
    }
  }

  void _generatePreview() {
    if (_csvData.isEmpty) {
      _parseError = 'CSV file is empty.';
      return;
    }

    int headerRowIndex = -1;
    int dateIdx = -1;
    int descIdx = -1;
    int debitIdx = -1;
    int creditIdx = -1;
    int amountIdx = -1;

    // Scan for header row dynamically with wider keyword support
    for (int i = 0; i < _csvData.length; i++) {
      final row = _csvData[i].map((e) => e.toString().toLowerCase().trim()).toList();
      
      int d = _findColumn(row, ['date', 'posting', 'value', 'txn date']);
      int ds = _findColumn(row, ['desc', 'narrat', 'particular', 'merchant', 'details', 'description', 'remarks']);
      int dr = _findColumn(row, ['debit', 'withdraw', 'paid out', 'money out', 'withdrawal', 'dr amount']);
      int cr = _findColumn(row, ['credit', 'deposit', 'paid in', 'money in', 'cr amount']);
      int am = _findColumn(row, ['amount', 'txn amount', 'transaction amount', 'value']);

      // Heuristic: If we found Date AND (Description OR Amount/Debit/Credit)
      if (d != -1 && (ds != -1 || am != -1 || dr != -1 || cr != -1)) {
        headerRowIndex = i;
        dateIdx = d;
        descIdx = ds != -1 ? ds : (am != -1 ? am : 0); // Fallback if description column not named well
        debitIdx = dr;
        creditIdx = cr;
        amountIdx = am;
        
        // If we only found date and amount but not description, look for the widest text column
        if (descIdx == -1 || descIdx == dateIdx || descIdx == amountIdx) {
            int longestTextIdx = -1;
            int maxLen = 0;
            for(int j=0; j<row.length; j++) {
                if(j == dateIdx || j == amountIdx || j == debitIdx || j == creditIdx) continue;
                if(row[j].length > maxLen) {
                    maxLen = row[j].length;
                    longestTextIdx = j;
                }
            }
            if(longestTextIdx != -1) descIdx = longestTextIdx;
        }
        
        break;
      }
    }

    if (headerRowIndex == -1) {
      setState(() {
        _parseError = 'CSV format not recognized. Could not find header row. Please ensure Date, Description and Amount are present.';
        _previewTransactions = [];
      });
      return;
    }

    List<TransactionModel> tempTxs = [];
    List<SkippedRow> skipped = [];
    
    for (int i = headerRowIndex + 1; i < _csvData.length; i++) {
      final row = _csvData[i];
      if (row.isEmpty || (row.length == 1 && row[0].toString().trim().isEmpty)) continue;

      String dateStr = _getValue(row, dateIdx).trim();
      DateTime? date = _parseDate(dateStr);

      if (date != null) {
        try {
          String description = _getValue(row, descIdx).trim();
          double finalAmount = 0;
          String type = 'expense';

          if (debitIdx != -1 || creditIdx != -1) {
            double debit = _parseAmount(_getValue(row, debitIdx));
            double credit = _parseAmount(_getValue(row, creditIdx));

            if (debit != 0) {
              type = 'expense';
              finalAmount = debit.abs();
            } else if (credit != 0) {
              type = 'income';
              finalAmount = credit.abs();
            } else {
              skipped.add(SkippedRow(i, 'Row has date but zero/empty amount', row));
              continue;
            }
          } else if (amountIdx != -1) {
            double amount = _parseAmount(_getValue(row, amountIdx));
            if (amount == 0) {
              skipped.add(SkippedRow(i, 'Zero amount', row));
              continue;
            }
            type = amount < 0 ? 'expense' : 'income';
            finalAmount = amount.abs();
          } else {
            skipped.add(SkippedRow(i, 'No amount detected', row));
            continue;
          }

          tempTxs.add(TransactionModel(
            type: type,
            category: 'Uncategorized',
            account: _targetAccount?.name ?? 'Unknown',
            note: description,
            amount: finalAmount,
            date: date,
          ));
        } catch (e) {
          skipped.add(SkippedRow(i, 'Parse error: $e', row));
        }
      } else {
        // Multi-line description detection
        String extraDesc = _getValue(row, descIdx).trim();
        if (extraDesc.isNotEmpty && tempTxs.isNotEmpty) {
          final lastIdx = tempTxs.length - 1;
          tempTxs[lastIdx] = tempTxs[lastIdx].copyWith(
            note: '${tempTxs[lastIdx].note} $extraDesc'.replaceAll(RegExp(r'\s+'), ' ').trim()
          );
        } else if (dateStr.isNotEmpty) {
             skipped.add(SkippedRow(i, 'Invalid date format: $dateStr', row));
        }
      }
    }

    final existingTxs = Provider.of<TransactionProvider>(context, listen: false).transactions;
    Set<int> duplicates = {};
    
    for (int i = 0; i < tempTxs.length; i++) {
      var tx = tempTxs[i];
      tx = tx.copyWith(category: _suggestCategory(tx.note));
      tempTxs[i] = tx;

      bool isDuplicate = existingTxs.any((e) =>
        e.date.year == tx.date.year &&
        e.date.month == tx.date.month &&
        e.date.day == tx.date.day &&
        e.amount == tx.amount &&
        e.note == tx.note &&
        (_targetAccount == null || e.account == _targetAccount!.name));

      if (isDuplicate) {
        duplicates.add(i);
      }
    }

    setState(() {
      _previewTransactions = tempTxs;
      _skippedRows = skipped;
      _duplicateIndices = duplicates;
      _parseError = tempTxs.isEmpty ? 'No valid transactions found. Please check if the file is a valid bank statement.' : '';
    });
  }

  int _findColumn(List<String> header, List<String> keywords) {
    for (var keyword in keywords) {
      int idx = header.indexWhere((h) => h == keyword || h.contains(keyword));
      if (idx != -1) return idx;
    }
    return -1;
  }

  String _getValue(List<dynamic> row, int index) {
    if (index == -1 || index >= row.length) return '';
    return row[index]?.toString() ?? '';
  }

  DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    
    List<String> formats = [
      'dd/MM/yyyy', 'dd-MM-yyyy', 'yyyy-MM-dd', 'dd MMM yyyy', 'MM/dd/yyyy',
      'd/M/yyyy', 'd-M-yyyy', 'dd.MM.yyyy', 'MMM dd, yyyy', 'dd MMM, yyyy',
      'dd/MM/yy', 'dd-MM-yy', 'MM/dd/yy',
    ];

    String cleanDate = dateStr.trim();

    for (var format in formats) {
      try {
        return DateFormat(format).parseStrict(cleanDate);
      } catch (_) {}
    }
    try {
      return DateTime.parse(cleanDate);
    } catch (_) {}

    return null;
  }

  double _parseAmount(String amountStr) {
    if (amountStr.isEmpty) return 0;
    String clean = amountStr.replaceAll(RegExp(r'[^\d.\-()]'), '').trim();
    if (clean.startsWith('(') && clean.endsWith(')')) {
      clean = '-${clean.substring(1, clean.length - 1)}';
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

    for (int i = 0; i < _previewTransactions.length; i++) {
      if (_duplicateIndices.contains(i)) {
        duplicateCount++;
        continue;
      }
      final tx = _previewTransactions[i];
      await txProvider.saveTransaction(tx.copyWith(account: _targetAccount!.name));
      importedCount++;
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
                Navigator.pop(context);
                Navigator.pop(context);
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
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Bank Statement'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ListTile(
                  tileColor: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                  ),
                  leading: const Icon(Icons.file_present, color: Color(0xFF0F766E)),
                  title: Text(_selectedFile == null 
                    ? 'Select CSV File' 
                    : _selectedFile!.path.split('/').last),
                  subtitle: const Text('Accepts common bank formats'),
                  trailing: const Icon(Icons.upload_file),
                  onTap: _pickFile,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<AccountModel>(
                  decoration: const InputDecoration(
                    labelText: 'Target Account',
                  ),
                  initialValue: _targetAccount,
                  items: accProvider.accounts.map((acc) {
                    return DropdownMenuItem(
                      value: acc,
                      child: Text(acc.name),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _targetAccount = val;
                      if (_csvData.isNotEmpty) _generatePreview();
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Preview (${_previewTransactions.length} rows)', 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        if (_skippedRows.isNotEmpty)
                          TextButton(
                            onPressed: _showSkippedRows,
                            child: Text('${_skippedRows.length} skipped', 
                              style: const TextStyle(color: Colors.red, fontSize: 12)),
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
                          elevation: 0,
                          color: isDuplicate 
                            ? Colors.orange.withOpacity(0.05) 
                            : Theme.of(context).cardColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isDuplicate ? Colors.orange.withOpacity(0.3) : Colors.grey.withOpacity(0.1)
                            ),
                          ),
                          child: ListTile(
                            dense: true,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isExpense ? Colors.red : Colors.green).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                                color: isExpense ? Colors.red : Colors.green,
                                size: 16,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(child: Text(tx.note, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                                if (isDuplicate)
                                  const Icon(Icons.copy_rounded, size: 14, color: Colors.orange),
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
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off_outlined, size: 48, color: Colors.orange),
                      const SizedBox(height: 16),
                      Text(_parseError, textAlign: TextAlign.center, 
                        style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                      if (_skippedRows.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        OutlinedButton(
                          onPressed: _showSkippedRows,
                          child: Text('View ${_skippedRows.length} Skipped Rows'),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            ),

          if (_selectedFile == null)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.upload_file_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Select a bank CSV to start import', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),

          if (_previewTransactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _isImporting ? null : _importTransactions,
                child: _isImporting 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Import ${_previewTransactions.length - _duplicateIndices.length} Transactions'),
              ),
            ),
        ],
      ),
    );
  }

  void _showSkippedRows() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Skipped Rows (${_skippedRows.length})', 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _skippedRows.length,
                itemBuilder: (context, index) {
                  final skip = _skippedRows[index];
                  return ListTile(
                    leading: CircleAvatar(child: Text('${skip.index}')),
                    title: Text(skip.reason),
                    subtitle: Text(skip.data.join(', '), maxLines: 2, overflow: TextOverflow.ellipsis),
                    isThreeLine: true,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
