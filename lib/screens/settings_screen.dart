import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../providers/app_settings.dart';
import '../providers/finance_provider.dart';
import '../services/export_service.dart';
import '../services/screen_security.dart';
import '../theme/app_theme.dart';
import '../utils/auth_error_message.dart';
import '../widgets/app_card.dart';
import '../widgets/list_card.dart';

enum _ResetChoice { cancel, backup, proceed }

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _toggleLock(
    BuildContext context,
    AppSettings settings,
    bool enabled,
  ) async {
    if (enabled) {
      try {
        final authenticated = await LocalAuthentication().authenticate(
          localizedReason: 'Verifikasi untuk mengaktifkan kunci Flowly',
          biometricOnly: false,
        );
        if (!authenticated || !context.mounted) return;
      } on LocalAuthException catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Autentikasi gagal: ${authErrorMessage(error)}'),
          ),
        );
        return;
      }
    }
    final saved = await settings.setAppLockEnabled(enabled);
    if (!saved && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengaturan kunci gagal disimpan.')),
      );
    }
  }

  Future<void> _resetAll(BuildContext context) async {
    final finance = context.read<FinanceProvider>();
    final settings = context.read<AppSettings>();
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showDialog<_ResetChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus semua data?'),
        content: const Text(
          'Semua transaksi, akun, kategori, target, anggaran, dan transaksi '
          'berulang akan dihapus permanen dan tidak bisa dikembalikan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _ResetChoice.cancel),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _ResetChoice.backup),
            child: const Text('Buat backup'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.expense,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, _ResetChoice.proceed),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (choice == _ResetChoice.backup) {
      try {
        await ExportService.shareBackupCsv(finance);
        await settings.markBackupNow();
      } catch (error) {
        messenger.showSnackBar(
          SnackBar(content: Text('Gagal membuat backup: $error')),
        );
      }
      return;
    }
    if (choice != _ResetChoice.proceed) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _TypeToConfirmDialog(),
    );
    if (confirmed != true) return;
    final error = await finance.resetAllData();
    if (error == null) await settings.setDefaultAccountId(null);
    messenger.showSnackBar(
      SnackBar(content: Text(error ?? 'Semua data sudah dihapus.')),
    );
  }

  static String _timeoutLabel(int seconds) =>
      seconds < 60 ? '$seconds dtk' : '${seconds ~/ 60} mnt';

  static String _backupLabel(DateTime? backupAt) {
    if (backupAt == null) return 'Belum pernah dicadangkan';
    final difference = DateTime.now().difference(backupAt);
    final days = difference.inDays;
    if (days == 0) return 'Terakhir dicadangkan: hari ini';
    if (days == 1) return 'Terakhir dicadangkan: 1 hari lalu';
    return 'Terakhir dicadangkan: $days hari lalu';
  }

  static bool _backupIsOld(DateTime? backupAt) =>
      backupAt == null || DateTime.now().difference(backupAt).inDays > 30;

  Future<void> _toggleSecureScreen(
    BuildContext context,
    AppSettings settings,
    bool enabled,
  ) async {
    try {
      await ScreenSecurity.setEnabled(enabled);
    } on PlatformException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengubah layar aman: ${error.message}')),
      );
      return;
    }
    final saved = await settings.setSecureScreenEnabled(enabled);
    if (!saved && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengaturan layar aman gagal disimpan.')),
      );
    }
  }

  Future<void> _createBackup(
    BuildContext context,
    FinanceProvider finance,
    AppSettings settings,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ExportService.shareBackupCsv(finance);
      await settings.markBackupNow();
    } catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal membuat backup: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final finance = context.watch<FinanceProvider>();
    final accountIds = finance.accounts.map((a) => a.id).toSet();
    final defaultAccountId = accountIds.contains(settings.defaultAccountId)
        ? settings.defaultAccountId
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          AppCard(
            child: Row(
              children: [
                const IconBadge(
                  icon: Icons.settings_rounded,
                  color: AppColors.navy,
                  tint: AppColors.tealTint,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pengaturan aplikasi',
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Sesuaikan tampilan, privasi, dan pengelolaan data.',
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
          const SizedBox(height: 24),
          const _SettingsSection(
            title: 'Tampilan',
            icon: Icons.palette_outlined,
          ),
          AppCard(
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ThemeMode.light, label: Text('Terang')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Gelap')),
                ButtonSegment(value: ThemeMode.system, label: Text('Sistem')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (value) => settings.setThemeMode(value.first),
            ),
          ),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bahasa',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'id', label: Text('Indonesia')),
                    ButtonSegment(value: 'en', label: Text('English')),
                  ],
                  selected: {settings.languageCode},
                  onSelectionChanged: (value) =>
                      settings.setLanguageCode(value.first),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ListCard(
            leading: const IconBadge(
              icon: Icons.visibility_off_outlined,
              color: AppColors.navy,
              tint: AppColors.tealTint,
            ),
            title: 'Sembunyikan saldo',
            subtitle: 'Sembunyikan saldo di layar Beranda',
            trailing: Switch(
              value: settings.hideBalance,
              onChanged: settings.setHideBalance,
              activeThumbColor: AppColors.teal,
            ),
          ),
          const SizedBox(height: 24),
          const _SettingsSection(title: 'Privasi', icon: Icons.shield_outlined),
          ListCard(
            leading: const IconBadge(
              icon: Icons.lock_outline_rounded,
              color: AppColors.navy,
              tint: AppColors.tealTint,
            ),
            title: 'Kunci aplikasi',
            subtitle: 'Gunakan biometrik atau kunci layar',
            trailing: Switch(
              value: settings.appLockEnabled,
              onChanged: (value) => _toggleLock(context, settings, value),
              activeThumbColor: AppColors.teal,
            ),
          ),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Waktu kunci otomatis',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    for (final seconds in AppSettings.lockTimeoutOptions)
                      ButtonSegment(
                        value: seconds,
                        label: Text(_timeoutLabel(seconds)),
                      ),
                  ],
                  selected: {settings.lockTimeoutSeconds},
                  onSelectionChanged: settings.appLockEnabled
                      ? (value) => settings.setLockTimeoutSeconds(value.first)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ListCard(
            leading: const IconBadge(
              icon: Icons.phonelink_lock_outlined,
              color: AppColors.navy,
              tint: AppColors.tealTint,
            ),
            title: 'Layar aman',
            subtitle: 'Sembunyikan aplikasi dan blokir screenshot',
            trailing: Switch(
              value: settings.secureScreenEnabled,
              onChanged: (value) =>
                  _toggleSecureScreen(context, settings, value),
              activeThumbColor: AppColors.teal,
            ),
          ),
          const SizedBox(height: 24),
          const _SettingsSection(
            title: 'Transaksi',
            icon: Icons.receipt_long_outlined,
          ),
          AppCard(
            child: DropdownButtonFormField<int?>(
              initialValue: defaultAccountId,
              decoration: appInput('Akun default'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Akun pertama'),
                ),
                for (final a in finance.accounts)
                  DropdownMenuItem<int?>(value: a.id, child: Text(a.name)),
              ],
              onChanged: settings.setDefaultAccountId,
            ),
          ),
          const SizedBox(height: 24),
          const _SettingsSection(
            title: 'Anggaran',
            icon: Icons.pie_chart_outline_rounded,
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Peringatan saat pengeluaran mencapai',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    for (final percent in AppSettings.budgetWarnOptions)
                      ButtonSegment(value: percent, label: Text('$percent%')),
                  ],
                  selected: {settings.budgetWarnPercent},
                  onSelectionChanged: (value) =>
                      settings.setBudgetWarnPercent(value.first),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SettingsSection(title: 'Data', icon: Icons.backup_outlined),
          ListCard(
            leading: IconBadge(
              icon: _backupIsOld(settings.lastBackupAt)
                  ? Icons.warning_amber_rounded
                  : Icons.cloud_done_outlined,
              color: _backupIsOld(settings.lastBackupAt)
                  ? AppColors.expense
                  : AppColors.navy,
              tint: _backupIsOld(settings.lastBackupAt)
                  ? AppColors.expenseTint
                  : AppColors.tealTint,
            ),
            title: _backupLabel(settings.lastBackupAt),
            subtitle: _backupIsOld(settings.lastBackupAt)
                ? 'Buat cadangan agar data tetap aman'
                : 'Simpan cadangan CSV secara berkala',
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _createBackup(context, finance, settings),
          ),
          const SizedBox(height: 24),
          const _SettingsSection(
            title: 'Zona berbahaya',
            icon: Icons.warning_amber_rounded,
          ),
          ListCard(
            leading: const IconBadge(
              icon: Icons.delete_forever_outlined,
              color: AppColors.expense,
              tint: AppColors.expenseTint,
            ),
            title: 'Hapus semua data',
            titleColor: AppColors.expense,
            subtitle: 'Mengembalikan aplikasi seperti baru dipasang',
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.expense,
            ),
            onTap: () => _resetAll(context),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.teal),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TypeToConfirmDialog extends StatefulWidget {
  const _TypeToConfirmDialog();

  @override
  State<_TypeToConfirmDialog> createState() => _TypeToConfirmDialogState();
}

class _TypeToConfirmDialogState extends State<_TypeToConfirmDialog> {
  final _controller = TextEditingController();

  bool get _matches => _controller.text.trim().toUpperCase() == 'HAPUS';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Konfirmasi terakhir'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ketik HAPUS untuk menghapus semua data.'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: appInput('Ketik HAPUS'),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.expense,
            foregroundColor: Colors.white,
          ),
          onPressed: _matches ? () => Navigator.pop(context, true) : null,
          child: const Text('Hapus permanen'),
        ),
      ],
    );
  }
}
