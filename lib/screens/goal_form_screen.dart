import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/primary_button.dart';

class GoalFormScreen extends StatefulWidget {
  const GoalFormScreen({super.key, this.existing});

  /// Diisi saat mengubah target; kosong saat membuat target baru.
  final Goal? existing;

  @override
  State<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends State<GoalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  DateTime? _targetDate;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _amountCtrl.text = e.targetAmount.toString();
      _targetDate = e.targetDate;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final initialDate = _targetDate ?? DateTime.now();
    final earliest = DateTime(2020);
    final latest = DateTime(2100);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: initialDate.isBefore(earliest) ? initialDate : earliest,
      lastDate: initialDate.isAfter(latest) ? initialDate : latest,
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<FinanceProvider>();
    final navigator = Navigator.of(context);

    await provider.saveGoal(
      Goal(
        id: widget.existing?.id,
        name: _nameCtrl.text.trim(),
        targetAmount: int.parse(_amountCtrl.text),
        targetDate: _targetDate,
      ),
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Ubah Target' : 'Target Baru')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: appInput('Nama target', hint: 'Contoh: Laptop baru'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Nama target wajib diisi'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(12),
              ],
              decoration: appInput('Nominal target', prefixText: 'Rp '),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Nominal harus lebih dari 0';
                return null;
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: appInput(
                  'Tanggal target (opsional)',
                  suffixIcon: _targetDate == null
                      ? const Icon(Icons.calendar_today_outlined, size: 20)
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          tooltip: 'Hapus tanggal',
                          onPressed: () => setState(() => _targetDate = null),
                        ),
                ),
                child: Text(
                  _targetDate == null
                      ? 'Tanpa batas waktu'
                      : tanggal(_targetDate!),
                ),
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(label: 'Simpan', onPressed: _save),
          ],
        ),
      ),
    );
  }
}
