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
import 'goal_deposit_screen.dart';
import 'goal_form_screen.dart';

class GoalDetailScreen extends StatelessWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final int goalId;

  Future<void> _deleteGoal(BuildContext context, Goal g) async {
    final f = context.read<FinanceProvider>();
    final navigator = Navigator.of(context);

    final ok = await confirmAction(
      context,
      title: 'Hapus target?',
      message: 'Target "${g.name}" dan seluruh histori setorannya akan dihapus.',
    );
    if (!ok) return;

    await f.deleteGoal(g.id!);
    navigator.pop();
  }

  Future<void> _deleteDeposit(BuildContext context, GoalDeposit d) async {
    final f = context.read<FinanceProvider>();

    final ok = await confirmAction(
      context,
      title: 'Hapus setoran?',
      message: 'Setoran sebesar ${rupiah(d.amount)} akan dihapus dan '
          'saldo akun akan dikembalikan.',
    );
    if (!ok) return;

    await f.deleteDeposit(d.id!);
  }

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceProvider>();
    final goal = f.goalById(goalId);

    if (goal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Target')),
        body: const Center(child: Text('Target tidak ditemukan.')),
      );
    }

    final saved = f.savedFor(goalId);
    final deposits = f.depositsFor(goalId);

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Ubah target',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GoalFormScreen(existing: goal),
              ),
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
          PrimaryButton(
            label: 'Tambah Setoran',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GoalDepositScreen(goal: goal),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Riwayat Setoran',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (deposits.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Belum ada setoran. Tekan tombol di atas untuk setor.',
                  style: TextStyle(color: AppColors.textSecondary),
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
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: AppColors.expense,
                tooltip: 'Hapus',
                onPressed: () => _deleteDeposit(context, d),
              ),
            ),
        ],
      ),
    );
  }
}
