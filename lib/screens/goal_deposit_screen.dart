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

class GoalDepositScreen extends StatefulWidget {
  const GoalDepositScreen({super.key, required this.goal, this.existing});

  final Goal goal;
  final GoalDeposit? existing;

  @override
  State<GoalDepositScreen> createState() => _GoalDepositScreenState();
}

class _GoalDepositScreenState extends State<GoalDepositScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  int? _accountId;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final accounts = context.read<FinanceProvider>().accounts;
    final existing = widget.existing;
    if (existing != null) {
      _accountId = existing.accountId;
      _date = existing.date;
      _amountCtrl.text = existing.amount.toString();
      _noteCtrl.text = existing.note;
    } else if (accounts.isNotEmpty) {
      _accountId = accounts.first.id;
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
      final account = provider.accounts.firstWhere((a) => a.id == _accountId);
      final existing = widget.existing;
      final accountBalance =
          provider.balanceOf(account) +
          (existing?.accountId == account.id ? existing!.amount : 0);
      final remaining =
          widget.goal.targetAmount -
          provider.savedFor(widget.goal.id!) +
          (existing?.amount ?? 0);
      final warnings = <String>[
        if (amount > accountBalance)
          'Setoran ini akan membuat saldo ${account.name} menjadi negatif.',
        if (amount > remaining)
          'Setoran ini akan melebihi sisa target sebesar '
              '${rupiah(amount - remaining)}.',
      ];
      if (warnings.isNotEmpty) {
        final confirmed = await confirmAction(
          context,
          title: 'Periksa setoran',
          message: '${warnings.join('\n\n')}\n\nTetap lanjutkan?',
          confirmLabel: 'Tetap setor',
        );
        if (!confirmed) return;
      }

      final deposit = GoalDeposit(
        id: existing?.id,
        goalId: widget.goal.id!,
        accountId: _accountId!,
        amount: amount,
        date: _date,
        note: _noteCtrl.text.trim(),
      );
      error = existing == null
          ? await provider.addDeposit(deposit)
          : await provider.updateDeposit(deposit);
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

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null
              ? 'Setor ke ${widget.goal.name}'
              : 'Ubah setoran',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AmountFormField(controller: _amountCtrl, label: 'Nominal setoran'),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _accountId,
              decoration: appInput('Diambil dari akun'),
              items: [
                for (final a in f.accounts)
                  DropdownMenuItem(
                    value: a.id,
                    child: Text('${a.name} · ${rupiah(f.balanceOf(a))}'),
                  ),
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
            PrimaryButton(
              label: _saving
                  ? 'Menyimpan...'
                  : widget.existing == null
                  ? 'Simpan setoran'
                  : 'Simpan perubahan',
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
