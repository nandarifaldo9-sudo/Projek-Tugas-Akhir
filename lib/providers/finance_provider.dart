import 'package:flutter/foundation.dart' hide Category;
import 'package:sqflite/sqflite.dart' show DatabaseException;

import '../data/database_helper.dart';
import '../models/models.dart';
import '../services/finances_service.dart';

class FinanceProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<Account> accounts = [];
  List<Category> categories = [];
  List<AppTransaction> transactions = [];
  List<Goal> goals = [];
  List<GoalDeposit> deposits = [];
  bool loading = true;
  String? error;

  Future<void> load() async {
    try {
      accounts = await _db.getAccounts();
      categories = await _db.getCategories();
      transactions = await _db.getTransactions();
      goals = await _db.getGoals();
      deposits = await _db.getDeposits();
      error = null;
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  /// Memicu layar menghitung ulang bagian yang bergantung pada jam
  /// (sapaan, "bulan ini"). Dipanggil saat jam atau tanggal berganti.
  void refreshClock() => notifyListeners();

  // ---------- Transaksi ----------

  Future<void> addTransaction(AppTransaction t) async {
    await _db.insertTransaction(t);
    await load();
  }

  Future<void> updateTransaction(AppTransaction t) async {
    await _db.updateTransaction(t);
    await load();
  }

  Future<void> deleteTransaction(int id) async {
    await _db.deleteTransaction(id);
    await load();
  }

  // ---------- Akun (mengembalikan pesan error, atau null bila berhasil) ----------

  Future<String?> saveAccount(Account a) async {
    try {
      if (a.id == null) {
        await _db.insertAccount(a);
      } else {
        await _db.updateAccount(a);
      }
    } on DatabaseException catch (e) {
      return e.isUniqueConstraintError()
          ? 'Nama akun sudah dipakai.'
          : 'Gagal menyimpan akun.';
    }
    await load();
    return null;
  }

  Future<String?> deleteAccount(int id) async {
    if (accounts.length <= 1) return 'Minimal harus ada satu akun.';
    if (await _db.isAccountUsed(id)) {
      return 'Akun ini sudah dipakai transaksi atau setoran target, '
          'jadi tidak bisa dihapus.';
    }
    await _db.deleteAccount(id);
    await load();
    return null;
  }

  // ---------- Kategori ----------

  Future<String?> saveCategory(Category c) async {
    try {
      if (c.id == null) {
        await _db.insertCategory(c);
      } else {
        await _db.updateCategory(c);
      }
    } on DatabaseException catch (e) {
      return e.isUniqueConstraintError()
          ? 'Nama kategori sudah ada.'
          : 'Gagal menyimpan kategori.';
    }
    await load();
    return null;
  }

  Future<String?> deleteCategory(Category c) async {
    final sameType = categories.where((x) => x.type == c.type).length;
    if (sameType <= 1) {
      final label = c.type == TxType.income ? 'pemasukan' : 'pengeluaran';
      return 'Minimal harus ada satu kategori $label.';
    }
    if (await _db.isCategoryUsed(c.id!)) {
      return 'Kategori ini sudah dipakai transaksi, jadi tidak bisa dihapus.';
    }
    await _db.deleteCategory(c.id!);
    await load();
    return null;
  }

  // ---------- Target dan setoran ----------

  Future<void> saveGoal(Goal g) async {
    if (g.id == null) {
      await _db.insertGoal(g);
    } else {
      await _db.updateGoal(g);
    }
    await load();
  }

  Future<void> deleteGoal(int id) async {
    await _db.deleteGoal(id);
    await load();
  }

  Future<void> addDeposit(GoalDeposit d) async {
    await _db.insertDeposit(d);
    await load();
  }

  Future<void> deleteDeposit(int id) async {
    await _db.deleteDeposit(id);
    await load();
  }

  Goal? goalById(int id) {
    for (final g in goals) {
      if (g.id == id) return g;
    }
    return null;
  }

  int savedFor(int goalId) => FinanceService.savedForGoal(goalId, deposits);

  List<GoalDeposit> depositsFor(int goalId) =>
      deposits.where((d) => d.goalId == goalId).toList();

  // ---------- Perhitungan ----------

  int get totalBalance =>
      FinanceService.totalBalance(accounts, transactions, deposits);

  int balanceOf(Account a) =>
      FinanceService.accountBalance(a, transactions, deposits);

  int incomeThisMonth() => incomeInMonth(DateTime.now());

  int expenseThisMonth() => expenseInMonth(DateTime.now());

  int incomeInMonth(DateTime month) =>
      FinanceService.incomeInMonth(transactions, month);

  int expenseInMonth(DateTime month) =>
      FinanceService.expenseInMonth(transactions, month);

  Map<int, int> expenseByCategory(DateTime month) =>
      FinanceService.expenseByCategory(transactions, month);

  List<MonthTotal> monthlyTotals(DateTime endMonth) =>
      FinanceService.monthlyTotals(transactions, endMonth);

  // ---------- Nama untuk tampilan ----------

  String accountName(int? id) {
    for (final a in accounts) {
      if (a.id == id) return a.name;
    }
    return '-';
  }

  String categoryName(int? id) {
    for (final c in categories) {
      if (c.id == id) return c.name;
    }
    return '-';
  }

  String goalName(int? id) {
    for (final g in goals) {
      if (g.id == id) return g.name;
    }
    return '-';
  }
}