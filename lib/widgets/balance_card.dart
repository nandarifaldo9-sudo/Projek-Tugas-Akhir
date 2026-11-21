import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'app_card.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.total,
    required this.accounts,
    this.hidden = false,
    this.onToggleHidden,
  });

  final int total;
  final List<MapEntry<String, int>> accounts;
  final bool hidden;
  final VoidCallback? onToggleHidden;

  String _money(int value) => hidden ? 'Rp ••••••' : rupiah(value);

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF243C58)
        : AppColors.navy;
    return AppCard(
      color: cardColor,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total saldo',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (onToggleHidden != null)
                IconButton(
                  onPressed: onToggleHidden,
                  tooltip: hidden ? 'Tampilkan saldo' : 'Sembunyikan saldo',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    hidden
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0x22FFFFFF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                  size: 19,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _money(total),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (accounts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in accounts) _AccountChip(a.key, _money(a.value)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip(this.name, this.balanceText);

  final String name;
  final String balanceText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$name  $balanceText',
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
    );
  }
}
