import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/primary_button.dart';

class GoalDepositScreen extends StatefulWidget {
  const GoalDepositScreen({super.key, required this.goal});

  final Goal goal;

  @override
  State<GoalDepositScreen> createState() => _GoalDepositScreenState();
}

class _GoalDepositScreenState extends State<GoalDepositScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  int? _accountId;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    final accounts = context.read<FinanceProvider>().accounts;
    if (accounts.isNotEmpty) _accountId = accounts.first.id;
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

    await provider.addDeposit(
      GoalDeposit(
        goalId: widget.goal.id!,
        accountId: _accountId!,
        amount: int.parse(_amountCtrl.text),
        date: _date,
        note: _noteCtrl.text.trim(),
      ),
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceProvider>();

    return Scaffold(
      appBar: AppBar(title: Text('Setor ke ${widget.goal.name}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(12),
              ],
              decoration: appInput('Nominal setoran', prefixText: 'Rp '),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Nominal harus lebih dari 0';
                return null;
              },
            ),
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
            PrimaryButton(label: 'Simpan setoran', onPressed: _save),
          ],
        ),
      ),
    );
  }
}
