import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:projek_tugas_akhir/models/models.dart';
import 'package:projek_tugas_akhir/providers/finance_provider.dart';
import 'package:projek_tugas_akhir/screens/transactions_screen.dart';
import 'package:provider/provider.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  testWidgets('combines month, account, and category filters', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    final previousMonth = DateTime(now.year, now.month - 1, 15);
    final finance = _TestFinanceProvider(
      testAccounts: const [
        Account(id: 1, name: 'Tunai'),
        Account(id: 2, name: 'Bank'),
      ],
      testCategories: const [
        Category(id: 1, name: 'Makanan', type: TxType.expense),
        Category(id: 2, name: 'Gaji', type: TxType.income),
      ],
      testTransactions: [
        AppTransaction(
          type: TxType.expense,
          amount: 10000,
          accountId: 1,
          categoryId: 1,
          date: currentMonth,
          note: 'Belanja Tunai',
        ),
        AppTransaction(
          type: TxType.expense,
          amount: 20000,
          accountId: 2,
          categoryId: 1,
          date: currentMonth,
          note: 'Belanja Bank',
        ),
        AppTransaction(
          type: TxType.income,
          amount: 30000,
          accountId: 2,
          categoryId: 2,
          date: currentMonth,
          note: 'Gaji Bank',
        ),
        AppTransaction(
          type: TxType.expense,
          amount: 40000,
          accountId: 2,
          categoryId: 1,
          date: previousMonth,
          note: 'Belanja bulan lalu',
        ),
      ],
    );
    addTearDown(finance.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<FinanceProvider>.value(
        value: finance,
        child: const MaterialApp(home: TransactionsScreen()),
      ),
    );

    await tester.tap(find.byTooltip('Filter transaksi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bulan ini'));
    await tester.tap(find.byType(DropdownButtonFormField<int?>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bank').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int?>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Makanan · Keluar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terapkan'));
    await tester.pumpAndSettle();

    expect(find.text('Belanja Bank'), findsOneWidget);
    expect(find.text('Belanja Tunai'), findsNothing);
    expect(find.text('Gaji Bank'), findsNothing);
    expect(find.text('Belanja bulan lalu'), findsNothing);
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.byTooltip('Filter transaksi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus filter'));
    await tester.pumpAndSettle();

    expect(find.text('Belanja Bank'), findsOneWidget);
    expect(find.text('Belanja Tunai'), findsOneWidget);
    expect(find.text('Gaji Bank'), findsOneWidget);
    expect(find.text('Belanja bulan lalu'), findsOneWidget);
    expect(find.text('3'), findsNothing);
  });
}

class _TestFinanceProvider extends FinanceProvider {
  _TestFinanceProvider({
    required this.testAccounts,
    required this.testCategories,
    required this.testTransactions,
  });

  final List<Account> testAccounts;
  final List<Category> testCategories;
  final List<AppTransaction> testTransactions;

  @override
  List<Account> get accounts => testAccounts;

  @override
  List<Category> get categories => testCategories;

  @override
  List<AppTransaction> get transactions => testTransactions;

  @override
  String accountName(int? id) {
    for (final account in testAccounts) {
      if (account.id == id) return account.name;
    }
    return '-';
  }

  @override
  String categoryName(int? id) {
    for (final category in testCategories) {
      if (category.id == id) return category.name;
    }
    return '-';
  }
}
