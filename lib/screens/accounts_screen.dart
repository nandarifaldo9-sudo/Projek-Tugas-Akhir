import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/amount_form_field.dart';
import '../widgets/list_card.dart';
import '../widgets/undo_snack_bar.dart';

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
    } else {
      showUndoSnackBar(
        messenger,
        message: 'Akun dihapus.',
        onUndo: () => f.restoreAccount(a),
      );
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
    final scheme = Theme.of(context).colorScheme;

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
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Saldo dihitung otomatis: saldo awal ditambah pemasukan, '
              'ditambah/dikurangi transfer antar akun, lalu dikurangi '
              'pengeluaran dan pergerakan dana target.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
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
  bool _saving = false;

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
    if (_saving || !_formKey.currentState!.validate()) return;

    final provider = context.read<FinanceProvider>();
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    String? error;
    try {
      error = await provider.saveAccount(
        Account(
          id: widget.existing?.id,
          name: _nameCtrl.text.trim(),
          initialBalance: int.tryParse(_balanceCtrl.text) ?? 0,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    if (error != null) {
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
              AmountFormField(
                controller: _balanceCtrl,
                label: 'Saldo awal (opsional)',
                allowEmpty: true,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.expense)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.teal,
            foregroundColor: AppColors.navy,
          ),
          child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
        ),
      ],
    );
  }
}
