import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.t,
    this.showDate = false,
    this.onTap,
    this.onLongPress,
  });

  final AppTransaction t;
  final bool showDate;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final f = context.read<FinanceProvider>();
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isIncome = t.type == TxType.income;
    final isTransfer = t.type == TxType.transfer;
    final color = isIncome
        ? AppColors.income
        : isTransfer
        ? scheme.primary
        : AppColors.expense;
    final category = f.categoryName(t.categoryId);
    final sign = isIncome
        ? '+'
        : isTransfer
        ? ''
        : '−';
    final title = isTransfer
        ? 'Transfer'
        : t.note.isEmpty
        ? category
        : t.note;
    final parts = <String>[
      if (isTransfer)
        '${f.accountName(t.accountId)} → ${f.accountName(t.toAccountId)}'
      else ...[
        category,
        f.accountName(t.accountId),
      ],
      if (showDate) tanggal(t.date),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: dark ? const Color(0xFF394757) : AppColors.border,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isIncome
                        ? AppColors.incomeTint
                        : isTransfer
                        ? AppColors.tealTint
                        : AppColors.expenseTint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isIncome
                        ? Icons.arrow_downward_rounded
                        : isTransfer
                        ? Icons.swap_horiz_rounded
                        : Icons.arrow_upward_rounded,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        parts.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$sign${rupiah(t.amount)}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> confirmDelete(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Hapus transaksi?'),
      content: const Text(
        'Saldo akan dihitung ulang setelah transaksi ini dihapus.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
          child: const Text('Hapus'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
