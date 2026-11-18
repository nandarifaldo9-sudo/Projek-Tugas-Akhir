import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../utils/date_picker.dart';
import '../utils/format.dart';
import '../widgets/amount_form_field.dart';
import '../widgets/primary_button.dart';

class GoalWithdrawalScreen extends StatefulWidget {
  const GoalWithdrawalScreen({super.key, required this.goal, this.existing});

  final Goal goal;
  final GoalWithdrawal? existing;

  @override
  State<GoalWithdrawalScreen> createState() => _GoalWithdrawalScreenState();
}

class _GoalWithdrawalScreenState extends State<GoalWithdrawalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  int? _accountId;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _accountId = existing.accountId;
      _date = existing.date;
      _amountController.text = existing.amount.toString();
      _noteController.text = existing.note;
    } else {
      final accounts = context.read<FinanceProvider>().accounts;
      _accountId = accounts.isEmpty ? null : accounts.first.id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await pilihTanggal(context, _date);
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final provider = context.read<FinanceProvider>();
    final withdrawal = GoalWithdrawal(
      id: widget.existing?.id,
      goalId: widget.goal.id!,
      accountId: _accountId!,
      amount: int.parse(_amountController.text),
      date: _date,
      note: _noteController.text.trim(),
    );
    final error = widget.existing == null
        ? await provider.addWithdrawal(withdrawal)
        : await provider.updateWithdrawal(withdrawal);
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Tarik dana target' : 'Ubah penarikan',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Saldo target tersedia ${rupiah(finance.savedFor(widget.goal.id!))}',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            AmountFormField(
              controller: _amountController,
              label: 'Nominal penarikan',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _accountId,
              isExpanded: true,
              decoration: appInput('Masukkan kembali ke akun'),
              items: [
                for (final account in finance.accounts)
                  DropdownMenuItem(
                    value: account.id,
                    child: Text(account.name),
                  ),
              ],
              onChanged: (value) => setState(() => _accountId = value),
              validator: (value) =>
                  value == null ? 'Pilih akun penerima' : null,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tanggal'),
              subtitle: Text(tanggal(_date)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
            ),
            TextFormField(
              controller: _noteController,
              decoration: appInput('Catatan (opsional)'),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: _saving ? 'Menyimpan...' : 'Simpan penarikan',
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
