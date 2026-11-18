import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/goal_card.dart';
import '../widgets/list_card.dart';
import '../widgets/primary_button.dart';
import '../widgets/undo_snack_bar.dart';
import 'goal_deposit_screen.dart';
import 'goal_form_screen.dart';
import 'goal_withdrawal_screen.dart';

class GoalDetailScreen extends StatelessWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final int goalId;

  Future<void> _deleteGoal(BuildContext context, Goal g) async {
    final f = context.read<FinanceProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final deletedDeposits = f.depositsFor(g.id!).toList();
    final deletedWithdrawals = f.withdrawalsFor(g.id!).toList();

    final ok = await confirmAction(
      context,
      title: 'Hapus target?',
      message:
          'Target "${g.name}" beserta seluruh histori setorannya akan '
          'dihapus. Dana setoran akan dikembalikan ke saldo akun masing-masing.',
    );
    if (!ok) return;

    final error = await f.deleteGoal(g.id!);
    if (!context.mounted) return;
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    navigator.pop();
    showUndoSnackBar(
      messenger,
      message: 'Target dan histori setorannya dihapus.',
      onUndo: () => f.restoreGoal(g, deletedDeposits, deletedWithdrawals),
    );
  }

  Future<void> _deleteDeposit(BuildContext context, GoalDeposit d) async {
    final f = context.read<FinanceProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final ok = await confirmAction(
      context,
      title: 'Hapus setoran?',
      message:
          'Setoran sebesar ${rupiah(d.amount)} akan dihapus dan '
          'saldo akun akan dikembalikan.',
    );
    if (!ok) return;

    final error = await f.deleteDeposit(d.id!);
    if (!context.mounted) return;
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    } else {
      showUndoSnackBar(
        messenger,
        message: 'Setoran dihapus.',
        onUndo: () => f.addDeposit(d),
      );
    }
  }

  Future<void> _deleteWithdrawal(
    BuildContext context,
    GoalWithdrawal withdrawal,
  ) async {
    final finance = context.read<FinanceProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmAction(
      context,
      title: 'Batalkan penarikan?',
      message: 'Penarikan ini akan dihapus dan saldo target dikembalikan.',
    );
    if (!confirmed) return;
    final error = await finance.deleteWithdrawal(withdrawal.id!);
    if (!context.mounted) return;
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    } else {
      showUndoSnackBar(
        messenger,
        message: 'Penarikan dibatalkan.',
        onUndo: () => finance.addWithdrawal(withdrawal),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceProvider>();
    final scheme = Theme.of(context).colorScheme;
    final goal = f.goalById(goalId);

    if (goal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Target')),
        body: const Center(child: Text('Target tidak ditemukan.')),
      );
    }

    final saved = f.savedFor(goalId);
    final deposits = f.depositsFor(goalId);
    final withdrawals = f.withdrawalsFor(goalId);
    final monthlyContribution = f.monthlyGoalContribution(goal);

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Ubah target',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => GoalFormScreen(existing: goal)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Hapus target',
            onPressed: () => _deleteGoal(context, goal),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GoalCard(goal: goal, saved: saved, onTap: () {}),
          const SizedBox(height: 16),
          if (goal.targetDate != null && monthlyContribution > 0) ...[
            Text(
              'Perlu menabung sekitar ${rupiah(monthlyContribution)} per bulan '
              'hingga ${tanggal(goal.targetDate!)}.',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'Tambah setoran',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GoalDepositScreen(goal: goal),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: saved <= 0
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GoalWithdrawalScreen(goal: goal),
                          ),
                        ),
                  child: const Text('Tarik dana'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Riwayat Setoran',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (deposits.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Belum ada setoran. Tekan tombol di atas untuk setor.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          for (final d in deposits)
            ListCard(
              leading: const IconBadge(
                icon: Icons.savings_outlined,
                color: AppColors.teal,
                tint: AppColors.tealTint,
              ),
              title: '+${rupiah(d.amount)}',
              subtitle:
                  '${f.accountName(d.accountId)} · ${tanggal(d.date)}${d.note.isNotEmpty ? ' · ${d.note}' : ''}',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GoalDepositScreen(goal: goal, existing: d),
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: AppColors.expense,
                tooltip: 'Hapus',
                onPressed: () => _deleteDeposit(context, d),
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'Riwayat Penarikan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (withdrawals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Belum ada penarikan.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          for (final withdrawal in withdrawals)
            ListCard(
              leading: const IconBadge(
                icon: Icons.south_west_rounded,
                color: AppColors.expense,
                tint: AppColors.expenseTint,
              ),
              title: '−${rupiah(withdrawal.amount)}',
              subtitle:
                  '${f.accountName(withdrawal.accountId)} · '
                  '${tanggal(withdrawal.date)}'
                  '${withdrawal.note.isNotEmpty ? ' · ${withdrawal.note}' : ''}',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      GoalWithdrawalScreen(goal: goal, existing: withdrawal),
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: AppColors.expense,
                tooltip: 'Batalkan penarikan',
                onPressed: () => _deleteWithdrawal(context, withdrawal),
              ),
            ),
        ],
      ),
    );
  }
}
