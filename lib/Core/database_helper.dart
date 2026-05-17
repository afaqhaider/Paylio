import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../Features/Transactions/transaction_model.dart';
import '../Features/Accounts/account_model.dart';
import '../Features/Budgets/budget_model.dart';
import '../Features/Categories/category_model.dart';
import '../Features/Auth/user_model.dart';
import '../Features/People/person_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError("SQLite database is not available on Web.");
    }
    if (_database != null) return _database!;

    _database = await _initDB('ledgix.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 12,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE transactions ADD COLUMN toAccount TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE budgets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category TEXT,
          amountLimit REAL,
          period TEXT
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE budgets ADD COLUMN month INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE budgets ADD COLUMN year INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE budgets ADD COLUMN notes TEXT');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE transactions ADD COLUMN attachmentPath TEXT');
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          email TEXT UNIQUE,
          password TEXT,
          profilePhoto TEXT
        )
      ''');
    }
    if (oldVersion < 8) {
      try { await db.execute('ALTER TABLE users ADD COLUMN ledgixId TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE users ADD COLUMN username TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE users ADD COLUMN phoneNumber TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE users ADD COLUMN preferredCurrency TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE users ADD COLUMN country TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE users ADD COLUMN themePreference TEXT'); } catch (_) {}
    }
    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS people (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ledgixId TEXT,
          name TEXT,
          email TEXT,
          phone TEXT,
          notes TEXT
        )
      ''');
      try { await db.execute('ALTER TABLE transactions ADD COLUMN personId INTEGER'); } catch (_) {}
    }
    if (oldVersion < 11) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          icon TEXT,
          color TEXT,
          isDefault INTEGER DEFAULT 0,
          createdAt TEXT
        )
      ''');
      try { await db.execute('ALTER TABLE categories ADD COLUMN icon TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE categories ADD COLUMN color TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE categories ADD COLUMN isDefault INTEGER DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE categories ADD COLUMN createdAt TEXT'); } catch (_) {}

      await _seedDefaultCategories(db);
    }

    if (oldVersion < 12) {
      try {
        await db.execute('ALTER TABLE accounts ADD COLUMN creditLimit REAL');
      } catch (_) {}
    }
    if (oldVersion < 13) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS goals (
          id TEXT PRIMARY KEY,
          name TEXT,
          targetAmount REAL,
          savedAmount REAL,
          color TEXT,
          deadline TEXT,
          createdAt TEXT
        )
      ''');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        ledgixId TEXT UNIQUE,
        username TEXT UNIQUE,
        name TEXT,
        email TEXT UNIQUE,
        password TEXT,
        profilePhoto TEXT,
        phoneNumber TEXT,
        preferredCurrency TEXT,
        country TEXT,
        themePreference TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        name TEXT UNIQUE,
        type TEXT,
        openingBalance REAL,
        creditLimit REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT,
        type TEXT,
        icon TEXT,
        color TEXT,
        isDefault INTEGER DEFAULT 0,
        createdAt TEXT,
        UNIQUE(name, type)
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        type TEXT,
        category TEXT,
        account TEXT,
        toAccount TEXT,
        note TEXT,
        amount REAL,
        date TEXT,
        attachmentPath TEXT,
        personId TEXT,
        parentLoanId TEXT,
        status TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        category TEXT,
        amountLimit REAL,
        period TEXT,
        month INTEGER,
        year INTEGER,
        notes TEXT,
        UNIQUE(category, period, month, year)
      )
    ''');

    await db.execute('''
      CREATE TABLE people (
        id TEXT PRIMARY KEY,
        ledgixId TEXT,
        name TEXT,
        email TEXT,
        phone TEXT,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE goals (
        id TEXT PRIMARY KEY,
        name TEXT,
        targetAmount REAL,
        savedAmount REAL,
        color TEXT,
        deadline TEXT,
        createdAt TEXT
      )
    ''');

    await _seedDefaultCategories(db);
  }

  Future<void> _seedDefaultCategories(Database db) async {
    final defaultCategories = [
      {'name': 'Food & Drinks', 'type': 'expense', 'isDefault': 1},
      {'name': 'Shopping', 'type': 'expense', 'isDefault': 1},
      {'name': 'Housing', 'type': 'expense', 'isDefault': 1},
      {'name': 'Transportation', 'type': 'expense', 'isDefault': 1},
      {'name': 'Entertainment', 'type': 'expense', 'isDefault': 1},
      {'name': 'Salary', 'type': 'income', 'isDefault': 1},
      {'name': 'Gift', 'type': 'income', 'isDefault': 1},
      {'name': 'Investments', 'type': 'income', 'isDefault': 1},
    ];

    for (var cat in defaultCategories) {
      cat['createdAt'] = DateTime.now().toIso8601String();
      await db.insert('categories', cat, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // --- Categories ---

  Future<int> insertCategory(CategoryModel category) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.insert('categories', category.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<CategoryModel>> getCategories() async {
    if (kIsWeb) return [];
    final db = await instance.database;
    final result = await db.query('categories', orderBy: 'name ASC');
    return result.map((map) => CategoryModel.fromMap(map)).toList();
  }

  Future<List<CategoryModel>> getCategoriesByType(String type) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    final result = await db.query('categories', where: 'type = ?', whereArgs: [type], orderBy: 'name ASC');
    return result.map((map) => CategoryModel.fromMap(map)).toList();
  }

  Future<int> deleteCategory(int id) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // --- Transactions ---

  Future<int> insertTransaction(TransactionModel transaction) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.insert('transactions', transaction.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<TransactionModel>> getTransactions({int? limit}) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    final result = await db.query('transactions', orderBy: 'date DESC', limit: limit);
    return result.map((map) => TransactionModel.fromMap(map)).toList();
  }

  Future<int> updateTransaction(TransactionModel transaction) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.update('transactions', transaction.toMap(), where: 'id = ?', whereArgs: [transaction.id]);
  }

  Future<int> deleteTransaction(int id) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // --- Accounts ---

  Future<int> insertAccount(AccountModel account) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.insert('accounts', account.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<AccountModel>> getAccounts() async {
    if (kIsWeb) return [];
    final db = await instance.database;
    final result = await db.query('accounts', orderBy: 'name ASC');
    return result.map((map) => AccountModel.fromMap(map)).toList();
  }

  Future<double> getAccountBalance(String accountName) async {
    if (kIsWeb) return 0;
    final db = await instance.database;

    final accountResult = await db.query('accounts', where: 'name = ?', whereArgs: [accountName], limit: 1);
    if (accountResult.isEmpty) return 0;

    final account = AccountModel.fromMap(accountResult.first);
    double openingBalance = account.openingBalance;

    final incResult = await db.rawQuery(
      "SELECT SUM(amount) as total FROM transactions WHERE (account = ? AND type IN ('income', 'borrow', 'repayment_received', 'loan_received')) OR (toAccount = ? AND type = 'transfer')",
      [accountName, accountName]
    );
    
    final expResult = await db.rawQuery(
      "SELECT SUM(amount) as total FROM transactions WHERE (account = ? AND type IN ('expense', 'lend', 'repayment_paid', 'transfer', 'savings_transfer', 'liability_payment', 'loan_given'))",
      [accountName]
    );

    double income = (incResult.first['total'] as num?)?.toDouble() ?? 0;
    double expense = (expResult.first['total'] as num?)?.toDouble() ?? 0;

    if (account.type == 'Credit Card') {
      return openingBalance + expense - income;
    }

    return openingBalance + income - expense;
  }

  Future<double> getTotalBalance() async {
    if (kIsWeb) return 0.0;
    final accounts = await getAccounts();
    double total = 0;
    for (var acc in accounts) {
      double balance = await getAccountBalance(acc.name);
      if (acc.type == 'Credit Card') {
        total -= balance;
      } else {
        total += balance;
      }
    }
    return total;
  }

  // --- Backup & Restore ---

  Future<Map<String, dynamic>> getAllBackupData() async {
    if (kIsWeb) return {};
    final db = await instance.database;
    
    return {
      'users': await db.query('users'),
      'accounts': await db.query('accounts'),
      'categories': await db.query('categories'),
      'transactions': await db.query('transactions'),
      'budgets': await db.query('budgets'),
      'people': await db.query('people'),
      'metadata': {
        'backupDate': DateTime.now().toIso8601String(),
        'version': 11,
      }
    };
  }

  Future<void> restoreBackupData(Map<String, dynamic> data) async {
    if (kIsWeb) return;
    final db = await instance.database;

    await db.transaction((txn) async {
      Future<void> safeInsert(String table, List<dynamic>? list) async {
        if (list == null) return;
        for (var item in list) {
          final map = Map<String, dynamic>.from(item);
          if (table == 'users' && map.containsKey('email')) {
            final existing = await txn.query(table, where: 'email = ?', whereArgs: [map['email']]);
            if (existing.isNotEmpty) {
              await txn.update(table, map, where: 'email = ?', whereArgs: [map['email']]);
              continue;
            }
          }
          if (table == 'categories' && map.containsKey('name') && map.containsKey('type')) {
            final existing = await txn.query(table, where: 'name = ? AND type = ?', whereArgs: [map['name'], map['type']]);
            if (existing.isNotEmpty) continue;
          }
          if (table == 'accounts' && map.containsKey('name')) {
            final existing = await txn.query(table, where: 'name = ?', whereArgs: [map['name']]);
            if (existing.isNotEmpty) continue;
          }
          
          await txn.insert(table, map, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      await safeInsert('users', data['users']);
      await safeInsert('accounts', data['accounts']);
      await safeInsert('categories', data['categories']);
      await safeInsert('people', data['people']);
      await safeInsert('transactions', data['transactions']);
      await safeInsert('budgets', data['budgets']);
    });
  }

  // --- Budgets ---

  Future<int> insertBudget(BudgetModel budget) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.insert('budgets', budget.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<BudgetModel>> getBudgets() async {
    if (kIsWeb) return [];
    final db = await instance.database;
    final result = await db.query('budgets');
    return result.map((map) => BudgetModel.fromMap(map)).toList();
  }

  Future<int> updateBudget(BudgetModel budget) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.update('budgets', budget.toMap(), where: 'id = ?', whereArgs: [budget.id]);
  }

  Future<int> deleteBudget(int id) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  Future<BudgetModel?> getBudgetByCategoryPeriod(String category, String period, int month, int year) async {
    if (kIsWeb) return null;
    final db = await instance.database;
    final result = await db.query(
      'budgets',
      where: 'category = ? AND period = ? AND month = ? AND year = ?',
      whereArgs: [category, period, month, year],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return BudgetModel.fromMap(result.first);
  }

  Future<double> getCategorySpending(String category, DateTime start, DateTime end) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    final result = await db.rawQuery(
      "SELECT SUM(amount) as total FROM transactions WHERE category = ? AND type = 'expense' AND date BETWEEN ? AND ?",
      [category, start.toIso8601String(), end.toIso8601String()]
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<Map<String, double>> getMonthlySummary() async {
    if (kIsWeb) return {'income': 0.0, 'expense': 0.0};
    final db = await instance.database;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59).toIso8601String();

    final inc = await db.rawQuery(
      "SELECT SUM(amount) as total FROM transactions WHERE type = 'income' AND date BETWEEN ? AND ?", 
      [startOfMonth, endOfMonth]
    );
    final exp = await db.rawQuery(
      "SELECT SUM(amount) as total FROM transactions WHERE type = 'expense' AND date BETWEEN ? AND ?", 
      [startOfMonth, endOfMonth]
    );

    return {
      'income': (inc.first['total'] as num?)?.toDouble() ?? 0,
      'expense': (exp.first['total'] as num?)?.toDouble() ?? 0
    };
  }

  // --- Users ---

  Future<int> insertUser(UserModel user) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.insert('users', user.toMap());
  }

  Future<UserModel?> getUserByEmail(String email) async {
    if (kIsWeb) return null;
    final db = await instance.database;
    final result = await db.query('users', where: 'email = ?', whereArgs: [email]);
    if (result.isNotEmpty) return UserModel.fromMap(result.first);
    return null;
  }

  Future<int> updateUser(UserModel user) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
  }

  // --- People ---

  Future<int> insertPerson(PersonModel person) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.insert('people', person.toMap());
  }

  Future<List<PersonModel>> getPeople() async {
    if (kIsWeb) return [];
    final db = await instance.database;
    final result = await db.query('people', orderBy: 'name ASC');
    return result.map((map) => PersonModel.fromMap(map)).toList();
  }

  Future<int> updatePerson(PersonModel person) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.update('people', person.toMap(), where: 'id = ?', whereArgs: [person.id]);
  }

  Future<int> deletePerson(String id) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db.delete('people', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, double>> getPersonSummary(String personId) async {
    if (kIsWeb) return {};
    final db = await instance.database;
    final txs = await db.query('transactions', where: 'personId = ?', whereArgs: [personId]);
    
    double lent = 0;
    double borrowed = 0;
    double repaidReceived = 0;
    double repaidPaid = 0;
    
    for (var row in txs) {
      final type = row['type'] as String;
      final amount = (row['amount'] as num).toDouble();
      if (type == 'lend') {
        lent += amount;
      } else if (type == 'borrow') borrowed += amount;
      else if (type == 'repayment_received') repaidReceived += amount;
      else if (type == 'repayment_paid') repaidPaid += amount;
    }
    
    return {
      'lent': lent,
      'borrowed': borrowed,
      'repaidReceived': repaidReceived,
      'repaidPaid': repaidPaid,
      'netBalance': (lent - repaidReceived) - (borrowed - repaidPaid),
    };
  }
}
