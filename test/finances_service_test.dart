import 'package:flutter_test/flutter_test.dart';
import 'package:projek_tugas_akhir/models/models.dart';
import 'package:projek_tugas_akhir/services/finances_service.dart';

void main() {
  group('future-dated records', () {
    final asOf = DateTime(2025, 3, 15);

    test('do not affect the current account balance', () {
      final account = Account(id: 1, name: 'Tunai', initialBalance: 500);
      final transactions = [
        AppTransaction(
          type: TxType.income,
          amount: 1000,
          accountId: 1,
          categoryId: 1,
          date: DateTime(2025, 3, 14),
        ),
        AppTransaction(
          type: TxType.expense,
          amount: 200,
          accountId: 1,
          categoryId: 2,
          date: DateTime(2025, 3, 15, 23),
        ),
        AppTransaction(
          type: TxType.expense,
          amount: 300,
          accountId: 1,
          categoryId: 2,
          date: DateTime(2025, 3, 16),
        ),
      ];
      final deposits = [
        GoalDeposit(
          goalId: 1,
          accountId: 1,
          amount: 100,
          date: DateTime(2025, 3, 15),
        ),
        GoalDeposit(
          goalId: 1,
          accountId: 1,
          amount: 400,
          date: DateTime(2025, 3, 16),
        ),
      ];

      expect(
        FinanceService.accountBalance(
          account,
          transactions,
          deposits,
          asOf: asOf,
        ),
        1200,
      );
    });

    test('do not count future deposits toward goal progress', () {
      final deposits = [
        GoalDeposit(
          goalId: 1,
          accountId: 1,
          amount: 100,
          date: DateTime(2025, 3, 15),
        ),
        GoalDeposit(
          goalId: 1,
          accountId: 1,
          amount: 400,
          date: DateTime(2025, 3, 16),
        ),
      ];

      expect(FinanceService.savedForGoal(1, deposits, asOf: asOf), 100);
    });

    test('do not count future transactions in monthly summaries', () {
      final transactions = [
        AppTransaction(
          type: TxType.income,
          amount: 1000,
          accountId: 1,
          categoryId: 1,
          date: DateTime(2025, 3, 10),
        ),
        AppTransaction(
          type: TxType.income,
          amount: 2000,
          accountId: 1,
          categoryId: 1,
          date: DateTime(2025, 3, 20),
        ),
        AppTransaction(
          type: TxType.expense,
          amount: 300,
          accountId: 1,
          categoryId: 2,
          date: DateTime(2025, 3, 14),
        ),
        AppTransaction(
          type: TxType.expense,
          amount: 700,
          accountId: 1,
          categoryId: 2,
          date: DateTime(2025, 3, 16),
        ),
      ];

      expect(
        FinanceService.incomeInMonth(transactions, asOf, asOf: asOf),
        1000,
      );
      expect(
        FinanceService.expenseInMonth(transactions, asOf, asOf: asOf),
        300,
      );
      expect(FinanceService.expenseByCategory(transactions, asOf, asOf: asOf), {
        2: 300,
      });
    });
  });

  test('transfers decrease source and increase destination only', () {
    final accounts = [
      const Account(id: 1, name: 'Tunai', initialBalance: 1000),
      const Account(id: 2, name: 'Bank', initialBalance: 500),
    ];
    final transfers = [
      AppTransaction(
        type: TxType.transfer,
        amount: 300,
        accountId: 1,
        toAccountId: 2,
        categoryId: null,
        date: DateTime(2025, 3, 10),
      ),
    ];

    expect(FinanceService.accountBalance(accounts[0], transfers, []), 700);
    expect(FinanceService.accountBalance(accounts[1], transfers, []), 800);
    expect(FinanceService.totalBalance(accounts, transfers, []), 1500);
    expect(FinanceService.expenseInMonth(transfers, DateTime(2025, 3)), 0);
    expect(FinanceService.incomeInMonth(transfers, DateTime(2025, 3)), 0);
  });

  test(
    'accepts transactions with a null category from the existing schema',
    () {
      final transaction = AppTransaction.fromMap({
        'id': 1,
        'type': 'expense',
        'amount': 100,
        'account_id': 1,
        'to_account_id': null,
        'category_id': null,
        'date': '2025-03-10',
        'note': '',
      });

      expect(transaction.categoryId, isNull);
    },
  );
}
