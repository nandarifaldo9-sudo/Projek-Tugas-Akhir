import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/amount_form_field.dart';
import '../widgets/app_card.dart';
import '../widgets/confirm_dialog.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  Future<void> _editBudget(
    BuildContext context,
    FinanceProvider finance,
    Category category,
  ) async {
    final controller = TextEditingController(
      text: finance.budgetFor(category.id!).toString(),
    );
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          finance.budgetFor(category.id!) == 0
              ? 'Atur anggaran'
              : 'Ubah anggaran',
        ),
        content: Form(
          key: formKey,
          child: AmountFormField(controller: controller, label: category.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    final amount = saved == true ? int.parse(controller.text) : null;
    controller.dispose();
    if (saved != true || !context.mounted) return;
    final error = await finance.saveBudget(
      CategoryBudget(categoryId: category.id!, amount: amount!),
    );
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _deleteBudget(
    BuildContext context,
    FinanceProvider finance,
    Category category,
  ) async {
    final confirmed = await confirmAction(
      context,
      title: 'Hapus anggaran?',
      message: 'Anggaran kategori ${category.name} akan dihapus.',
    );
    if (!confirmed || !context.mounted) return;
    final error = await finance.deleteBudget(category.id!);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final categories = finance.categories
        .where((category) => category.type == TxType.expense)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Anggaran bulanan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Peringatan muncul sekali per kategori setiap bulan saat '
              'pengeluaran mencapai 80% anggaran.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          for (final category in categories)
            _BudgetCard(
              category: category,
              limit: finance.budgetFor(category.id!),
              spent: finance.spentForCategory(category.id!, now),
              onEdit: () => _editBudget(context, finance, category),
              onDelete: () => _deleteBudget(context, finance, category),
            ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.category,
    required this.limit,
    required this.spent,
    required this.onEdit,
    required this.onDelete,
  });

  final Category category;
  final int limit;
  final int spent;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = limit == 0 ? 0.0 : spent / limit;
    final color = ratio >= 1
        ? AppColors.expense
        : ratio >= 0.8
        ? const Color(0xFFE6A23C)
        : AppColors.teal;
    final status = limit == 0
        ? 'Belum diatur'
        : ratio > 1
        ? 'Melebihi ${rupiah(spent - limit)}'
        : ratio == 1
        ? 'Anggaran habis'
        : ratio >= 0.8
        ? 'Hampir habis'
        : 'Sisa ${rupiah(limit - spent)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    category.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (limit > 0)
                  IconButton(
                    tooltip: 'Hapus anggaran',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                IconButton(
                  tooltip: limit == 0 ? 'Atur anggaran' : 'Ubah anggaran',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            Text(
              limit == 0
                  ? 'Pengeluaran bulan ini ${rupiah(spent)}'
                  : '${rupiah(spent)} dari ${rupiah(limit)}',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            if (limit > 0) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0, 1).toDouble(),
                  minHeight: 8,
                  backgroundColor: scheme.outlineVariant,
                  color: color,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              status,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
