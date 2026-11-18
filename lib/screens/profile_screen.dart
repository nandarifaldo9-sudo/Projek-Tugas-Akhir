import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../providers/finance_provider.dart';
import '../services/export_service.dart';
import '../services/backup_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/list_card.dart';
import 'accounts_screen.dart';
import 'budget_screen.dart';
import 'categories_screen.dart';
import 'recurring_screen.dart';
import 'settings_screen.dart';

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
      messenger.showSnackBar(SnackBar(content: Text('Gagal mengekspor: $e')));
    }
  }

  Future<void> _exportBackup(BuildContext context) async {
    final finance = context.read<FinanceProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ExportService.shareBackupCsv(finance);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal membuat backup: $error')),
      );
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    final finance = context.read<FinanceProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Impor backup?'),
        content: const Text('Data akan digabung. Entri duplikat dilewati.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Pilih file'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (!context.mounted || picked == null) return;
      final bytes = await picked.readAsBytes();
      final result = await BackupService.importCsv(finance, utf8.decode(bytes));
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Impor selesai: ${result.imported} ditambahkan, '
            '${result.skipped} dilewati.',
          ),
        ),
      );
    } on FormatException catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Format CSV tidak valid: ${error.message}')),
      );
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal mengimpor CSV: $error')),
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
            child: Row(
              children: [
                const IconBadge(
                  icon: Icons.account_balance_wallet_rounded,
                  color: AppColors.navy,
                  tint: AppColors.tealTint,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Flowly',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${f.transactions.length} transaksi · Data di perangkat',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12.5,
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
              icon: Icons.pie_chart_outline_rounded,
              color: AppColors.navy,
              tint: AppColors.tealTint,
            ),
            title: 'Anggaran kategori',
            subtitle: 'Batas pengeluaran per kategori',
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _push(context, const BudgetScreen()),
          ),
          ListCard(
            leading: const IconBadge(
              icon: Icons.repeat_rounded,
              color: AppColors.navy,
              tint: AppColors.tealTint,
            ),
            title: 'Transaksi berulang',
            subtitle: 'Jadwalkan transaksi otomatis',
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _push(context, const RecurringScreen()),
          ),
          ListCard(
            leading: const IconBadge(
              icon: Icons.settings_outlined,
              color: AppColors.navy,
              tint: AppColors.tealTint,
            ),
            title: 'Pengaturan',
            subtitle: 'Tema & kunci aplikasi',
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _push(context, const SettingsScreen()),
          ),
          ListCard(
            leading: const IconBadge(
              icon: Icons.backup_outlined,
              color: AppColors.navy,
              tint: AppColors.tealTint,
            ),
            title: 'Backup data (CSV)',
            subtitle: 'Cadangkan atau pulihkan data',
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (sheetContext) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.file_upload_outlined),
                        title: const Text('Buat backup CSV'),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _exportBackup(context);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.file_download_outlined),
                        title: const Text('Impor backup'),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _restoreBackup(context);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ListCard(
            leading: const IconBadge(
              icon: Icons.file_download_outlined,
              color: AppColors.navy,
              tint: AppColors.tealTint,
            ),
            title: 'Ekspor CSV',
            subtitle: 'Ekspor transaksi ke CSV',
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
                Text('Pencatat keuangan offline. Data tersimpan di perangkat.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
