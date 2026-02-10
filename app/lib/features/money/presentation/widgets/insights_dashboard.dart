import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/money_provider.dart';
import '../../domain/models/insight_models.dart';

/// Dashboard widget showing spending insights and trends
class InsightsDashboard extends ConsumerWidget {
  const InsightsDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(spendingSummaryProvider);
    final healthAsync = ref.watch(budgetHealthProvider);
    final trendAsync = ref.watch(spendingTrendProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Insights', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),

        // Spending summary card
        summaryAsync.when(
          data: (summary) => _SpendingSummaryCard(summary: summary),
          loading: () => const _LoadingCard(),
          error: (_, _) => const _ErrorCard(message: 'Failed to load summary'),
        ),

        const SizedBox(height: 12),

        // Trend card
        trendAsync.when(
          data: (trend) => _TrendCard(trend: trend),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),

        const SizedBox(height: 12),

        // Budget health
        healthAsync.when(
          data: (health) => _BudgetHealthCard(health: health),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _SpendingSummaryCard extends StatelessWidget {
  final SpendingSummary summary;

  const _SpendingSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This Month', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: 'Spent',
                  value: summary.totalExpensesFormatted,
                  color: Colors.red,
                ),
                _StatItem(
                  label: 'Income',
                  value: summary.totalIncomeFormatted,
                  color: Colors.green,
                ),
                _StatItem(
                  label: 'Daily Avg',
                  value: summary.dailyAverageFormatted,
                  color: Colors.blue,
                ),
              ],
            ),
            if (summary.topCategories.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Top Categories',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...summary.topCategories
                  .take(3)
                  .map(
                    (cat) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(cat.category),
                          Text(
                            cat.amountFormatted,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _TrendCard extends StatelessWidget {
  final SpendingTrend trend;

  const _TrendCard({required this.trend});

  @override
  Widget build(BuildContext context) {
    final icon = trend.isSpendingUp ? Icons.trending_up : Icons.trending_down;
    final color = trend.isSpendingUp ? Colors.red : Colors.green;

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(trend.changeDescription),
        subtitle: Text('vs last month'),
      ),
    );
  }
}

class _BudgetHealthCard extends StatelessWidget {
  final BudgetHealth health;

  const _BudgetHealthCard({required this.health});

  @override
  Widget build(BuildContext context) {
    Color healthColor;
    IconData healthIcon;
    String healthText;

    if (health.hasExceeded) {
      healthColor = Colors.red;
      healthIcon = Icons.warning;
      healthText = '${health.exceededBudgets} budget(s) exceeded';
    } else if (health.hasWarnings) {
      healthColor = Colors.orange;
      healthIcon = Icons.info;
      healthText = '${health.warningBudgets} budget(s) near limit';
    } else {
      healthColor = Colors.green;
      healthIcon = Icons.check_circle;
      healthText = 'All budgets healthy';
    }

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(healthIcon, color: healthColor, size: 32),
            title: Text('Budget Health: ${health.overallHealthScore}%'),
            subtitle: Text(healthText),
          ),
          if (health.insights.isNotEmpty) ...[
            const Divider(),
            ...health.insights
                .take(2)
                .map(
                  (insight) => ListTile(
                    dense: true,
                    leading: Icon(
                      _getInsightIcon(insight.type),
                      color: _getSeverityColor(insight.severity),
                      size: 20,
                    ),
                    title: Text(
                      insight.message,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  IconData _getInsightIcon(InsightType type) {
    switch (type) {
      case InsightType.exceeded:
        return Icons.error;
      case InsightType.warning:
        return Icons.warning;
      case InsightType.saving:
        return Icons.savings;
      case InsightType.trend:
        return Icons.trending_up;
      case InsightType.tip:
        return Icons.lightbulb;
    }
  }

  Color _getSeverityColor(InsightSeverity severity) {
    switch (severity) {
      case InsightSeverity.low:
        return Colors.blue;
      case InsightSeverity.medium:
        return Colors.orange;
      case InsightSeverity.high:
        return Colors.red;
    }
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.error, color: Colors.red),
        title: Text(message),
      ),
    );
  }
}
