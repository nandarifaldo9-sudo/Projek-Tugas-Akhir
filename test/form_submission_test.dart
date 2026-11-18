import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:projek_tugas_akhir/models/models.dart';
import 'package:projek_tugas_akhir/providers/finance_provider.dart';
import 'package:projek_tugas_akhir/screens/add_transaction_screen.dart';
import 'package:projek_tugas_akhir/screens/goal_deposit_screen.dart';
import 'package:projek_tugas_akhir/screens/goal_form_screen.dart';
import 'package:provider/provider.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  testWidgets(
    'transaction form ignores a second save while the first is pending',
    (tester) async {
      final provider = _SlowFinanceProvider();
      addTearDown(provider.dispose);

      await tester.pumpWidget(_app(provider, const AddTransactionScreen()));
      await _openForm(tester);
      await tester.enterText(find.byType(TextFormField).first, '100');
      await tester.tap(find.byType(DropdownButtonFormField<int>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Makanan').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan'));
      await tester.pump();

      expect(provider.transactionCalls, 1);
      expect(find.text('Menyimpan...'), findsOneWidget);
      await tester.tap(find.text('Menyimpan...'));
      expect(provider.transactionCalls, 1);

      provider.transactionResult.complete(null);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Transaksi dihapus.'), findsNothing);
    },
  );

  testWidgets('deleting a transaction offers undo after the route closes', (
    tester,
  ) async {
    final provider = _SlowFinanceProvider();
    addTearDown(provider.dispose);
    final transaction = AppTransaction(
      id: 9,
      type: TxType.expense,
      amount: 100,
      accountId: 1,
      categoryId: 1,
      date: DateTime.now(),
    );

    await tester.pumpWidget(
      _app(provider, AddTransactionScreen(existing: transaction)),
    );
    await _openForm(tester);
    await tester.tap(find.byTooltip('Hapus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();

    expect(find.text('Transaksi dihapus.'), findsOneWidget);
    await tester.tap(find.text('URUNGKAN'));
    await tester.pump();
    expect(provider.transactionCalls, 1);
    provider.transactionResult.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('Perubahan berhasil dipulihkan.'), findsOneWidget);
  });

  testWidgets('goal form disables saving while a write is pending', (
    tester,
  ) async {
    final provider = _SlowFinanceProvider();
    addTearDown(provider.dispose);

    await tester.pumpWidget(_app(provider, const GoalFormScreen()));
    await _openForm(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Dana darurat');
    await tester.enterText(find.byType(TextFormField).last, '10000');
    await tester.tap(find.text('Simpan'));
    await tester.pump();

    expect(provider.goalCalls, 1);
    expect(find.text('Menyimpan...'), findsOneWidget);
    provider.goalResult.complete(null);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('goal deposit disables saving while a write is pending', (
    tester,
  ) async {
    final provider = _SlowFinanceProvider();
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      _app(
        provider,
        const GoalDepositScreen(
          goal: Goal(id: 1, name: 'Dana darurat', targetAmount: 10000),
        ),
      ),
    );
    await _openForm(tester);
    await tester.enterText(find.byType(TextFormField).first, '100');
    await tester.tap(find.text('Simpan setoran'));
    await tester.pump();

    expect(provider.depositCalls, 1);
    expect(find.text('Menyimpan...'), findsOneWidget);
    provider.depositResult.complete(null);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

Widget _app(FinanceProvider provider, Widget screen) {
  return ChangeNotifierProvider<FinanceProvider>.value(
    value: provider,
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => screen),
            ),
            child: const Text('Buka formulir'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openForm(WidgetTester tester) async {
  await tester.tap(find.text('Buka formulir'));
  await tester.pumpAndSettle();
}

class _SlowFinanceProvider extends FinanceProvider {
  final transactionResult = Completer<String?>();
  final goalResult = Completer<String?>();
  final depositResult = Completer<String?>();
  int transactionCalls = 0;
  int goalCalls = 0;
  int depositCalls = 0;

  @override
  List<Account> get accounts => const [
    Account(id: 1, name: 'Tunai', initialBalance: 1000),
  ];

  @override
  List<Category> get categories => const [
    Category(id: 1, name: 'Makanan', type: TxType.expense),
  ];

  @override
  List<Goal> get goals => const [
    Goal(id: 1, name: 'Dana darurat', targetAmount: 10000),
  ];

  @override
  List<GoalDeposit> get deposits => const [];

  @override
  Future<String?> addTransaction(AppTransaction transaction) {
    transactionCalls++;
    return transactionResult.future;
  }

  @override
  Future<String?> saveGoal(Goal goal) {
    goalCalls++;
    return goalResult.future;
  }

  @override
  Future<String?> addDeposit(GoalDeposit deposit) {
    depositCalls++;
    return depositResult.future;
  }

  @override
  Future<String?> deleteTransaction(int id) async => null;
}
