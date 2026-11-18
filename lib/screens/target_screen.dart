import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/finance_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/goal_card.dart';
import 'goal_detail_screen.dart';
import 'goal_form_screen.dart';

class TargetScreen extends StatelessWidget {
  const TargetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Target'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Target baru',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GoalFormScreen()),
            ),
          ),
        ],
      ),
      body: f.goals.isEmpty
          ? const EmptyState(
              icon: Icons.flag_outlined,
              title: 'Belum ada target',
              message:
                  'Buat target, misalnya laptop baru atau dana darurat, '
                  'lalu setor sedikit demi sedikit. Tekan + di kanan atas.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                for (final g in f.goals)
                  GoalCard(
                    goal: g,
                    saved: f.savedFor(g.id!),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GoalDetailScreen(goalId: g.id!),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
