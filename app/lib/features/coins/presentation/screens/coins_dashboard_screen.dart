import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/locale_settings.dart';
import '../../application/providers/dashboard_providers.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/models/budget_status.dart';
import '../../domain/services/finance_insight_service.dart';
import '../../domain/services/quick_add_expense_parser.dart';
import '../widgets/expense_card.dart';
import 'add_expense_screen.dart';
import 'groups_list_screen.dart';

/// Coins Dashboard Screen
///
/// Main screen for the Coins feature showing:
/// - Safe-to-spend amount
/// - Quick stats (today's spending, pending settlements)
/// - Recent transactions
/// - Budget overview
/// - Quick action buttons
///
/// Phase: 1 (Foundation)
/// See: docs/features/coins/UI_WIREFRAMES.md (Screen 1)
class CoinsDashboardScreen extends ConsumerWidget {
  final VoidCallback? onOpenAddExpense;

  const CoinsDashboardScreen({super.key, this.onOpenAddExpense});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coins'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Navigate to notifications
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // TODO: Navigate to settings
            },
          ),
        ],
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading dashboard: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(dashboardDataProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.refresh(dashboardRefreshProvider.future),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Safe to Spend Card
                  _SafeToSpendCard(data: data),
                  const SizedBox(height: 12),

                  _FinancialSnapshotSection(data: data),
                  const SizedBox(height: 16),

                  const _QuickAddExpenseCard(),
                  const SizedBox(height: 16),

                  // Quick Actions
                  const _QuickActionsRow(),
                  const SizedBox(height: 16),

                  _SplitwiseSummarySection(data: data),
                  const SizedBox(height: 16),

                  // Recent Transactions
                  _RecentTransactionsSection(transactions: data.recentExpenses),
                  const SizedBox(height: 16),

                  // Budget Overview
                  _BudgetOverviewSection(budgetStatuses: data.budgetStatuses),
                  const SizedBox(height: 16),

                  _FinanceInsightsSection(data: data),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: Builder(
        builder: (buttonContext) => FloatingActionButton.extended(
          onPressed: () => _openAddExpense(buttonContext),
          icon: const Icon(Icons.add),
          label: const Text('Add Expense'),
        ),
      ),
    );
  }

  void _openAddExpense(BuildContext context) {
    final override = onOpenAddExpense;
    if (override != null) {
      override();
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddExpenseScreen()));
  }
}

