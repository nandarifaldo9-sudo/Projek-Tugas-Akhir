import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/primary_button.dart';
import '../widgets/transaction_tile.dart';

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
  int? _categoryId;
  DateTime _date = DateTime.now();

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _type = e.type;
      _accountId = e.accountId;
      _categoryId = e.categoryId;
      _date = e.date;
      _amountCtrl.text = e.amount.toString();
      _noteCtrl.text = e.note;
    } else {
      final accounts = context.read<FinanceProvider>().accounts;
      if (accounts.isNotEmpty) _accountId = accounts.first.id;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final earliest = DateTime(2020);
    final latest = DateTime(2100);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _date.isBefore(earliest) ? _date : earliest,
      lastDate: _date.isAfter(latest) ? _date : latest,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<FinanceProvider>();
    final navigator = Navigator.of(context);

    final t = AppTransaction(
      id: widget.existing?.id,
      type: _type,
      amount: int.parse(_amountCtrl.text),
      accountId: _accountId!,
      categoryId: _categoryId!,
      date: _date,
      note: _noteCtrl.text.trim(),
    );

    if (_isEdit) {
      await provider.updateTransaction(t);
    } else {
      await provider.addTransaction(t);
    }
    navigator.pop();
  }

  Future<void> _delete() async {
    final provider = context.read<FinanceProvider>();
    final navigator = Navigator.of(context);

    if (!await confirmDelete(context)) return;
    await provider.deleteTransaction(widget.existing!.id!);
    navigator.pop();
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
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<TxType>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: TxType.expense, label: Text('Keluar')),
                ButtonSegment(value: TxType.income, label: Text('Masuk')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _categoryId = null;
              }),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(12),
              ],
              decoration: appInput('Nominal', prefixText: 'Rp '),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Nominal harus lebih dari 0';
                return null;
              },
            ),
            const SizedBox(height: 16),
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
            DropdownButtonFormField<int>(
              initialValue: _accountId,
              decoration: appInput('Akun'),
              items: [
                for (final a in f.accounts)
                  DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: (v) => setState(() => _accountId = v),
              validator: (v) => v == null ? 'Pilih akun' : null,
            ),
            const SizedBox(height: 16),
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
            PrimaryButton(label: 'Simpan', onPressed: _save),
          ],
        ),
      ),
    );
  }
}
