import 'dart:collection';

import 'package:flutter/foundation.dart' hide Category;
import 'package:sqflite/sqflite.dart' show DatabaseException;

import '../data/database_helper.dart';
import '../models/models.dart';
import '../services/finances_service.dart';

class FinanceProvider extends ChangeNotifier {
  FinanceProvider({DatabaseHelper? database})
    : _db = database ?? DatabaseHelper.instance;

  final DatabaseHelper _db;
  List<Account> _accounts = [];
  List<Category> _categories = [];
  List<AppTransaction> _transactions = [];
  List<Goal> _goals = [];
  List<GoalDeposit> _deposits = [];
  List<GoalWithdrawal> _withdrawals = [];
  List<CategoryBudget> _budgets = [];
  List<RecurringRule> _recurringRules = [];
  final List<int> _newBudgetAlerts = [];

  List<Account> get accounts => UnmodifiableListView(_accounts);
  List<Category> get categories => UnmodifiableListView(_categories);
  List<AppTransaction> get transactions => UnmodifiableListView(_transactions);
  List<Goal> get goals => UnmodifiableListView(_goals);
  List<GoalDeposit> get deposits => UnmodifiableListView(_deposits);
  List<GoalWithdrawal> get withdrawals => UnmodifiableListView(_withdrawals);
  List<CategoryBudget> get budgets => UnmodifiableListView(_budgets);
  List<RecurringRule> get recurringRules =>
      UnmodifiableListView(_recurringRules);

  int budgetWarnPercent = 80;
  int? defaultAccountId;

  void applySettings({
    required int budgetWarnPercent,
    required int? defaultAccountId,
  }) {
    this.budgetWarnPercent = budgetWarnPercent;
    this.defaultAccountId = defaultAccountId;
  }

  Account? get defaultAccount {
    for (final a in _accounts) {
      if (a.id == defaultAccountId) return a;
    }
    return _accounts.isEmpty ? null : _accounts.first;
  }

  bool loading = true;
  String? error;

  Future<void> load() async {
    String? recurringError;
    try {
      await _db.materializeDueRecurring(DateTime.now());
    } on DatabaseException {
      recurringError = 'Gagal memproses transaksi berulang.';
    }
    await _refresh(
      accounts: true,
      categories: true,
      transactions: true,
      goals: true,
      deposits: true,
      withdrawals: true,
      budgets: true,
      recurringRules: true,
    );
    if (recurringError != null && error == null) {
      error = recurringError;
      notifyListeners();
    }
    await _checkBudgetWarnings();
  }

