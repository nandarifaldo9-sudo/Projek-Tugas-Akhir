import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:projek_tugas_akhir/data/database_helper.dart';
import 'package:projek_tugas_akhir/models/models.dart';
import 'package:projek_tugas_akhir/providers/finance_provider.dart';
import 'package:projek_tugas_akhir/services/backup_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late DatabaseFactory factory;
  late String databasePath;
  late FinanceProvider finance;
  late DatabaseHelper helper;

  setUpAll(() {
    sqfliteFfiInit();
    factory = databaseFactoryFfi;
  });

  setUp(() async {
    databasePath = path.join(
      await factory.getDatabasesPath(),
      'flowly_features_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    helper = DatabaseHelper(factory: factory, databasePath: databasePath);
    finance = FinanceProvider(database: helper);
    await finance.load();
  });

  tearDown(() async {
    finance.dispose();
    await factory.deleteDatabase(databasePath);
  });

  test('recurring catch-up creates each missed date only once', () async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day - 14);
    final category = finance.categories.firstWhere(
      (item) => item.type == TxType.expense,
    );
    final account = finance.accounts.first;
    final error = await finance.saveRecurringRule(
      RecurringRule(
        type: TxType.expense,
        amount: 125,
        accountId: account.id!,
        categoryId: category.id,
        frequency: RecurrenceFrequency.weekly,
        startDate: start,
        nextDate: start,
        dayOfMonth: start.day,
        note: 'Tagihan',
      ),
    );

    expect(error, isNull);
    final rule = finance.recurringRules.single;
    expect(
      finance.transactions
          .where((transaction) => transaction.recurringRuleId == rule.id)
          .length,
      3,
    );
    final database = await helper.database;
    expect(
      await DatabaseHelper(
        factory: factory,
        databasePath: databasePath,
      ).materializeDueRecurring(DateTime.now()),
      0,
    );
    expect(
      await database.rawQuery(
        'SELECT occurrence_date FROM transactions '
        'WHERE recurring_rule_id = ?',
        [rule.id],
      ),
      hasLength(3),
    );
  });

  test('budget warning is recorded once per category and month', () async {
    final category = finance.categories.firstWhere(
      (item) => item.type == TxType.expense,
    );
    final account = finance.accounts.first;
    expect(
      await finance.saveBudget(
        CategoryBudget(categoryId: category.id!, amount: 1000),
      ),
      isNull,
    );
    AppTransaction expense(int amount) => AppTransaction(
      type: TxType.expense,
      amount: amount,
      accountId: account.id!,
      categoryId: category.id,
      date: DateTime.now(),
    );

    expect(await finance.addTransaction(expense(800)), isNull);
    expect(finance.takeBudgetAlerts(), [category.id]);
    expect(await finance.addTransaction(expense(500)), isNull);
    expect(finance.takeBudgetAlerts(), isEmpty);
    expect(finance.spentForCategory(category.id!, DateTime.now()), 1300);
  });

  test('withdrawals keep history and prevent negative goal savings', () async {
    final account = finance.accounts.first;
    final goal = Goal(name: 'Dana darurat', targetAmount: 1000);
    expect(await finance.saveGoal(goal), isNull);
    final savedGoal = finance.goals.single;
    final today = DateTime.now();
    final deposit = GoalDeposit(
      goalId: savedGoal.id!,
      accountId: account.id!,
      amount: 500,
      date: today,
    );
    expect(await finance.addDeposit(deposit), isNull);
    final savedDeposit = finance.deposits.single;
    final withdrawal = GoalWithdrawal(
      goalId: savedGoal.id!,
      accountId: account.id!,
      amount: 300,
      date: today,
    );

    expect(await finance.addWithdrawal(withdrawal), isNull);
    final savedWithdrawal = finance.withdrawals.single;
    expect(finance.savedFor(savedGoal.id!), 200);
    expect(finance.balanceOf(account), -200);
    expect(
      await finance.updateDeposit(
        GoalDeposit(
          id: savedDeposit.id,
          goalId: savedGoal.id!,
          accountId: account.id!,
          amount: 200,
          date: today,
        ),
      ),
      contains('riwayat penarikan'),
    );
    expect(
      await finance.updateWithdrawal(
        GoalWithdrawal(
          id: savedWithdrawal.id,
          goalId: savedGoal.id!,
          accountId: account.id!,
          amount: 501,
          date: today,
        ),
      ),
      contains('melebihi saldo target'),
    );
    expect(await finance.deleteWithdrawal(savedWithdrawal.id!), isNull);
    expect(finance.savedFor(savedGoal.id!), 500);
    expect(finance.balanceOf(account), -500);
  });

  test(
    'backup CSV restores data and repeated import does not duplicate it',
    () async {
      final sourceAccount = Account(name: 'Dompet');
      expect(await finance.saveAccount(sourceAccount), isNull);
      final account = finance.accounts.firstWhere(
        (item) => item.name == 'Dompet',
      );
      final category = Category(name: 'Kopi', type: TxType.expense);
      expect(await finance.saveCategory(category), isNull);
      final savedCategory = finance.categories.firstWhere(
        (item) => item.name == 'Kopi',
      );
      expect(
        await finance.saveGoal(Goal(name: 'Sepeda', targetAmount: 200000)),
        isNull,
      );
      final goal = finance.goals.single;
      expect(
        await finance.saveBudget(
          CategoryBudget(categoryId: savedCategory.id!, amount: 50000),
        ),
        isNull,
      );
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(
        await finance.saveRecurringRule(
          RecurringRule(
            type: TxType.expense,
            amount: 1000,
            accountId: account.id!,
            categoryId: savedCategory.id,
            frequency: RecurrenceFrequency.monthly,
            startDate: tomorrow,
            nextDate: tomorrow,
            dayOfMonth: tomorrow.day,
            note: 'Kopi langganan',
          ),
        ),
        isNull,
      );
      expect(
        await finance.addTransaction(
          AppTransaction(
            type: TxType.expense,
            amount: 25000,
            accountId: account.id!,
            categoryId: savedCategory.id,
            date: DateTime.now(),
            note: 'Kopi, pagi',
          ),
        ),
        isNull,
      );
      expect(
        await finance.addDeposit(
          GoalDeposit(
            goalId: goal.id!,
            accountId: account.id!,
            amount: 5000,
            date: DateTime.now(),
          ),
        ),
        isNull,
      );

      final csv = BackupService.buildCsv(finance);
      final targetPath = path.join(
        await factory.getDatabasesPath(),
        'flowly_restore_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final target = FinanceProvider(
        database: DatabaseHelper(factory: factory, databasePath: targetPath),
      );
      addTearDown(() async {
        target.dispose();
        await factory.deleteDatabase(targetPath);
      });
      await target.load();

      final firstImport = await BackupService.importCsv(target, csv);
      expect(firstImport.imported, greaterThanOrEqualTo(6));
      expect(target.transactions, hasLength(1));
      expect(target.deposits, hasLength(1));
      expect(target.recurringRules, hasLength(1));
      final restoredCategory = target.categories.firstWhere(
        (item) => item.name == 'Kopi',
      );
      expect(target.budgetFor(restoredCategory.id!), 50000);

      final secondImport = await BackupService.importCsv(target, csv);
      expect(secondImport.imported, 0);
      expect(target.transactions, hasLength(1));
      expect(target.deposits, hasLength(1));
    },
  );
}
