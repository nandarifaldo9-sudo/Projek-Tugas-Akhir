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
  });
}