// TODO: Implement these widget classes in separate files
class _SafeToSpendCard extends ConsumerWidget {
  final DashboardData data;
  const _SafeToSpendCard({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final formatter = ref.watch(currencyFormatterProvider);
    final safeToSpend = data.safeToSpend;
    final amount = safeToSpend == null
        ? formatter.formatCents(0)
        : formatter.formatCents(safeToSpend.amountCents);

    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Safe to Spend Today',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              amount,
              style: theme.textTheme.displayMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            if (safeToSpend != null) ...[
              const SizedBox(height: 12),
              Text(
                '${safeToSpend.daysRemaining} days left · '
                '${formatter.formatCents(safeToSpend.remainingCents)} remain',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickAddExpenseCard extends StatefulWidget {
  const _QuickAddExpenseCard();

  @override
  State<_QuickAddExpenseCard> createState() => _QuickAddExpenseCardState();
}

class _QuickAddExpenseCardState extends State<_QuickAddExpenseCard> {
  final _controller = TextEditingController();
  final _parser = const QuickAddExpenseParser();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick add',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Type naturally. AIRO drafts the expense for review.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('coins_quick_add_field'),
              controller: _controller,
              textInputAction: TextInputAction.go,
              decoration: const InputDecoration(
                hintText: 'Pizza 420 split with Alex',
                prefixIcon: Icon(Icons.auto_awesome),
              ),
              onSubmitted: (_) => _draftExpense(context),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _draftExpense(context),
                icon: const Icon(Icons.bolt),
                label: const Text('Draft expense'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _draftExpense(BuildContext context) {
    final draft = _parser.parse(_controller.text);
    if (draft == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Try an amount like "Pizza 420 split with Alex".'),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddExpenseScreen(initialDraft: draft)),
    );
  }
}

class _FinancialSnapshotSection extends ConsumerWidget {
  final DashboardData data;
  const _FinancialSnapshotSection({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = ref.watch(currencyFormatterProvider);
    final budgetRemaining = data.budgetStatuses.fold<int>(
      0,
      (sum, status) =>
          sum + (status.remainingCents > 0 ? status.remainingCents : 0),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = constraints.maxWidth < 520 ? 8.0 : 12.0;
        final tileWidth = constraints.maxWidth < 520
            ? (constraints.maxWidth - spacing) / 2
            : (constraints.maxWidth - spacing * 3) / 4;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _MetricTile(
              width: tileWidth,
              label: 'Today spent',
              value: formatter.formatCents(data.spentTodayCents.abs()),
              icon: Icons.today_outlined,
            ),
            _MetricTile(
              width: tileWidth,
              label: 'Monthly spend',
              value: formatter.formatCents(data.spentThisMonthCents.abs()),
              icon: Icons.calendar_month_outlined,
            ),
            _MetricTile(
              width: tileWidth,
              label: 'Budget remaining',
              value: formatter.formatCents(budgetRemaining),
              icon: Icons.account_balance_wallet_outlined,
            ),
            _MetricTile(
              width: tileWidth,
              label: 'Due payments',
              value: '${data.pendingSettlements}',
              icon: Icons.receipt_long_outlined,
            ),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final IconData icon;

  const _MetricTile({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(height: 10),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _QuickActionButton(
          icon: Icons.add,
          label: 'Add Expense',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AddExpenseScreen())),
        ),
        _QuickActionButton(
          icon: Icons.call_split,
          label: 'Split New Expense',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const GroupsListScreen())),
        ),
        const _QuickActionButton(
          icon: Icons.pie_chart_outline,
          label: 'Budgets',
        ),
        const _QuickActionButton(icon: Icons.camera_alt, label: 'Scan Receipt'),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _QuickActionButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(36),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          children: [
            CircleAvatar(radius: 24, child: Icon(icon)),
            const SizedBox(height: 6),
            SizedBox(
              width: 76,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, height: 1.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplitwiseSummarySection extends ConsumerWidget {
  final DashboardData data;
  const _SplitwiseSummarySection({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Groups & settlements',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SettlementFact(
                    label: 'Shared groups',
                    value: '${data.totalGroups} groups',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SettlementFact(
                    label: 'Pending',
                    value:
                        '${data.pendingSettlements} settlement'
                        '${data.pendingSettlements == 1 ? '' : 's'}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              data.pendingSettlements == 0
                  ? 'No pending settlements. Split a bill when money is shared.'
                  : 'Review who owes whom before settling up.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GroupsListScreen()),
                ),
                icon: const Icon(Icons.call_split),
                label: const Text('Split New Expense'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettlementFact extends StatelessWidget {
  final String label;
  final String value;

  const _SettlementFact({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTransactionsSection extends StatelessWidget {
  final List<Transaction> transactions;
  const _RecentTransactionsSection({required this.transactions});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent expenses',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (transactions.isEmpty)
              const Text('Add your first expense to begin tracking spending.')
            else
              ...transactions.take(5).map((transaction) {
                return ExpenseCard(transaction: transaction);
              }),
          ],
        ),
      ),
    );
  }
}

class _BudgetOverviewSection extends StatelessWidget {
  final List<BudgetStatus> budgetStatuses;
  const _BudgetOverviewSection({required this.budgetStatuses});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Budget overview',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (budgetStatuses.isEmpty)
              const Text('Create a monthly budget to see remaining spend here.')
            else
              ...budgetStatuses.take(4).map((status) {
                final percentUsed = status.percentUsed;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(status.budget.displayName),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: (percentUsed / 100).clamp(0.0, 1.0),
                    ),
                  ),
                  trailing: Text('${percentUsed.round()}%'),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _FinanceInsightsSection extends StatelessWidget {
  final DashboardData data;

  const _FinanceInsightsSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final insights = const FinanceInsightService().generate(
      recentTransactions: data.recentExpenses,
      budgetStatuses: data.budgetStatuses,
    );
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI finance insights',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ...insights.take(2).map((insight) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _insightColor(
                      theme,
                      insight.severity,
                    ).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _insightColor(
                        theme,
                        insight.severity,
                      ).withValues(alpha: 0.30),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    leading: Icon(
                      _insightIcon(insight.severity),
                      color: _insightColor(theme, insight.severity),
                    ),
                    title: Text(
                      insight.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(insight.message),
                    trailing: TextButton(
                      onPressed: () {},
                      child: Text(insight.actionLabel),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  IconData _insightIcon(FinanceInsightSeverity severity) {
    return switch (severity) {
      FinanceInsightSeverity.success => Icons.check_circle_outline,
      FinanceInsightSeverity.warning => Icons.warning_amber_outlined,
      FinanceInsightSeverity.danger => Icons.error_outline,
      FinanceInsightSeverity.info => Icons.auto_awesome,
    };
  }

  Color _insightColor(ThemeData theme, FinanceInsightSeverity severity) {
    return switch (severity) {
      FinanceInsightSeverity.success => Colors.green,
      FinanceInsightSeverity.warning => Colors.orange,
      FinanceInsightSeverity.danger => theme.colorScheme.error,
      FinanceInsightSeverity.info => theme.colorScheme.primary,
    };
  }
}
