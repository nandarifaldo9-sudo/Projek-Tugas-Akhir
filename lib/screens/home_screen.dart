import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/balance_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/summary_card.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onSeeAll});

  /// Dipanggil saat "Lihat semua" ditekan (pindah ke tab Transaksi).
  final VoidCallback onSeeAll;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat pagi';
    if (h < 15) return 'Selamat siang';
    if (h < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  void _openForm(BuildContext context, AppTransaction t) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddTransactionScreen(existing: t)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceProvider>();
    final scheme = Theme.of(context).colorScheme;

    Widget body;
    if (f.loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (f.error != null) {
      body = EmptyState(
        icon: Icons.error_outline,
        title: 'Gagal memuat data',
        message: f.error,
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            '${_greeting()},',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Ringkasan keuangan',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tanggalLengkap(DateTime.now()),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 16),
          BalanceCard(
            total: f.totalBalance,
            accounts: [
              for (final a in f.accounts) MapEntry(a.name, f.balanceOf(a)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SummaryCard(
                  label: 'Masuk bulan ini',
                  amount: f.incomeThisMonth(),
                  color: AppColors.income,
                  tint: AppColors.incomeTint,
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SummaryCard(
                  label: 'Keluar bulan ini',
                  amount: f.expenseThisMonth(),
                  color: AppColors.expense,
                  tint: AppColors.expenseTint,
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Transaksi terbaru',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              TextButton(onPressed: onSeeAll, child: const Text('Lihat semua')),
            ],
          ),
          const SizedBox(height: 4),
          if (f.transactions.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Belum ada transaksi',
              message:
                  'Tekan tombol + untuk mencatat pemasukan atau '
                  'pengeluaran pertamamu.',
            ),
          for (final t in f.transactions.take(5))
            TransactionTile(
              t: t,
              showDate: true,
              onTap: () => _openForm(context, t),
            ),
        ],
      );
    }

    return Scaffold(body: SafeArea(child: body));
  }
}
