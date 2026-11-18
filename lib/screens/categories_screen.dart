import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/list_card.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  Future<void> _delete(BuildContext context, Category c) async {
    final f = context.read<FinanceProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final ok = await confirmAction(
      context,
      title: 'Hapus kategori?',
      message: 'Kategori "${c.name}" akan dihapus.',
    );
    if (!ok) return;

    final error = await f.deleteCategory(c);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  void _openDialog(BuildContext context, [Category? existing]) {
    showDialog<void>(
      context: context,
      builder: (_) => _CategoryDialog(existing: existing),
    );
  }

  Widget _section(
      BuildContext context,
      FinanceProvider f,
      String title,
      TxType type,
      ) {
    final isIncome = type == TxType.income;
    final items = f.categories.where((c) => c.type == type).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (final c in items)
          ListCard(
            leading: IconBadge(
              icon: isIncome
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: isIncome ? AppColors.income : AppColors.expense,
              tint: isIncome ? AppColors.incomeTint : AppColors.expenseTint,
            ),
            title: c.name,
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: AppColors.expense,
              tooltip: 'Hapus',
              onPressed: () => _delete(context, c),
            ),
            onTap: () => _openDialog(context, c),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Kategori'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Tambah kategori',
            onPressed: () => _openDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          _section(context, f, 'Pengeluaran', TxType.expense),
          _section(context, f, 'Pemasukan', TxType.income),
        ],
      ),
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({this.existing});

  final Category? existing;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  TxType _type = TxType.expense;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    if (e != null) _type = e.type;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<FinanceProvider>();
    final navigator = Navigator.of(context);

    final error = await provider.saveCategory(
      Category(
        id: widget.existing?.id,
        name: _nameCtrl.text.trim(),
        type: _type,
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
      title: Text(isEdit ? 'Ubah kategori' : 'Tambah kategori'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Jenis kategori tidak bisa diubah setelah dibuat.
              if (!isEdit) ...[
                SegmentedButton<TxType>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: TxType.expense,
                      label: Text('Keluar'),
                    ),
                    ButtonSegment(value: TxType.income, label: Text('Masuk')),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) => setState(() => _type = s.first),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: appInput('Nama kategori'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nama kategori wajib diisi'
                    : null,
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