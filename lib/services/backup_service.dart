import 'dart:convert';

import 'package:csv/csv.dart';

import '../models/models.dart';
import '../providers/finance_provider.dart';

class BackupImportResult {
  const BackupImportResult({required this.imported, required this.skipped});

  final int imported;
  final int skipped;
}

class BackupService {
  BackupService._();

  static String buildCsv(FinanceProvider finance) {
    final rows = <List<String>>[
      ['Tanggal', 'Jenis', 'Kategori', 'Akun', 'Nominal', 'Catatan'],
      for (final account in finance.accounts)
        ['', '_akun', '', _safe(account.name), '${account.initialBalance}', ''],
      for (final category in finance.categories)
        [
          '',
          category.type == TxType.income
              ? '_kategori_masuk'
              : '_kategori_keluar',
          _safe(category.name),
          '',
          '',
          '',
        ],
      for (final goal in finance.goals)
        [
          goal.targetDate == null ? '' : dateKey(goal.targetDate!),
          '_target',
          _safe(goal.name),
          '',
          '${goal.targetAmount}',
          '',
        ],
      for (final budget in finance.budgets)
        [
          '',
          '_anggaran',
          _safe(finance.categoryName(budget.categoryId)),
          '',
          '${budget.amount}',
          '',
        ],
      for (final rule in finance.recurringRules)
        [
          '',
          '_berulang',
          '',
          '',
          '',
          jsonEncode({
            'type': rule.type.name,
            'amount': rule.amount,
            'account': finance.accountName(rule.accountId),
            'toAccount': finance.accountName(rule.toAccountId),
            'category': finance.categoryName(rule.categoryId),
            'frequency': rule.frequency.name,
            'startDate': dateKey(rule.startDate),
            'nextDate': dateKey(rule.nextDate),
            'dayOfMonth': rule.dayOfMonth,
            'note': rule.note,
            'enabled': rule.enabled,
          }),
        ],
      for (final transaction in finance.transactions)
        [
          dateKey(transaction.date),
          transaction.type == TxType.income
              ? 'Masuk'
              : transaction.type == TxType.transfer
              ? 'Transfer'
              : 'Keluar',
          _safe(
            transaction.type == TxType.transfer
                ? ''
                : finance.categoryName(transaction.categoryId),
          ),
          _safe(
            transaction.type == TxType.transfer
                ? '${finance.accountName(transaction.accountId)} → '
                      '${finance.accountName(transaction.toAccountId)}'
                : finance.accountName(transaction.accountId),
          ),
          '${transaction.amount}',
          _safe(transaction.note),
        ],
      for (final deposit in finance.deposits)
        [
          dateKey(deposit.date),
          'Setoran target',
          _safe(finance.goalName(deposit.goalId)),
          _safe(finance.accountName(deposit.accountId)),
          '${deposit.amount}',
          _safe(deposit.note),
        ],
      for (final withdrawal in finance.withdrawals)
        [
          dateKey(withdrawal.date),
          'Penarikan target',
          _safe(finance.goalName(withdrawal.goalId)),
          _safe(finance.accountName(withdrawal.accountId)),
          '${withdrawal.amount}',
          _safe(withdrawal.note),
        ],
    ];
    return csv.encode(rows);
  }

