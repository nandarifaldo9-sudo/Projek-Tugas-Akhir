import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

class DatabaseHelper {
  DatabaseHelper({this.factory, this.databasePath});

  static final DatabaseHelper instance = DatabaseHelper._();

  DatabaseHelper._() : factory = null, databasePath = null;

  final DatabaseFactory? factory;
  final String? databasePath;
  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final databaseFactoryInstance = factory ?? databaseFactory;
    final path =
        databasePath ??
        join(await databaseFactoryInstance.getDatabasesPath(), 'flowly.db');
    return databaseFactoryInstance.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
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
    if (oldVersion < 3) {
      await db.execute('''
        ALTER TABLE transactions ADD COLUMN recurring_rule_id INTEGER
          REFERENCES recurring_rules(id) ON DELETE SET NULL
      ''');
      await db.execute('''
        ALTER TABLE transactions ADD COLUMN occurrence_date TEXT
      ''');
      await _createFeatureTables(db);
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
        note TEXT NOT NULL DEFAULT '',
        recurring_rule_id INTEGER REFERENCES recurring_rules(id) ON DELETE SET NULL,
        occurrence_date TEXT
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

    await _createFeatureTables(db);

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

  Future<void> _createFeatureTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS category_budgets (
        category_id INTEGER PRIMARY KEY REFERENCES categories(id) ON DELETE CASCADE,
        amount INTEGER NOT NULL CHECK (amount > 0)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS budget_warnings (
        category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
        month TEXT NOT NULL,
        PRIMARY KEY (category_id, month)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recurring_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL CHECK (amount > 0),
        account_id INTEGER NOT NULL REFERENCES accounts(id),
        to_account_id INTEGER REFERENCES accounts(id),
        category_id INTEGER REFERENCES categories(id),
        frequency TEXT NOT NULL CHECK (frequency IN ('weekly', 'monthly')),
        start_date TEXT NOT NULL,
        next_date TEXT NOT NULL,
        day_of_month INTEGER NOT NULL CHECK (day_of_month BETWEEN 1 AND 31),
        note TEXT NOT NULL DEFAULT '',
        enabled INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS recurring_occurrence_unique
      ON transactions(recurring_rule_id, occurrence_date)
      WHERE recurring_rule_id IS NOT NULL AND occurrence_date IS NOT NULL
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_withdrawals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
        account_id INTEGER NOT NULL REFERENCES accounts(id),
        amount INTEGER NOT NULL CHECK (amount > 0),
        date TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      )
    ''');
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
    return db.update('accounts', a.toMap(), where: 'id = ?', whereArgs: [a.id]);
  }

  Future<bool> isAccountUsed(int id) async {
    final db = await database;
    final txCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM transactions '
            'WHERE account_id = ? OR to_account_id = ?',
            [id, id],
          ),
        ) ??
        0;
    if (txCount > 0) return true;
    final depCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM deposits WHERE account_id = ?',
            [id],
          ),
        ) ??
        0;
    if (depCount > 0) return true;
    final withdrawalCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM goal_withdrawals WHERE account_id = ?',
            [id],
          ),
        ) ??
        0;
    if (withdrawalCount > 0) return true;
    final ruleCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM recurring_rules '
            'WHERE account_id = ? OR to_account_id = ?',
            [id, id],
          ),
        ) ??
        0;
    return ruleCount > 0;
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
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM transactions WHERE category_id = ?',
            [id],
          ),
        ) ??
        0;
    if (count > 0) return true;
    final budgetCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM category_budgets WHERE category_id = ?',
            [id],
          ),
        ) ??
        0;
    if (budgetCount > 0) return true;
    final ruleCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM recurring_rules WHERE category_id = ?',
            [id],
          ),
        ) ??
        0;
    return ruleCount > 0;
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
    return db.delete('transactions', where: 'id = ?', whereArgs: [id]);
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
    return db.update('goals', g.toMap(), where: 'id = ?', whereArgs: [g.id]);
  }

  Future<int> deleteGoal(int id) async {
    final db = await database;
    return db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> restoreGoal(
    Goal goal,
    List<GoalDeposit> goalDeposits, [
    List<GoalWithdrawal> goalWithdrawals = const [],
  ]) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('goals', goal.toMap());
      for (final deposit in goalDeposits) {
        await txn.insert('deposits', deposit.toMap());
      }
      for (final withdrawal in goalWithdrawals) {
        await txn.insert('goal_withdrawals', withdrawal.toMap());
      }
    });
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

  Future<int> updateDeposit(GoalDeposit d) async {
    final db = await database;
    return db.update('deposits', d.toMap(), where: 'id = ?', whereArgs: [d.id]);
  }

  Future<int> deleteDeposit(int id) async {
    final db = await database;
    return db.delete('deposits', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<GoalWithdrawal>> getWithdrawals() async {
    final db = await database;
    final rows = await db.query(
      'goal_withdrawals',
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(GoalWithdrawal.fromMap).toList();
  }

  Future<int> insertWithdrawal(GoalWithdrawal w) async {
    final db = await database;
    return db.insert('goal_withdrawals', w.toMap());
  }

  Future<int> updateWithdrawal(GoalWithdrawal w) async {
    final db = await database;
    return db.update(
      'goal_withdrawals',
      w.toMap(),
      where: 'id = ?',
      whereArgs: [w.id],
    );
  }

  Future<int> deleteWithdrawal(int id) async {
    final db = await database;
    return db.delete('goal_withdrawals', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<CategoryBudget>> getBudgets() async {
    final db = await database;
    final rows = await db.query('category_budgets', orderBy: 'category_id');
    return rows.map(CategoryBudget.fromMap).toList();
  }

  Future<void> saveBudget(CategoryBudget budget) async {
    final db = await database;
    await db.insert(
      'category_budgets',
      budget.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteBudget(int categoryId) async {
    final db = await database;
    await db.delete(
      'category_budgets',
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );
  }

  Future<bool> hasBudgetWarning(int categoryId, String month) async {
    final db = await database;
    final rows = await db.query(
      'budget_warnings',
      where: 'category_id = ? AND month = ?',
      whereArgs: [categoryId, month],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> markBudgetWarning(int categoryId, String month) async {
    final db = await database;
    await db.insert('budget_warnings', {
      'category_id': categoryId,
      'month': month,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<RecurringRule>> getRecurringRules() async {
    final db = await database;
    final rows = await db.query('recurring_rules', orderBy: 'id DESC');
    return rows.map(RecurringRule.fromMap).toList();
  }

  Future<int> saveRecurringRule(RecurringRule rule) async {
    final db = await database;
    if (rule.id == null) return db.insert('recurring_rules', rule.toMap());
    return db.update(
      'recurring_rules',
      rule.toMap(),
      where: 'id = ?',
      whereArgs: [rule.id],
    );
  }

  Future<int> deleteRecurringRule(int id) async {
    final db = await database;
    return db.delete('recurring_rules', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> materializeDueRecurring(DateTime throughDate) async {
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'recurring_rules',
        where: 'enabled = 1',
        orderBy: 'id',
      );
      var inserted = 0;
      final through = DateTime(
        throughDate.year,
        throughDate.month,
        throughDate.day,
      );
      for (final row in rows) {
        var rule = RecurringRule.fromMap(row);
        while (!_dateOnly(rule.nextDate).isAfter(through)) {
          final occurrence = _dateOnly(rule.nextDate);
          final result = await txn.insert('transactions', {
            'type': rule.type.name,
            'amount': rule.amount,
            'account_id': rule.accountId,
            'to_account_id': rule.toAccountId,
            'category_id': rule.categoryId,
            'date': dateKey(occurrence),
            'note': rule.note,
            'recurring_rule_id': rule.id,
            'occurrence_date': dateKey(occurrence),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          if (result != 0) inserted++;
          final next = _nextOccurrence(rule, occurrence);
          await txn.update(
            'recurring_rules',
            {'next_date': dateKey(next)},
            where: 'id = ?',
            whereArgs: [rule.id],
          );
          rule = RecurringRule(
            id: rule.id,
            type: rule.type,
            amount: rule.amount,
            accountId: rule.accountId,
            toAccountId: rule.toAccountId,
            categoryId: rule.categoryId,
            frequency: rule.frequency,
            startDate: rule.startDate,
            nextDate: next,
            dayOfMonth: rule.dayOfMonth,
            note: rule.note,
            enabled: rule.enabled,
          );
        }
      }
      return inserted;
    });
  }

  DateTime _nextOccurrence(RecurringRule rule, DateTime current) {
    if (rule.frequency == RecurrenceFrequency.weekly) {
      return current.add(const Duration(days: 7));
    }
    final nextMonth = DateTime(current.year, current.month + 1);
    final lastDay = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
    return DateTime(
      nextMonth.year,
      nextMonth.month,
      rule.dayOfMonth.clamp(1, lastDay).toInt(),
    );
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
