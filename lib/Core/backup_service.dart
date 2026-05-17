import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'database_helper.dart';

class BackupService {
  static Future<void> exportFullBackup() async {
    try {
      final data = await DatabaseHelper.instance.getAllBackupData();
      final jsonString = jsonEncode(data);
      
      final timestamp = DateFormat('yyyy_MM_dd_HHmm').format(DateTime.now());
      final fileName = 'ledgix_backup_$timestamp.json';

      if (kIsWeb) {
        // Web download logic (not fully implemented with share_plus, usually use anchor tag)
        // For now, we'll focus on mobile as requested for most SQLite apps
        return;
      }

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonString);

      await Share.shareXFiles([XFile(file.path)], text: 'LedGix Data Backup');
    } catch (e) {
      throw Exception('Failed to export backup: $e');
    }
  }

  static Future<void> exportTransactionsCsv() async {
    try {
      final transactions = await DatabaseHelper.instance.getTransactions();
      
      List<List<dynamic>> rows = [];
      // Header
      rows.add(['ID', 'Type', 'Category', 'Account', 'Amount', 'Date', 'Note']);

      for (var t in transactions) {
        rows.add([
          t.id,
          t.type,
          t.category,
          t.account,
          t.amount,
          DateFormat('yyyy-MM-dd').format(t.date),
          t.note,
        ]);
      }

      String csvData = const ListToCsvConverter().convert(rows);
      
      final timestamp = DateFormat('yyyy_MM_dd_HHmm').format(DateTime.now());
      final fileName = 'ledgix_transactions_$timestamp.csv';

      if (kIsWeb) return;

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvData);

      await Share.shareXFiles([XFile(file.path)], text: 'LedGix Transactions Export');
    } catch (e) {
      throw Exception('Failed to export CSV: $e');
    }
  }

  static Future<String?> importBackup() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final Map<String, dynamic> data = jsonDecode(content);

        // Basic validation
        if (!data.containsKey('metadata') || !data.containsKey('transactions')) {
          return 'Invalid backup file format';
        }

        await DatabaseHelper.instance.restoreBackupData(data);
        return null; // Success
      }
      return 'No file selected';
    } catch (e) {
      return 'Import failed: $e';
    }
  }
}