  static Future<BackupImportResult> importCsv(
    FinanceProvider finance,
    String contents,
  ) async {
    final rows = csv.decode(contents);
    if (rows.isEmpty ||
        rows.first.length < 6 ||
        rows.first.take(6).map((cell) => cell.toString()).join('|') !=
            'Tanggal|Jenis|Kategori|Akun|Nominal|Catatan') {
      throw const FormatException('Format CSV Flowly tidak dikenali.');
    }

    var imported = 0;
    var skipped = 0;
    final seenRecords = <String, int>{};
    final existingRecords = <String, int>{};
    for (final transaction in finance.transactions) {
      _count(existingRecords, _transactionKey(transaction));
    }
    for (final deposit in finance.deposits) {
      _count(existingRecords, _depositKey(deposit));
    }
    for (final withdrawal in finance.withdrawals) {
      _count(existingRecords, _withdrawalKey(withdrawal));
    }

    for (var index = 1; index < rows.length; index++) {
      final row = rows[index].map((cell) => cell.toString()).toList();
      if (row.length < 6) {
        skipped++;
        continue;
      }
      final date = row[0];
      final type = row[1];
      final categoryName = _unescape(row[2]);
      final accountField = _unescape(row[3]);
      final amount = int.tryParse(row[4]);
      final note = _unescape(row[5]);

      switch (type) {
        case '_akun':
          final initialBalance = int.tryParse(row[4]);
          if (accountField.isEmpty || initialBalance == null) {
            skipped++;
          } else if (finance.accounts.any((a) => a.name == accountField)) {
            skipped++;
          } else {
            final error = await finance.saveAccount(
              Account(name: accountField, initialBalance: initialBalance),
            );
            error == null ? imported++ : skipped++;
          }
          break;
        case '_kategori_masuk':
        case '_kategori_keluar':
          final categoryType = type == '_kategori_masuk'
              ? TxType.income
              : TxType.expense;
          if (categoryName.isEmpty ||
              finance.categories.any(
                (c) => c.name == categoryName && c.type == categoryType,
              )) {
            skipped++;
          } else {
            final error = await finance.saveCategory(
              Category(name: categoryName, type: categoryType),
            );
            error == null ? imported++ : skipped++;
          }
          break;
        case '_target':
          if (categoryName.isEmpty ||
              amount == null ||
              finance.goals.any((g) => g.name == categoryName)) {
            skipped++;
          } else {
            final targetDate = date.isEmpty ? null : DateTime.tryParse(date);
            if (date.isNotEmpty && targetDate == null) {
              skipped++;
              break;
            }
            final error = await finance.saveGoal(
              Goal(
                name: categoryName,
                targetAmount: amount,
                targetDate: targetDate,
              ),
            );
            error == null ? imported++ : skipped++;
          }
          break;
        case '_anggaran':
          final category = _expenseCategory(finance, categoryName);
          if (category == null ||
              amount == null ||
              finance.budgetFor(category.id!) > 0) {
            skipped++;
          } else {
            final error = await finance.saveBudget(
              CategoryBudget(categoryId: category.id!, amount: amount),
            );
            error == null ? imported++ : skipped++;
          }
          break;
        case '_berulang':
          final importedRule = await _importRecurringRule(finance, note);
          if (importedRule) {
            imported++;
          } else {
            skipped++;
          }
          break;
        case 'Masuk':
        case 'Keluar':
        case 'Transfer':
          if (amount == null || date.isEmpty) {
            skipped++;
            break;
          }
          final transactionDate = DateTime.tryParse(date);
          if (transactionDate == null) {
            skipped++;
            break;
          }
          final transferAccounts = accountField.split(' → ');
          final account = type == 'Transfer'
              ? _accountByName(finance, transferAccounts.first)
              : _accountByName(finance, accountField);
          final toAccount = type == 'Transfer' && transferAccounts.length == 2
              ? _accountByName(finance, transferAccounts.last)
              : null;
          final category = type == 'Transfer'
              ? null
              : _categoryByName(
                  finance,
                  categoryName,
                  type == 'Masuk' ? TxType.income : TxType.expense,
                );
          if (account == null ||
              (type == 'Transfer' && toAccount == null) ||
              (type != 'Transfer' && category == null)) {
            skipped++;
            break;
          }
          final transaction = AppTransaction(
            type: type == 'Transfer'
                ? TxType.transfer
                : type == 'Masuk'
                ? TxType.income
                : TxType.expense,
            amount: amount,
            accountId: account.id!,
            toAccountId: toAccount?.id,
            categoryId: category?.id,
            date: transactionDate,
            note: note,
          );
          final key = _transactionKey(transaction);
          if (!_shouldInsert(key, seenRecords, existingRecords)) {
            skipped++;
            break;
          }
          final error = await finance.addTransaction(transaction);
          error == null ? imported++ : skipped++;
          break;
        case 'Setoran target':
        case 'Penarikan target':
          if (amount == null || date.isEmpty) {
            skipped++;
            break;
          }
          final transactionDate = DateTime.tryParse(date);
          final goal = _goalByName(finance, categoryName);
          final account = _accountByName(finance, accountField);
          if (transactionDate == null || goal == null || account == null) {
            skipped++;
            break;
          }
          if (type == 'Setoran target') {
            final deposit = GoalDeposit(
              goalId: goal.id!,
              accountId: account.id!,
              amount: amount,
              date: transactionDate,
              note: note,
            );
            final key = _depositKey(deposit);
            if (!_shouldInsert(key, seenRecords, existingRecords)) {
              skipped++;
              break;
            }
            final error = await finance.addDeposit(deposit);
            error == null ? imported++ : skipped++;
          } else {
            final withdrawal = GoalWithdrawal(
              goalId: goal.id!,
              accountId: account.id!,
              amount: amount,
              date: transactionDate,
              note: note,
            );
            final key = _withdrawalKey(withdrawal);
            if (!_shouldInsert(key, seenRecords, existingRecords)) {
              skipped++;
              break;
            }
            final error = await finance.addWithdrawal(withdrawal);
            error == null ? imported++ : skipped++;
          }
          break;
        default:
          skipped++;
      }
    }
    return BackupImportResult(imported: imported, skipped: skipped);
  }

