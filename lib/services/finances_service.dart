import '../models/models.dart';

class FinanceService {
  FinanceService._();

  static int savedForGoal(
    int goalId,
    List<GoalDeposit> deposits, {
    List<GoalWithdrawal> withdrawals = const [],
    DateTime? asOf,
  }) {
    final cutoff = _dateOnly(asOf ?? DateTime.now());
    final totalDeposits = deposits
        .where((d) => d.goalId == goalId && !_isAfter(d.date, cutoff))
        .fold(0, (sum, d) => sum + d.amount);
    final totalWithdrawals = withdrawals
        .where((w) => w.goalId == goalId && !_isAfter(w.date, cutoff))
        .fold(0, (sum, w) => sum + w.amount);
    return totalDeposits - totalWithdrawals;
  }

  /// Saldo = saldo awal + pemasukan - pengeluaran - setoran target pada akun tersebut.
  static int accountBalance(
    Account account,
    List<AppTransaction> txs,
    List<GoalDeposit> deposits, {
    List<GoalWithdrawal> withdrawals = const [],
    DateTime? asOf,
  }) {
    final cutoff = _dateOnly(asOf ?? DateTime.now());
    var balance = account.initialBalance;
    for (final t in txs) {
      if (_isAfter(t.date, cutoff)) continue;
      if (t.type == TxType.transfer) {
        if (t.accountId == account.id) balance -= t.amount;
        if (t.toAccountId == account.id) balance += t.amount;
      } else if (t.accountId == account.id) {
        balance += t.type == TxType.income ? t.amount : -t.amount;
      }
    }
    for (final d in deposits) {
      if (d.accountId == account.id && !_isAfter(d.date, cutoff)) {
        balance -= d.amount;
      }
    }
    for (final w in withdrawals) {
      if (w.accountId == account.id && !_isAfter(w.date, cutoff)) {
        balance += w.amount;
      }
    }
    return balance;
  }

  static int totalBalance(
    List<Account> accounts,
    List<AppTransaction> txs,
    List<GoalDeposit> deposits, {
    List<GoalWithdrawal> withdrawals = const [],
  }) {
    return accounts.fold(
      0,
      (sum, a) =>
          sum + accountBalance(a, txs, deposits, withdrawals: withdrawals),
    );
  }

  static int incomeInMonth(
    List<AppTransaction> txs,
    DateTime month, {
    DateTime? asOf,
  }) {
    return _sumInMonth(txs, month, TxType.income, asOf: asOf);
  }

  static int expenseInMonth(
    List<AppTransaction> txs,
    DateTime month, {
    DateTime? asOf,
  }) {
    return _sumInMonth(txs, month, TxType.expense, asOf: asOf);
  }

  static int _sumInMonth(
    List<AppTransaction> txs,
    DateTime month,
    TxType type, {
    DateTime? asOf,
  }) {
    return txs
        .where(
          (t) =>
              t.type == type &&
              t.date.year == month.year &&
              t.date.month == month.month &&
              !_isAfter(t.date, _dateOnly(asOf ?? DateTime.now())),
        )
        .fold(0, (sum, t) => sum + t.amount);
  }

  static Map<int, int> expenseByCategory(
    List<AppTransaction> txs,
    DateTime month, {
    DateTime? asOf,
  }) {
    final result = <int, int>{};
    for (final t in txs) {
      if (t.type == TxType.expense &&
          t.date.year == month.year &&
          t.date.month == month.month &&
          t.categoryId != null &&
          !_isAfter(t.date, _dateOnly(asOf ?? DateTime.now()))) {
        final categoryId = t.categoryId!;
        result[categoryId] = (result[categoryId] ?? 0) + t.amount;
      }
    }
    return result;
  }

  static List<MonthTotal> monthlyTotals(
    List<AppTransaction> txs,
    DateTime endMonth, {
    DateTime? asOf,
  }) {
    final firstMonth = DateTime(endMonth.year, endMonth.month - 5);
    final nextMonth = DateTime(endMonth.year, endMonth.month + 1);
    final cutoff = _dateOnly(asOf ?? DateTime.now());
    final totals = <int, (int, int)>{};
    for (final transaction in txs) {
      final date = _dateOnly(transaction.date);
      if (date.isAfter(cutoff) ||
          date.isBefore(firstMonth) ||
          !date.isBefore(nextMonth)) {
        continue;
      }
      final monthKey = date.year * 12 + date.month;
      final current = totals[monthKey] ?? (0, 0);
      if (transaction.type == TxType.income) {
        totals[monthKey] = (current.$1 + transaction.amount, current.$2);
      } else if (transaction.type == TxType.expense) {
        totals[monthKey] = (current.$1, current.$2 + transaction.amount);
      }
    }

    final result = <MonthTotal>[];
    for (var i = 5; i >= 0; i--) {
      final m = DateTime(endMonth.year, endMonth.month - i, 1);
      final values = totals[m.year * 12 + m.month] ?? (0, 0);
      result.add(MonthTotal(month: m, income: values.$1, expense: values.$2));
    }
    return result;
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool _isAfter(DateTime date, DateTime cutoff) =>
      _dateOnly(date).isAfter(cutoff);
}
