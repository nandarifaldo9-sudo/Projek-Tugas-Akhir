import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/list_card.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  Future<void> _delete(BuildContext context, Account a) async {
    final f = context.read<FinanceProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final ok = await confirmAction(
      context,
      title: 'Hapus akun?',
      message: 'Akun "${a.name}" akan dihapus.',
    );
    if (!ok) return;

    final error = await f.deleteAccount(a.id!);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  void _openDialog(BuildContext context, [Account? existing]) {
    showDialog<void>(
      context: context,
      builder: (_) => _AccountDialog(existing: existing),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Akun'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Tambah akun',
            onPressed: () => _openDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (final a in f.accounts)
            ListCard(
              leading: const IconBadge(
                icon: Icons.account_balance_wallet_outlined,
                color: AppColors.navy,
                tint: AppColors.tealTint,
              ),
              title: a.name,
              subtitle: 'Saldo ${rupiah(f.balanceOf(a))}',
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: AppColors.expense,
                tooltip: 'Hapus',
                onPressed: () => _delete(context, a),
              ),
              onTap: () => _openDialog(context, a),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Saldo dihitung otomatis: saldo awal ditambah pemasukan, '
                  'dikurangi pengeluaran dan setoran target.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountDialog extends StatefulWidget {
  const _AccountDialog({this.existing});

  final Account? existing;

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _balanceCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _balanceCtrl = TextEditingController(
      text: (e == null || e.initialBalance == 0)
          ? ''
          : e.initialBalance.toString(),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<FinanceProvider>();
    final navigator = Navigator.of(context);

    final error = await provider.saveAccount(
      Account(
        id: widget.existing?.id,
        name: _nameCtrl.text.trim(),
        initialBalance: int.tryParse(_balanceCtrl.text) ?? 0,
      ),
    );

    if (error != null) {
      if (!mounted) return;
      setState(() => _error = error);
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return AlertDialog(
      title: Text(isEdit ? 'Ubah akun' : 'Tambah akun'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: appInput('Nama akun', hint: 'Contoh: E-wallet'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nama akun wajib diisi'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _balanceCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                decoration: appInput('Saldo awal (opsional)', prefixText: 'Rp '),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.expense),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.teal,
            foregroundColor: AppColors.navy,
          ),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}