  static Future<bool> _importRecurringRule(
    FinanceProvider finance,
    String json,
  ) async {
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final type = TxType.values.byName(data['type'] as String);
      final account = _accountByName(finance, data['account'] as String);
      final category = _categoryByName(
        finance,
        data['category'] as String,
        type,
      );
      if (account == null || category == null) return false;
      final frequency = RecurrenceFrequency.values.byName(
        data['frequency'] as String,
      );
      final rule = RecurringRule(
        type: type,
        amount: data['amount'] as int,
        accountId: account.id!,
        categoryId: category.id,
        frequency: frequency,
        startDate: DateTime.parse(data['startDate'] as String),
        nextDate: DateTime.parse(data['nextDate'] as String),
        dayOfMonth: data['dayOfMonth'] as int,
        note: data['note'] as String,
        enabled: data['enabled'] as bool,
      );
      final duplicate = finance.recurringRules.any(
        (existing) =>
            existing.type == rule.type &&
            existing.amount == rule.amount &&
            existing.accountId == rule.accountId &&
            existing.categoryId == rule.categoryId &&
            existing.frequency == rule.frequency &&
            existing.startDate == rule.startDate &&
            existing.nextDate == rule.nextDate &&
            existing.note == rule.note,
      );
      if (duplicate) return false;
      return await finance.saveRecurringRule(rule) == null;
    } on FormatException {
      return false;
    } on TypeError {
      return false;
    }
  }

  static bool _shouldInsert(
    String key,
    Map<String, int> seen,
    Map<String, int> existing,
  ) {
    _count(seen, key);
    return (existing[key] ?? 0) < seen[key]!;
  }

  static void _count(Map<String, int> counts, String key) {
    counts[key] = (counts[key] ?? 0) + 1;
  }

  static String _transactionKey(AppTransaction t) => jsonEncode([
    t.type.name,
    t.amount,
    t.accountId,
    t.toAccountId,
    t.categoryId,
    dateKey(t.date),
    t.note,
  ]);

  static String _depositKey(GoalDeposit d) =>
      jsonEncode([d.goalId, d.accountId, d.amount, dateKey(d.date), d.note]);

  static String _withdrawalKey(GoalWithdrawal w) =>
      jsonEncode([w.goalId, w.accountId, w.amount, dateKey(w.date), w.note]);

  static Account? _accountByName(FinanceProvider finance, String name) {
    for (final account in finance.accounts) {
      if (account.name == name) return account;
    }
    return null;
  }

  static Category? _categoryByName(
    FinanceProvider finance,
    String name,
    TxType type,
  ) {
    for (final category in finance.categories) {
      if (category.name == name && category.type == type) return category;
    }
    return null;
  }

  static Category? _expenseCategory(FinanceProvider finance, String name) =>
      _categoryByName(finance, name, TxType.expense);

  static Goal? _goalByName(FinanceProvider finance, String name) {
    for (final goal in finance.goals) {
      if (goal.name == name) return goal;
    }
    return null;
  }

  static String _unescape(String value) {
    if (value.startsWith("'") &&
        RegExp(r"^[\u0000-\u0020]*[=+\-@]").hasMatch(value.substring(1))) {
      return value.substring(1);
    }
    return value;
  }

  static String _safe(String value) {
    if (RegExp(r'^[\u0000-\u0020]*[=+\-@]').hasMatch(value) ||
        value.startsWith('\t') ||
        value.startsWith('\r')) {
      return "'$value";
    }
    return value;
  }
}
