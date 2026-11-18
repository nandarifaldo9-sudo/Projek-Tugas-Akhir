import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'app_card.dart';

class GoalProgressBar extends StatelessWidget {
  const GoalProgressBar({super.key, required this.value});

  /// 0.0 sampai 1.0 (lebih dari 1 dianggap penuh).
  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0).toDouble(),
        minHeight: 10,
        backgroundColor: AppColors.border,
        color: value >= 1 ? AppColors.income : AppColors.teal,
      ),
    );
  }
}

class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.goal,
    required this.saved,
    required this.onTap,
  });

  final Goal goal;
  final int saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = saved / goal.targetAmount;
    final percent = math.min(100, (progress * 100).floor());
    final remaining = goal.targetAmount - saved;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      goal.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GoalProgressBar(value: progress),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    rupiah(saved),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'dari ${rupiah(goal.targetAmount)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                remaining > 0 ? 'Sisa ${rupiah(remaining)}' : 'Target tercapai',
                style: TextStyle(
                  color: remaining > 0
                      ? AppColors.textSecondary
                      : AppColors.income,
                  fontSize: 12.5,
                  fontWeight: remaining > 0 ? FontWeight.w400 : FontWeight.w600,
                ),
              ),
              if (goal.targetDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Target ${tanggal(goal.targetDate!)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}