  Future<void> _refresh({
    bool accounts = false,
    bool categories = false,
    bool transactions = false,
    bool goals = false,
    bool deposits = false,
    bool withdrawals = false,
    bool budgets = false,
    bool recurringRules = false,
  }) async {
    try {
      if (accounts) _accounts = await _db.getAccounts();
      if (categories) _categories = await _db.getCategories();
      if (transactions) _transactions = await _db.getTransactions();
      if (goals) _goals = await _db.getGoals();
      if (deposits) _deposits = await _db.getDeposits();
      if (withdrawals) _withdrawals = await _db.getWithdrawals();
      if (budgets) _budgets = await _db.getBudgets();
      if (recurringRules) _recurringRules = await _db.getRecurringRules();
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

  String? _validateTransaction(AppTransaction t) {
    if (t.amount <= 0) return 'Nominal harus lebih dari 0.';
    if (!_accounts.any((a) => a.id == t.accountId)) {
      return 'Akun asal tidak ditemukan.';
    }
    if (t.type == TxType.transfer) {
      if (t.toAccountId == null ||
          !_accounts.any((a) => a.id == t.toAccountId)) {
        return 'Pilih akun tujuan transfer.';
      }
      if (t.toAccountId == t.accountId) {
        return 'Akun asal dan tujuan harus berbeda.';
      }
      if (t.categoryId != null) {
        return 'Transfer tidak menggunakan kategori.';
      }
    } else {
      final category = _categories.where((c) => c.id == t.categoryId);
      if (category.isEmpty || category.first.type != t.type) {
        return 'Pilih kategori yang sesuai dengan jenis transaksi.';
      }
      if (t.toAccountId != null) {
        return 'Transaksi ini tidak memiliki akun tujuan.';
      }
    }
    return null;
  }

  Future<String?> addTransaction(AppTransaction t) async {
    final validationError = _validateTransaction(t);
    if (validationError != null) return validationError;
    try {
      await _db.insertTransaction(t);
    } on DatabaseException {
      return 'Gagal menyimpan transaksi.';
    }
    await _refresh(transactions: true);
    await _checkBudgetWarnings();
    return null;
  }

  Future<String?> updateTransaction(AppTransaction t) async {
    final validationError = _validateTransaction(t);
    if (validationError != null) return validationError;
    try {
      final count = await _db.updateTransaction(t);
      if (count == 0) return 'Transaksi tidak ditemukan.';
    } on DatabaseException {
      return 'Gagal mengubah transaksi.';
    }
    await _refresh(transactions: true);
    await _checkBudgetWarnings();
    return null;
  }

  Future<String?> deleteTransaction(int id) async {
    try {
      final count = await _db.deleteTransaction(id);
      if (count == 0) return 'Transaksi tidak ditemukan.';
    } on DatabaseException {
      return 'Gagal menghapus transaksi.';
    }
    await _refresh(transactions: true);
    await _checkBudgetWarnings();
    return null;
  }

  int balanceBeforeTransaction(Account account, int? transactionId) {
    final transactions = _transactions
        .where((transaction) => transaction.id != transactionId)
        .toList();
    return FinanceService.accountBalance(
      account,
      transactions,
      _deposits,
      withdrawals: _withdrawals,
    );
  }

  // ---------- Akun (mengembalikan pesan error, atau null bila berhasil) ----------

  Future<String?> saveAccount(Account a) async {
    if (a.name.trim().isEmpty) return 'Nama akun wajib diisi.';
    try {
      if (a.id == null) {
        await _db.insertAccount(a);
      } else {
        final count = await _db.updateAccount(a);
        if (count == 0) return 'Akun tidak ditemukan.';
      }
    } on DatabaseException catch (e) {
      return e.isUniqueConstraintError()
          ? 'Nama akun sudah dipakai.'
          : 'Gagal menyimpan akun.';
    }
    await _refresh(accounts: true);
    return null;
  }

  Future<String?> restoreAccount(Account account) async {
    try {
      await _db.insertAccount(account);
    } on DatabaseException catch (e) {
      return e.isUniqueConstraintError()
          ? 'Akun tidak dapat dipulihkan karena namanya sudah dipakai.'
          : 'Gagal memulihkan akun.';
    }
    await _refresh(accounts: true);
    return null;
  }

  Future<String?> deleteAccount(int id) async {
    if (_accounts.length <= 1) return 'Minimal harus ada satu akun.';
    try {
      if (await _db.isAccountUsed(id)) {
        return 'Akun ini sudah dipakai transaksi, target, atau jadwal berulang, '
            'jadi tidak bisa dihapus.';
      }
      final count = await _db.deleteAccount(id);
      if (count == 0) return 'Akun tidak ditemukan.';
    } on DatabaseException {
      return 'Gagal menghapus akun.';
    }
    await _refresh(accounts: true);
    return null;
  }

  // ---------- Kategori ----------

  Future<String?> saveCategory(Category c) async {
    if (c.name.trim().isEmpty) return 'Nama kategori wajib diisi.';
    try {
      if (c.id == null) {
        await _db.insertCategory(c);
      } else {
        final count = await _db.updateCategory(c);
        if (count == 0) return 'Kategori tidak ditemukan.';
      }
    } on DatabaseException catch (e) {
      return e.isUniqueConstraintError()
          ? 'Nama kategori sudah ada.'
          : 'Gagal menyimpan kategori.';
    }
    await _refresh(categories: true);
    return null;
  }

  Future<String?> restoreCategory(Category category) async {
    try {
      await _db.insertCategory(category);
    } on DatabaseException catch (e) {
      return e.isUniqueConstraintError()
          ? 'Kategori tidak dapat dipulihkan karena namanya sudah dipakai.'
          : 'Gagal memulihkan kategori.';
    }
    await _refresh(categories: true);
    return null;
  }

  Future<String?> deleteCategory(Category c) async {
    final sameType = _categories.where((x) => x.type == c.type).length;
    if (sameType <= 1) {
      final label = c.type == TxType.income ? 'pemasukan' : 'pengeluaran';
      return 'Minimal harus ada satu kategori $label.';
    }
    try {
      if (await _db.isCategoryUsed(c.id!)) {
        return 'Kategori ini sudah dipakai transaksi, anggaran, atau jadwal '
            'berulang, jadi tidak bisa dihapus.';
      }
      final count = await _db.deleteCategory(c.id!);
      if (count == 0) return 'Kategori tidak ditemukan.';
    } on DatabaseException {
      return 'Gagal menghapus kategori.';
    }
    await _refresh(categories: true, budgets: true);
    return null;
  }

  // ---------- Target dan setoran ----------

  Future<String?> saveGoal(Goal g) async {
    if (g.name.trim().isEmpty) return 'Nama target wajib diisi.';
    if (g.targetAmount <= 0) return 'Nominal target harus lebih dari 0.';
    try {
      if (g.id == null) {
        await _db.insertGoal(g);
      } else {
        final count = await _db.updateGoal(g);
        if (count == 0) return 'Target tidak ditemukan.';
      }
    } on DatabaseException {
      return 'Gagal menyimpan target.';
    }
    await _refresh(goals: true);
    return null;
  }

  Future<String?> deleteGoal(int id) async {
    try {
      final count = await _db.deleteGoal(id);
      if (count == 0) return 'Target tidak ditemukan.';
    } on DatabaseException {
      return 'Gagal menghapus target.';
    }
    await _refresh(goals: true, deposits: true, withdrawals: true);
    return null;
  }

  Future<String?> restoreGoal(
    Goal goal,
    List<GoalDeposit> goalDeposits, [
    List<GoalWithdrawal> goalWithdrawals = const [],
  ]) async {
    try {
      await _db.restoreGoal(goal, goalDeposits, goalWithdrawals);
    } on DatabaseException {
      return 'Target tidak dapat dipulihkan.';
    }
    await _refresh(goals: true, deposits: true, withdrawals: true);
    return null;
  }

  Future<String?> addDeposit(GoalDeposit d) async {
    if (d.amount <= 0) return 'Nominal setoran harus lebih dari 0.';
    if (!_accounts.any((a) => a.id == d.accountId)) {
      return 'Akun setoran tidak ditemukan.';
    }
    if (!_goals.any((g) => g.id == d.goalId)) {
      return 'Target tidak ditemukan.';
    }
    try {
      await _db.insertDeposit(d);
    } on DatabaseException {
      return 'Gagal menyimpan setoran.';
    }
    await _refresh(deposits: true);
    return null;
  }

  Future<String?> updateDeposit(GoalDeposit d) async {
    if (d.amount <= 0) return 'Nominal setoran harus lebih dari 0.';
    if (!_accounts.any((a) => a.id == d.accountId)) {
      return 'Akun setoran tidak ditemukan.';
    }
    if (!_goals.any((g) => g.id == d.goalId)) {
      return 'Target tidak ditemukan.';
    }
    final otherDeposits = _deposits.where((item) => item.id != d.id).toList();
    if (!_hasValidGoalHistory(d.goalId, [...otherDeposits, d], _withdrawals)) {
      return 'Setoran ini membuat riwayat penarikan melebihi saldo target.';
    }
    try {
      final count = await _db.updateDeposit(d);
      if (count == 0) return 'Setoran tidak ditemukan.';
    } on DatabaseException {
      return 'Gagal mengubah setoran.';
    }
    await _refresh(deposits: true);
    return null;
  }

  Future<String?> deleteDeposit(int id) async {
    GoalDeposit? deposit;
    for (final item in _deposits) {
      if (item.id == id) {
        deposit = item;
        break;
      }
    }
    if (deposit != null &&
        !_hasValidGoalHistory(
          deposit.goalId,
          _deposits.where((item) => item.id != id).toList(),
          _withdrawals,
        )) {
      return 'Setoran ini diperlukan untuk menutup riwayat penarikan.';
    }
    try {
      final count = await _db.deleteDeposit(id);
      if (count == 0) return 'Setoran tidak ditemukan.';
    } on DatabaseException {
      return 'Gagal menghapus setoran.';
    }
    await _refresh(deposits: true);
    return null;
  }

  Future<String?> addWithdrawal(GoalWithdrawal w) async {
    final validationError = _validateWithdrawal(w);
    if (validationError != null) return validationError;
    try {
      await _db.insertWithdrawal(w);
    } on DatabaseException {
      return 'Gagal menyimpan penarikan.';
    }
    await _refresh(withdrawals: true);
    return null;
  }

  Future<String?> updateWithdrawal(GoalWithdrawal w) async {
    final validationError = _validateWithdrawal(w);
    if (validationError != null) return validationError;
    try {
      final count = await _db.updateWithdrawal(w);
      if (count == 0) return 'Penarikan tidak ditemukan.';
    } on DatabaseException {
      return 'Gagal mengubah penarikan.';
    }
    await _refresh(withdrawals: true);
    return null;
  }

  String? _validateWithdrawal(GoalWithdrawal w) {
    if (w.amount <= 0) return 'Nominal penarikan harus lebih dari 0.';
    if (!_accounts.any((a) => a.id == w.accountId)) {
      return 'Akun tujuan penarikan tidak ditemukan.';
    }
    if (!_goals.any((g) => g.id == w.goalId)) {
      return 'Target tidak ditemukan.';
    }
    final otherWithdrawals = _withdrawals
        .where((item) => item.id != w.id)
        .toList();
    if (!_hasValidGoalHistory(w.goalId, _deposits, [...otherWithdrawals, w])) {
      return 'Penarikan melebihi saldo target yang tersedia pada tanggal itu.';
    }
    return null;
  }

  bool _hasValidGoalHistory(
    int goalId,
    List<GoalDeposit> deposits,
    List<GoalWithdrawal> withdrawals,
  ) {
    final movements =
        <(DateTime, int)>[
          for (final deposit in deposits)
            if (deposit.goalId == goalId) (deposit.date, deposit.amount),
          for (final withdrawal in withdrawals)
            if (withdrawal.goalId == goalId)
              (withdrawal.date, -withdrawal.amount),
        ]..sort((a, b) {
          final byDate = DateTime(
            a.$1.year,
            a.$1.month,
            a.$1.day,
          ).compareTo(DateTime(b.$1.year, b.$1.month, b.$1.day));
          return byDate != 0 ? byDate : b.$2.compareTo(a.$2);
        });
    var balance = 0;
    for (final movement in movements) {
      balance += movement.$2;
      if (balance < 0) return false;
    }
    return true;
  }

  Future<String?> deleteWithdrawal(int id) async {
    try {
      final count = await _db.deleteWithdrawal(id);
      if (count == 0) return 'Penarikan tidak ditemukan.';
    } on DatabaseException {
      return 'Gagal menghapus penarikan.';
    }
    await _refresh(withdrawals: true);
    return null;
  }

  Future<String?> saveBudget(CategoryBudget budget) async {
    if (budget.amount <= 0) return 'Nominal anggaran harus lebih dari 0.';
    if (!_categories.any(
      (c) => c.id == budget.categoryId && c.type == TxType.expense,
    )) {
      return 'Pilih kategori pengeluaran yang valid.';
    }
    try {
      await _db.saveBudget(budget);
    } on DatabaseException {
      return 'Gagal menyimpan anggaran.';
    }
    await _refresh(budgets: true);
    await _checkBudgetWarnings();
    return null;
  }

  Future<String?> deleteBudget(int categoryId) async {
    try {
      await _db.deleteBudget(categoryId);
    } on DatabaseException {
      return 'Gagal menghapus anggaran.';
    }
    await _refresh(budgets: true);
    return null;
  }

  Future<String?> resetAllData() async {
    try {
      await _db.deleteAllData();
    } on DatabaseException {
      return 'Gagal menghapus data.';
    }
    _newBudgetAlerts.clear();
    await _refresh(
      accounts: true,
      categories: true,
      transactions: true,
      goals: true,
      deposits: true,
      withdrawals: true,
      budgets: true,
      recurringRules: true,
    );
    return null;
  }

  Future<String?> saveRecurringRule(RecurringRule rule) async {
    if (rule.amount <= 0) return 'Nominal harus lebih dari 0.';
    final error = _validateTransaction(
      AppTransaction(
        type: rule.type,
        amount: rule.amount,
        accountId: rule.accountId,
        toAccountId: rule.toAccountId,
        categoryId: rule.categoryId,
        date: rule.nextDate,
      ),
    );
    if (error != null) return error;
    try {
      await _db.saveRecurringRule(rule);
      await _db.materializeDueRecurring(DateTime.now());
    } on DatabaseException {
      return 'Gagal menyimpan transaksi berulang.';
    }
    await _refresh(recurringRules: true, transactions: true);
    await _checkBudgetWarnings();
    return null;
  }

  Future<String?> deleteRecurringRule(int id) async {
    try {
      final count = await _db.deleteRecurringRule(id);
      if (count == 0) return 'Jadwal tidak ditemukan.';
    } on DatabaseException {
      return 'Gagal menghapus jadwal berulang.';
    }
    await _refresh(recurringRules: true);
    return null;
  }

  Future<String?> toggleRecurringRule(RecurringRule rule, bool enabled) async {
    try {
      await _db.saveRecurringRule(
        RecurringRule(
          id: rule.id,
          type: rule.type,
          amount: rule.amount,
          accountId: rule.accountId,
          toAccountId: rule.toAccountId,
          categoryId: rule.categoryId,
          frequency: rule.frequency,
          startDate: rule.startDate,
          nextDate: rule.nextDate,
          dayOfMonth: rule.dayOfMonth,
          note: rule.note,
          enabled: enabled,
        ),
      );
      if (enabled) await _db.materializeDueRecurring(DateTime.now());
    } on DatabaseException {
      return 'Gagal mengubah status transaksi berulang.';
    }
    await _refresh(recurringRules: true, transactions: enabled);
    if (enabled) await _checkBudgetWarnings();
    return null;
  }

  Goal? goalById(int id) {
    for (final g in goals) {
      if (g.id == id) return g;
    }
    return null;
  }

  int savedFor(int goalId) =>
      FinanceService.savedForGoal(goalId, deposits, withdrawals: withdrawals);

  List<GoalDeposit> depositsFor(int goalId) =>
      deposits.where((d) => d.goalId == goalId).toList();

  List<GoalWithdrawal> withdrawalsFor(int goalId) =>
      withdrawals.where((w) => w.goalId == goalId).toList();

  int budgetFor(int categoryId) => budgets
      .where((budget) => budget.categoryId == categoryId)
      .fold(0, (sum, budget) => sum + budget.amount);

  int spentForCategory(int categoryId, DateTime month) =>
      expenseByCategory(month)[categoryId] ?? 0;

  int monthlyGoalContribution(Goal goal, {DateTime? from}) {
    final date = goal.targetDate;
    if (date == null) return 0;
    final today = from ?? DateTime.now();
    if (date.isBefore(DateTime(today.year, today.month, today.day))) return 0;
    final months = (date.year - today.year) * 12 + date.month - today.month + 1;
    if (months <= 0) return 0;
    final remaining = goal.targetAmount - savedFor(goal.id!);
    if (remaining <= 0) return 0;
    return (remaining + months - 1) ~/ months;
  }

  List<int> takeBudgetAlerts() {
    final alerts = List<int>.of(_newBudgetAlerts);
    _newBudgetAlerts.clear();
    return alerts;
  }

  Future<void> _checkBudgetWarnings() async {
    final now = DateTime.now();
    final month = dateKey(DateTime(now.year, now.month));
    var changed = false;
    for (final budget in _budgets) {
      final spent = spentForCategory(budget.categoryId, now);
      if (spent < (budget.amount * budgetWarnPercent + 99) ~/ 100) continue;
      if (await _db.hasBudgetWarning(budget.categoryId, month)) continue;
      await _db.markBudgetWarning(budget.categoryId, month);
      _newBudgetAlerts.add(budget.categoryId);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  // ---------- Perhitungan ----------

  int get totalBalance => FinanceService.totalBalance(
    accounts,
    transactions,
    deposits,
    withdrawals: withdrawals,
  );

  int balanceOf(Account a) => FinanceService.accountBalance(
    a,
    transactions,
    deposits,
    withdrawals: withdrawals,
  );

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
