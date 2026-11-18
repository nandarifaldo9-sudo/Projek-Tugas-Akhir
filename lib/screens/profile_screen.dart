import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/finance_provider.dart';
import '../services/export_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/list_card.dart';
import 'accounts_screen.dart';
import 'categories_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _export(BuildContext context) async {
    final f = context.read<FinanceProvider>();
    final messenger = ScaffoldMessenger.of(context);

    if (f.transactions.isEmpty && f.deposits.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Belum ada data untuk diekspor.')),
      );
      return;
    }

    try {
      await ExportService.shareCsv(f);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal mengekspor: $e')),
      );
    }
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AppCard(
            color: AppColors.navy,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Color(0x1FFFFFFF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Flowly',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Data tersimpan di HP ini · '
                            '${f.transactions.length} transaksi',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ListCard(
            leading: const IconBadge(
              icon: Icons.account_balance_wallet_outlined,
              color: AppColors.navy,
              tint: AppColors.tealTint,
            ),
            title: 'Kelola akun',
            subtitle: '${f.accounts.length} akun',
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _push(context, const AccountsScreen()),
          ),
          ListCard(
            leading: const IconBadge(
              icon: Icons.category_outlined,
              color: AppColors.navy,
              tint: AppColors.tealTint,
            ),
            title: 'Kelola kategori',
            subtitle: '${f.categories.length} kategori',
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _push(context, const CategoriesScreen()),
          ),
          ListCard(
            leading: const IconBadge(
              icon: Icons.file_download_outlined,
              color: AppColors.navy,
              tint: AppColors.tealTint,
            ),
            title: 'Ekspor CSV',
            subtitle: 'Simpan salinan data lewat menu bagikan',
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _export(context),
          ),
          ListCard(
            leading: const IconBadge(
              icon: Icons.info_outline_rounded,
              color: AppColors.navy,
              tint: AppColors.tealTint,
            ),
            title: 'Tentang Flowly',
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Flowly',
              applicationVersion: '1.0.0',
              children: const [
                SizedBox(height: 8),
                Text(
                  'Aplikasi pencatat keuangan pribadi yang berjalan offline. '
                      'Semua data tersimpan di HP ini, tanpa akun dan tanpa server.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}