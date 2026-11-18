import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../utils/date_picker.dart';
import '../utils/format.dart';
import '../widgets/amount_form_field.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/primary_button.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/undo_snack_bar.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key, this.existing});

  /// Diisi saat mengubah transaksi; kosong saat menambah.
  final AppTransaction? existing;

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  TxType _type = TxType.expense;
  int? _accountId;
  int? _toAccountId;
  int? _categoryId;
  DateTime _date = DateTime.now();
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _type = e.type;
      _accountId = e.accountId;
      _toAccountId = e.toAccountId;
      _categoryId = e.categoryId;
      _date = e.date;
      _amountCtrl.text = e.amount.toString();
      _noteCtrl.text = e.note;
    } else {
      final accounts = context.read<FinanceProvider>().accounts;
      if (accounts.isNotEmpty) _accountId = accounts.first.id;
      if (accounts.length > 1) _toAccountId = accounts[1].id;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await pilihTanggal(context, _date);
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    final provider = context.read<FinanceProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    String? error;
    try {
      final amount = int.parse(_amountCtrl.text);
      if (_type != TxType.income) {
        final account = provider.accounts.firstWhere((a) => a.id == _accountId);
        final balance = provider.balanceBeforeTransaction(
          account,
          widget.existing?.id,
        );
        if (amount > balance) {
          final confirmed = await confirmAction(
            context,
            title: 'Saldo akun tidak cukup',
            message: _type == TxType.transfer
                ? 'Transfer ${rupiah(amount)} akan membuat saldo ${account.name} '
                      'menjadi negatif. Tetap lanjutkan?'
                : 'Pengeluaran ${rupiah(amount)} akan membuat saldo '
                      '${account.name} menjadi negatif. Tetap lanjutkan?',
            confirmLabel: 'Tetap simpan',
          );
          if (!confirmed) return;
        }
      }

      final transaction = AppTransaction(
        id: widget.existing?.id,
        type: _type,
        amount: amount,
        accountId: _accountId!,
        toAccountId: _type == TxType.transfer ? _toAccountId : null,
        categoryId: _type == TxType.transfer ? null : _categoryId,
        date: _date,
        note: _noteCtrl.text.trim(),
      );
      error = _isEdit
          ? await provider.updateTransaction(transaction)
          : await provider.addTransaction(transaction);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    navigator.pop();
  }

  Future<void> _delete() async {
    if (_saving) return;
    final provider = context.read<FinanceProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (!await confirmDelete(context)) return;
    if (!mounted) return;
    setState(() => _saving = true);
    final error = await provider.deleteTransaction(widget.existing!.id!);
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    navigator.pop();
    showUndoSnackBar(
      messenger,
      message: 'Transaksi dihapus.',
      onUndo: () => provider.addTransaction(widget.existing!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceProvider>();
    final categories = f.categories.where((c) => c.type == _type).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Ubah Transaksi' : 'Tambah Transaksi'),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: AppColors.expense,
              tooltip: 'Hapus',
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final labelWidth = constraints.maxWidth / 3 - 24;
                return SegmentedButton<TxType>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: TxType.expense,
                      label: SizedBox(
                        width: labelWidth,
                        child: const Center(child: Text('Keluar')),
                      ),
                    ),
                    ButtonSegment(
                      value: TxType.income,
                      label: SizedBox(
                        width: labelWidth,
                        child: const Center(child: Text('Masuk')),
                      ),
                    ),
                    ButtonSegment(
                      value: TxType.transfer,
                      label: SizedBox(
                        width: labelWidth,
                        child: const Center(child: Text('Transfer')),
                      ),
                      enabled:
                          f.accounts.length > 1 || _type == TxType.transfer,
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: _saving
                      ? null
                      : (s) => setState(() {
                          _type = s.first;
                          _categoryId = null;
                          if (_type != TxType.transfer) _toAccountId = null;
                        }),
                );
              },
            ),
            const SizedBox(height: 16),
            AmountFormField(controller: _amountCtrl, label: 'Nominal'),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _accountId,
              decoration: appInput(
                _type == TxType.transfer ? 'Akun asal' : 'Akun',
              ),
              items: [
                for (final a in f.accounts)
                  DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: (v) => setState(() {
                _accountId = v;
                if (_toAccountId == v) {
                  final otherAccounts = f.accounts.where(
                    (account) => account.id != v,
                  );
                  _toAccountId = otherAccounts.isEmpty
                      ? null
                      : otherAccounts.first.id;
                }
              }),
              validator: (v) => v == null ? 'Pilih akun' : null,
            ),
            const SizedBox(height: 16),
            if (_type == TxType.transfer) ...[
              DropdownButtonFormField<int>(
                initialValue: _toAccountId,
                decoration: appInput('Akun tujuan'),
                items: [
                  for (final a in f.accounts.where((a) => a.id != _accountId))
                    DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: (v) => setState(() => _toAccountId = v),
                validator: (v) => v == null
                    ? 'Pilih akun tujuan'
                    : v == _accountId
                    ? 'Akun tujuan harus berbeda'
                    : null,
              ),
              const SizedBox(height: 16),
            ] else ...[
              DropdownButtonFormField<int>(
                initialValue: _categoryId,
                decoration: appInput('Kategori'),
                items: [
                  for (final c in categories)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
                validator: (v) => v == null ? 'Pilih kategori' : null,
              ),
              const SizedBox(height: 16),
            ],
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: appInput(
                  'Tanggal',
                  suffixIcon: const Icon(
                    Icons.calendar_today_outlined,
                    size: 20,
                  ),
                ),
                child: Text(tanggal(_date)),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteCtrl,
              decoration: appInput('Catatan (opsional)'),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: _saving ? 'Menyimpan...' : 'Simpan',
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
