import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'flowly.db');
    return openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS goals (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          target_amount INTEGER NOT NULL CHECK (target_amount > 0),
          target_date TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS deposits (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          goal_id INTEGER NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
          account_id INTEGER NOT NULL REFERENCES accounts(id),
          amount INTEGER NOT NULL CHECK (amount > 0),
          date TEXT NOT NULL,
          note TEXT NOT NULL DEFAULT ''
        )
      ''');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        initial_balance INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        UNIQUE (name, type)
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL CHECK (amount > 0),
        account_id INTEGER NOT NULL REFERENCES accounts(id),
        to_account_id INTEGER REFERENCES accounts(id),
        category_id INTEGER REFERENCES categories(id),
        date TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        target_amount INTEGER NOT NULL CHECK (target_amount > 0),
        target_date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE deposits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
        account_id INTEGER NOT NULL REFERENCES accounts(id),
        amount INTEGER NOT NULL CHECK (amount > 0),
        date TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      )
    ''');

    // Data awal: akun Tunai dan Bank, serta kategori bawaan.
    final batch = db.batch();
    for (final name in ['Tunai', 'Bank']) {
      batch.insert('accounts', {'name': name, 'initial_balance': 0});
    }
    const expense = [
      'Makanan',
      'Transport',
      'Belanja',
      'Tagihan',
      'Hiburan',
      'Kesehatan',
      'Pendidikan',
      'Lainnya',
    ];
    const income = ['Gaji', 'Bonus', 'Lainnya'];
    for (final n in expense) {
      batch.insert('categories', {'name': n, 'type': TxType.expense.name});
    }
    for (final n in income) {
      batch.insert('categories', {'name': n, 'type': TxType.income.name});
    }
    await batch.commit(noResult: true);
  }

  // ---------- Accounts ----------

  Future<List<Account>> getAccounts() async {
    final db = await database;
    final rows = await db.query('accounts', orderBy: 'id');
    return rows.map(Account.fromMap).toList();
  }

  Future<int> insertAccount(Account a) async {
    final db = await database;
    return db.insert('accounts', a.toMap());
  }

  Future<int> updateAccount(Account a) async {
    final db = await database;
    return db.update(
      'accounts',
      a.toMap(),
      where: 'id = ?',
      whereArgs: [a.id],
    );
  }

  Future<bool> isAccountUsed(int id) async {
    final db = await database;
    final txCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM transactions WHERE account_id = ?',
      [id],
    )) ?? 0;
    if (txCount > 0) return true;
    final depCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM deposits WHERE account_id = ?',
      [id],
    )) ?? 0;
    return depCount > 0;
  }

  Future<int> deleteAccount(int id) async {
    final db = await database;
    return db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Categories ----------

  Future<List<Category>> getCategories() async {
    final db = await database;
    final rows = await db.query('categories', orderBy: 'id');
    return rows.map(Category.fromMap).toList();
  }

  Future<int> insertCategory(Category c) async {
    final db = await database;
    return db.insert('categories', c.toMap());
  }

  Future<int> updateCategory(Category c) async {
    final db = await database;
    return db.update(
      'categories',
      c.toMap(),
      where: 'id = ?',
      whereArgs: [c.id],
    );
  }

  Future<bool> isCategoryUsed(int id) async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM transactions WHERE category_id = ?',
      [id],
    )) ?? 0;
    return count > 0;
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Transactions ----------

  Future<List<AppTransaction>> getTransactions() async {
    final db = await database;
    final rows = await db.query('transactions', orderBy: 'date DESC, id DESC');
    return rows.map(AppTransaction.fromMap).toList();
  }

  Future<int> insertTransaction(AppTransaction t) async {
    final db = await database;
    return db.insert('transactions', t.toMap());
  }

  Future<int> updateTransaction(AppTransaction t) async {
    final db = await database;
    return db.update(
      'transactions',
      t.toMap(),
      where: 'id = ?',
      whereArgs: [t.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------- Goals ----------

  Future<List<Goal>> getGoals() async {
    final db = await database;
    final rows = await db.query('goals', orderBy: 'id DESC');
    return rows.map(Goal.fromMap).toList();
  }

  Future<int> insertGoal(Goal g) async {
    final db = await database;
    return db.insert('goals', g.toMap());
  }

  Future<int> updateGoal(Goal g) async {
    final db = await database;
    return db.update(
      'goals',
      g.toMap(),
      where: 'id = ?',
      whereArgs: [g.id],
    );
  }

  Future<int> deleteGoal(int id) async {
    final db = await database;
    return db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Deposits ----------

  Future<List<GoalDeposit>> getDeposits() async {
    final db = await database;
    final rows = await db.query('deposits', orderBy: 'date DESC, id DESC');
    return rows.map(GoalDeposit.fromMap).toList();
  }

  Future<int> insertDeposit(GoalDeposit d) async {
    final db = await database;
    return db.insert('deposits', d.toMap());
  }

  Future<int> deleteDeposit(int id) async {
    final db = await database;
    return db.delete('deposits', where: 'id = ?', whereArgs: [id]);
  }
}
