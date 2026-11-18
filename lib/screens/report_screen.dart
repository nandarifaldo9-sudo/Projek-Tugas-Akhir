import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/app_card.dart';
import '../widgets/charts.dart';
import '../widgets/summary_card.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  /// Bulan yang dipilih pengguna. null = bulan ini (mengikuti jam HP).
  DateTime? _selected;

  DateTime get _month {
    final now = DateTime.now();
    return _selected ?? DateTime(now.year, now.month);
  }

  bool get _isCurrentMonth => _selected == null;

  void _shift(int delta) {
    final target = DateTime(_month.year, _month.month + delta);
    final now = DateTime.now();
    final current = DateTime(now.year, now.month);
    setState(() => _selected = target.isBefore(current) ? target : null);
  }

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceProvider>();
    final scheme = Theme.of(context).colorScheme;
    final month = _month;

    final entries = f.expenseByCategory(month).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalExpense = entries.fold<int>(0, (s, e) => s + e.value);
    final trendData = f.monthlyTotals(month);

    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Bulan sebelumnya',
                onPressed: () => _shift(-1),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    bulanTahun(month),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'Bulan berikutnya',
                onPressed: _isCurrentMonth ? null : () => _shift(1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SummaryCard(
                  label: 'Masuk',
                  amount: f.incomeInMonth(month),
                  color: AppColors.income,
                  tint: AppColors.incomeTint,
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SummaryCard(
                  label: 'Keluar',
                  amount: f.expenseInMonth(month),
                  color: AppColors.expense,
                  tint: AppColors.expenseTint,
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pengeluaran per kategori',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Belum ada pengeluaran di bulan ini.',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  )
                else ...[
                  Center(
                    child: DonutChart(
                      values: [for (final e in entries) e.value],
                      semanticLabel:
                          'Pengeluaran per kategori. '
                          '${entries.map((e) => '${f.categoryName(e.key)} ${rupiah(e.value)}').join(', ')}. '
                          'Total ${rupiah(totalExpense)}.',
                      center: SizedBox(
                        width: 90,
                        child: FittedBox(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Keluar',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                rupiah(totalExpense),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < entries.length; i++)
                    _LegendRow(
                      color: chartPalette[i % chartPalette.length],
                      name: f.categoryName(entries[i].key),
                      amount: entries[i].value,
                      total: totalExpense,
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tren 6 bulan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Semantics(
                  container: true,
                  excludeSemantics: true,
                  label:
                      'Tren pemasukan dan pengeluaran enam bulan. '
                      '${trendData.map((m) => '${bulanTahun(m.month)}: masuk ${rupiah(m.income)}, keluar ${rupiah(m.expense)}').join('; ')}.',
                  child: TrendBarChart(data: trendData),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.name,
    required this.amount,
    required this.total,
  });

  final Color color;
  final String name;
  final int amount;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = amount * 100 / total;
    final pctText = pct < 1 ? '<1%' : '${pct.round()}%';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Text(
            rupiah(amount),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(
            width: 44,
            child: Text(
              pctText,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
