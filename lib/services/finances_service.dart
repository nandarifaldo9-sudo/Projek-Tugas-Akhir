import '../models/models.dart';

class FinanceService {
  FinanceService._();

  static int savedForGoal(
    int goalId,
    List<GoalDeposit> deposits, {
    DateTime? asOf,
  }) {
    final cutoff = _dateOnly(asOf ?? DateTime.now());
    return deposits
        .where((d) => d.goalId == goalId && !_isAfter(d.date, cutoff))
        .fold(0, (sum, d) => sum + d.amount);
  }

  /// Saldo = saldo awal + pemasukan - pengeluaran - setoran target pada akun tersebut.
  static int accountBalance(
    Account account,
    List<AppTransaction> txs,
    List<GoalDeposit> deposits, {
    DateTime? asOf,
  }) {
    final cutoff = _dateOnly(asOf ?? DateTime.now());
    var balance = account.initialBalance;
    for (final t in txs) {
      if (t.accountId != account.id || _isAfter(t.date, cutoff)) continue;
      balance += t.type == TxType.income ? t.amount : -t.amount;
    }
    for (final d in deposits) {
      if (d.accountId == account.id && !_isAfter(d.date, cutoff)) {
        balance -= d.amount;
      }
    }
    return balance;
  }

  static int totalBalance(
    List<Account> accounts,
    List<AppTransaction> txs,
    List<GoalDeposit> deposits,
  ) {
    return accounts.fold(0, (sum, a) => sum + accountBalance(a, txs, deposits));
  }

  static int incomeInMonth(List<AppTransaction> txs, DateTime month) {
    return _sumInMonth(txs, month, TxType.income);
  }

  static int expenseInMonth(List<AppTransaction> txs, DateTime month) {
    return _sumInMonth(txs, month, TxType.expense);
  }

  static int _sumInMonth(
    List<AppTransaction> txs,
    DateTime month,
    TxType type,
  ) {
    return txs
        .where(
          (t) =>
              t.type == type &&
              t.date.year == month.year &&
              t.date.month == month.month,
        )
        .fold(0, (sum, t) => sum + t.amount);
  }

  static Map<int, int> expenseByCategory(
    List<AppTransaction> txs,
    DateTime month,
  ) {
    final result = <int, int>{};
    for (final t in txs) {
      if (t.type == TxType.expense &&
          t.date.year == month.year &&
          t.date.month == month.month) {
        result[t.categoryId] = (result[t.categoryId] ?? 0) + t.amount;
      }
    }
    return result;
  }

  static List<MonthTotal> monthlyTotals(
    List<AppTransaction> txs,
    DateTime endMonth,
  ) {
    final result = <MonthTotal>[];
    for (var i = 5; i >= 0; i--) {
      final m = DateTime(endMonth.year, endMonth.month - i, 1);
      final inc = incomeInMonth(txs, m);
      final exp = expenseInMonth(txs, m);
      result.add(MonthTotal(month: m, income: inc, expense: exp));
    }
    return result;
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool _isAfter(DateTime date, DateTime cutoff) =>
      _dateOnly(date).isAfter(cutoff);
}
