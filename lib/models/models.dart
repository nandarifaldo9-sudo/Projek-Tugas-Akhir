enum TxType { income, expense }

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

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'type': type.name,
  };
}

/// Dinamai AppTransaction agar tidak bentrok dengan Transaction milik sqflite.
class AppTransaction {
  final int? id;
  final TxType type;
  final int amount;
  final int accountId;
  final int categoryId;
  final DateTime date;
  final String note;

  const AppTransaction({
    this.id,
    required this.type,
    required this.amount,
    required this.accountId,
    required this.categoryId,
    required this.date,
    this.note = '',
  });

  factory AppTransaction.fromMap(Map<String, Object?> m) => AppTransaction(
    id: m['id'] as int,
    type: TxType.values.byName(m['type'] as String),
    amount: m['amount'] as int,
    accountId: m['account_id'] as int,
    categoryId: m['category_id'] as int,
    date: DateTime.parse(m['date'] as String),
    note: (m['note'] as String?) ?? '',
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'type': type.name,
    'amount': amount,
    'account_id': accountId,
    'category_id': categoryId,
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
