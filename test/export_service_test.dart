import 'package:flutter_test/flutter_test.dart';
import 'package:projek_tugas_akhir/models/models.dart';
import 'package:projek_tugas_akhir/providers/finance_provider.dart';
import 'package:projek_tugas_akhir/services/export_service.dart';

void main() {
  test('CSV escapes formula-like notes and quotes special characters', () {
    final provider = _ExportFinanceProvider(
      testTransactions: [
        AppTransaction(
          id: 2,
          type: TxType.expense,
          amount: 100,
          accountId: 1,
          categoryId: 1,
          date: DateTime(2025, 3, 10),
          note: '=1+1',
        ),
        AppTransaction(
          id: 1,
          type: TxType.expense,
          amount: 200,
          accountId: 1,
          categoryId: 1,
          date: DateTime(2025, 3, 10),
          note: 'note, "quoted"\nnext line',
        ),
      ],
    );
    addTearDown(provider.dispose);

    final csv = ExportService.buildCsv(provider);

    expect(csv, contains(",'=1+1\r\n"));
    expect(csv, contains('"note, ""quoted""\nnext line"'));
    expect(csv.indexOf("'=1+1"), lessThan(csv.indexOf('"note')));
  });
}

class _ExportFinanceProvider extends FinanceProvider {
  _ExportFinanceProvider({required this.testTransactions});

  final List<AppTransaction> testTransactions;

  @override
  List<AppTransaction> get transactions => testTransactions;

  @override
  List<GoalDeposit> get deposits => const [];

  @override
  String categoryName(int? id) => 'Makanan';

  @override
  String accountName(int? id) => 'Tunai';

  @override
  String goalName(int? id) => 'Target';
}
