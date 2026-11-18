import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../utils/date_picker.dart';
import '../utils/format.dart';
import '../widgets/amount_form_field.dart';
import '../widgets/app_card.dart';

class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  Future<void> _openForm(BuildContext context, [RecurringRule? rule]) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => RecurringRuleFormScreen(existing: rule),
      ),
    );
  }

  Future<void> _delete(BuildContext context, RecurringRule rule) async {
    final finance = context.read<FinanceProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus jadwal berulang?'),
        content: const Text('Transaksi yang sudah dibuat tetap tersimpan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus jadwal'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final error = await finance.deleteRecurringRule(rule.id!);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi berulang'),
        actions: [
          IconButton(
            tooltip: 'Tambah jadwal',
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: finance.recurringRules.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Belum ada jadwal. Transaksi akan dibuat otomatis saat '
                  'aplikasi dibuka setelah tanggal jatuh tempo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final rule in finance.recurringRules)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  rule.note.isEmpty
                                      ? finance.categoryName(rule.categoryId)
                                      : rule.note,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Switch(
                                value: rule.enabled,
                                onChanged: (value) async {
                                  final error = await finance
                                      .toggleRecurringRule(rule, value);
                                  if (error != null && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(error)),
                                    );
                                  }
                                },
                              ),
                              PopupMenuButton<String>(
                                onSelected: (action) {
                                  if (action == 'edit') {
                                    _openForm(context, rule);
                                  } else {
                                    _delete(context, rule);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Ubah jadwal'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Hapus jadwal'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Text(
                            '${rupiah(rule.amount)} · '
                            '${rule.frequency == RecurrenceFrequency.weekly ? 'Mingguan' : 'Bulanan'}',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Berikutnya ${tanggal(rule.nextDate)} · '
                            '${finance.accountName(rule.accountId)}',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class RecurringRuleFormScreen extends StatefulWidget {
  const RecurringRuleFormScreen({super.key, this.existing});

  final RecurringRule? existing;

  @override
  State<RecurringRuleFormScreen> createState() =>
      _RecurringRuleFormScreenState();
}

class _RecurringRuleFormScreenState extends State<RecurringRuleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  TxType _type = TxType.expense;
  RecurrenceFrequency _frequency = RecurrenceFrequency.monthly;
  int? _accountId;
  int? _categoryId;
  DateTime _nextDate = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final rule = widget.existing;
    if (rule != null) {
      _type = rule.type;
      _frequency = rule.frequency;
      _accountId = rule.accountId;
      _categoryId = rule.categoryId;
      _nextDate = rule.nextDate;
      _amountController.text = rule.amount.toString();
      _noteController.text = rule.note;
    } else {
      final finance = context.read<FinanceProvider>();
      _accountId = finance.accounts.firstOrNull?.id;
      _categoryId = finance.categories
          .where((category) => category.type == _type)
          .firstOrNull
          ?.id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await pilihTanggal(context, _nextDate);
    if (date != null) setState(() => _nextDate = date);
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final finance = context.read<FinanceProvider>();
    setState(() => _saving = true);
    final rule = widget.existing;
    final error = await finance.saveRecurringRule(
      RecurringRule(
        id: rule?.id,
        type: _type,
        amount: int.parse(_amountController.text),
        accountId: _accountId!,
        categoryId: _categoryId,
        frequency: _frequency,
        startDate: rule?.startDate ?? _nextDate,
        nextDate: _nextDate,
        dayOfMonth: _nextDate.day,
        note: _noteController.text.trim(),
        enabled: rule?.enabled ?? true,
      ),
    );
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
    final categories = finance.categories
        .where((category) => category.type == _type)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Jadwal baru' : 'Ubah jadwal'),
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
              onSelectionChanged: (selection) => setState(() {
                _type = selection.first;
                _categoryId = null;
              }),
            ),
            const SizedBox(height: 16),
            AmountFormField(controller: _amountController, label: 'Nominal'),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _accountId,
              isExpanded: true,
              decoration: appInput('Akun'),
              items: [
                for (final account in finance.accounts)
                  DropdownMenuItem(
                    value: account.id,
                    child: Text(account.name),
                  ),
              ],
              onChanged: (value) => setState(() => _accountId = value),
              validator: (value) => value == null ? 'Pilih akun' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _categoryId,
              isExpanded: true,
              decoration: appInput('Kategori'),
              items: [
                for (final category in categories)
                  DropdownMenuItem(
                    value: category.id,
                    child: Text(category.name),
                  ),
              ],
              onChanged: (value) => setState(() => _categoryId = value),
              validator: (value) => value == null ? 'Pilih kategori' : null,
            ),
            const SizedBox(height: 16),
            SegmentedButton<RecurrenceFrequency>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: RecurrenceFrequency.weekly,
                  label: Text('Mingguan'),
                ),
                ButtonSegment(
                  value: RecurrenceFrequency.monthly,
                  label: Text('Bulanan'),
                ),
              ],
              selected: {_frequency},
              onSelectionChanged: (selection) =>
                  setState(() => _frequency = selection.first),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mulai berikutnya'),
              subtitle: Text(tanggal(_nextDate)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
            ),
            TextFormField(
              controller: _noteController,
              decoration: appInput('Catatan (opsional)'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Menyimpan...' : 'Simpan jadwal'),
            ),
          ],
        ),
      ),
    );
  }
}
