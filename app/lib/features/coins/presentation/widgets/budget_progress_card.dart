import 'package:flutter/material.dart';
import '../../domain/entities/budget.dart';
import '../../domain/models/budget_status.dart';

/// Budget Progress Card Widget
///
/// Displays a budget with visual progress indicator.
/// Shows spent vs limit with color-coded status.
///
/// Phase: 1 (Foundation)
class BudgetProgressCard extends StatelessWidget {
  final Budget budget;
  final BudgetStatus? status;
  final VoidCallback? onTap;

  const BudgetProgressCard({
    super.key,
    required this.budget,
    this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentUsed = status?.percentUsed ?? 0.0;
    final spentCents = status?.spentCents ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      budget.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StatusChip(percentUsed: percentUsed),
                ],
              ),
              const SizedBox(height: 12),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentUsed.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getProgressColor(percentUsed),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Amount Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₹${(spentCents / 100).toStringAsFixed(0)} spent',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    '₹${(budget.limitCents / 100).toStringAsFixed(0)} limit',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),

              // Period Badge
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  budget.period.name.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getProgressColor(double percent) {
    if (percent >= 1.0) return Colors.red;
    if (percent >= 0.9) return Colors.red.shade400;
    if (percent >= 0.75) return Colors.orange;
    if (percent >= 0.5) return Colors.amber;
    return Colors.green;
  }
}

class _StatusChip extends StatelessWidget {
  final double percentUsed;

  const _StatusChip({required this.percentUsed});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;

    if (percentUsed >= 1.0) {
      label = 'Over';
      color = Colors.red;
    } else if (percentUsed >= 0.9) {
      label = 'Critical';
      color = Colors.red.shade400;
    } else if (percentUsed >= 0.75) {
      label = 'Warning';
      color = Colors.orange;
    } else {
      label = 'On Track';
      color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

