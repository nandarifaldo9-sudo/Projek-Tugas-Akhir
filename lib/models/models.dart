enum TxType { income, expense, transfer }

/// Format tanggal untuk database dan CSV: yyyy-MM-dd.
String dateKey(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-$m-$day';
}

class Account {
  final int? id;
  final String name;
  final int initialBalance;

  const Account({this.id, required this.name, this.initialBalance = 0});

  factory Account.fromMap(Map<String, Object?> m) => Account(
    id: m['id'] as int,
    name: m['name'] as String,
    initialBalance: m['initial_balance'] as int,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'initial_balance': initialBalance,
  };
}

class Category {
  final int? id;
  final String name;
  final TxType type;

  const Category({this.id, required this.name, required this.type});

  factory Category.fromMap(Map<String, Object?> m) => Category(
    id: m['id'] as int,
    name: m['name'] as String,
    type: TxType.values.byName(m['type'] as String),
  );

  Map<String, Object?> toMap() => {'id': id, 'name': name, 'type': type.name};
}

/// Dinamai AppTransaction agar tidak bentrok dengan Transaction milik sqflite.
class AppTransaction {
  final int? id;
  final TxType type;
  final int amount;
  final int accountId;
  final int? toAccountId;
  final int? categoryId;
  final int? recurringRuleId;
  final DateTime? occurrenceDate;
  final DateTime date;
  final String note;

  const AppTransaction({
    this.id,
    required this.type,
    required this.amount,
    required this.accountId,
    this.toAccountId,
    required this.categoryId,
    this.recurringRuleId,
    this.occurrenceDate,
    required this.date,
    this.note = '',
  });

  factory AppTransaction.fromMap(Map<String, Object?> m) => AppTransaction(
    id: m['id'] as int,
    type: TxType.values.byName(m['type'] as String),
    amount: m['amount'] as int,
    accountId: m['account_id'] as int,
    toAccountId: m['to_account_id'] as int?,
    categoryId: m['category_id'] as int?,
    recurringRuleId: m['recurring_rule_id'] as int?,
    occurrenceDate: m['occurrence_date'] == null
        ? null
        : DateTime.parse(m['occurrence_date'] as String),
    date: DateTime.parse(m['date'] as String),
    note: (m['note'] as String?) ?? '',
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'type': type.name,
    'amount': amount,
    'account_id': accountId,
    'to_account_id': toAccountId,
    'category_id': categoryId,
    'recurring_rule_id': recurringRuleId,
    'occurrence_date': occurrenceDate == null ? null : dateKey(occurrenceDate!),
    'date': dateKey(date),
    'note': note,
  };
}

/// Target tabungan.
class Goal {
  final int? id;
  final String name;
  final int targetAmount;
  final DateTime? targetDate;

  const Goal({
    this.id,
    required this.name,
    required this.targetAmount,
    this.targetDate,
  });

  factory Goal.fromMap(Map<String, Object?> m) {
    final d = m['target_date'] as String?;
    return Goal(
      id: m['id'] as int,
      name: m['name'] as String,
      targetAmount: m['target_amount'] as int,
      targetDate: d == null ? null : DateTime.parse(d),
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'target_amount': targetAmount,
    'target_date': targetDate == null ? null : dateKey(targetDate!),
  };
}

/// Setoran ke target. Mengurangi saldo akun asal, tapi bukan pengeluaran.
class GoalDeposit {
  final int? id;
  final int goalId;
  final int accountId;
  final int amount;
  final DateTime date;
  final String note;

  const GoalDeposit({
    this.id,
    required this.goalId,
    required this.accountId,
    required this.amount,
    required this.date,
    this.note = '',
  });

  factory GoalDeposit.fromMap(Map<String, Object?> m) => GoalDeposit(
    id: m['id'] as int,
    goalId: m['goal_id'] as int,
    accountId: m['account_id'] as int,
    amount: m['amount'] as int,
    date: DateTime.parse(m['date'] as String),
    note: (m['note'] as String?) ?? '',
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'goal_id': goalId,
    'account_id': accountId,
    'amount': amount,
    'date': dateKey(date),
    'note': note,
  };
}

class GoalWithdrawal {
  final int? id;
  final int goalId;
  final int accountId;
  final int amount;
  final DateTime date;
  final String note;

  const GoalWithdrawal({
    this.id,
    required this.goalId,
    required this.accountId,
    required this.amount,
    required this.date,
    this.note = '',
  });

  factory GoalWithdrawal.fromMap(Map<String, Object?> m) => GoalWithdrawal(
    id: m['id'] as int,
    goalId: m['goal_id'] as int,
    accountId: m['account_id'] as int,
    amount: m['amount'] as int,
    date: DateTime.parse(m['date'] as String),
    note: (m['note'] as String?) ?? '',
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'goal_id': goalId,
    'account_id': accountId,
    'amount': amount,
    'date': dateKey(date),
    'note': note,
  };
}

class CategoryBudget {
  final int categoryId;
  final int amount;

  const CategoryBudget({required this.categoryId, required this.amount});

  factory CategoryBudget.fromMap(Map<String, Object?> m) => CategoryBudget(
    categoryId: m['category_id'] as int,
    amount: m['amount'] as int,
  );

  Map<String, Object?> toMap() => {'category_id': categoryId, 'amount': amount};
}

enum RecurrenceFrequency { weekly, monthly }

class RecurringRule {
  final int? id;
  final TxType type;
  final int amount;
  final int accountId;
  final int? toAccountId;
  final int? categoryId;
  final RecurrenceFrequency frequency;
  final DateTime startDate;
  final DateTime nextDate;
  final int dayOfMonth;
  final String note;
  final bool enabled;

  const RecurringRule({
    this.id,
    required this.type,
    required this.amount,
    required this.accountId,
    this.toAccountId,
    this.categoryId,
    required this.frequency,
    required this.startDate,
    required this.nextDate,
    required this.dayOfMonth,
    this.note = '',
    this.enabled = true,
  });

  factory RecurringRule.fromMap(Map<String, Object?> m) => RecurringRule(
    id: m['id'] as int,
    type: TxType.values.byName(m['type'] as String),
    amount: m['amount'] as int,
    accountId: m['account_id'] as int,
    toAccountId: m['to_account_id'] as int?,
    categoryId: m['category_id'] as int?,
    frequency: RecurrenceFrequency.values.byName(m['frequency'] as String),
    startDate: DateTime.parse(m['start_date'] as String),
    nextDate: DateTime.parse(m['next_date'] as String),
    dayOfMonth: m['day_of_month'] as int,
    note: (m['note'] as String?) ?? '',
    enabled: (m['enabled'] as int) == 1,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'type': type.name,
    'amount': amount,
    'account_id': accountId,
    'to_account_id': toAccountId,
    'category_id': categoryId,
    'frequency': frequency.name,
    'start_date': dateKey(startDate),
    'next_date': dateKey(nextDate),
    'day_of_month': dayOfMonth,
    'note': note,
    'enabled': enabled ? 1 : 0,
  };
}

/// Ringkasan total pemasukan dan pengeluaran per bulan untuk grafik.
class MonthTotal {
  final DateTime month;
  final int income;
  final int expense;

  const MonthTotal({
    required this.month,
    required this.income,
    required this.expense,
  });
}
