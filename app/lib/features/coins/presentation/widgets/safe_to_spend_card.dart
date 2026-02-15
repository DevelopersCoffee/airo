import 'package:flutter/material.dart';
import '../../domain/models/safe_to_spend.dart';

/// Safe to Spend Card Widget
///
/// Hero card showing daily safe-to-spend amount.
/// Displays the amount prominently with supporting info.
///
/// Phase: 1 (Foundation)
class SafeToSpendCard extends StatelessWidget {
  final SafeToSpend? safeToSpend;
  final VoidCallback? onTap;

  const SafeToSpendCard({
    super.key,
    this.safeToSpend,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = safeToSpend?.dailyAmountCents ?? 0;
    final isNegative = amount < 0;

    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isNegative
                  ? [Colors.red.shade700, Colors.red.shade900]
                  : [theme.colorScheme.primary, theme.colorScheme.primaryContainer],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Label
              Text(
                'Safe to Spend Today',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 12),

              // Amount
              Text(
                '₹${(amount.abs() / 100).toStringAsFixed(0)}',
                style: theme.textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),

              if (isNegative) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Over budget!',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Sub-info
              if (safeToSpend != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _InfoItem(
                      label: 'Remaining',
                      value: '₹${(safeToSpend!.remainingBudgetCents / 100).toStringAsFixed(0)}',
                    ),
                    const SizedBox(width: 24),
                    _InfoItem(
                      label: 'Days Left',
                      value: '${safeToSpend!.daysRemaining}',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _InfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

