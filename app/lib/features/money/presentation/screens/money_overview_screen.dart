import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/dictionary/dictionary.dart';
import '../../../../core/routing/route_names.dart';
import '../../application/providers/money_provider.dart';
import '../../domain/models/money_models.dart';
// ignore: unused_import
import '../widgets/transaction_upload_dialog.dart';
import 'add_expense_screen.dart';
import 'budgets_screen.dart';
import 'transactions_list_screen.dart';
import '../../../../shared/widgets/responsive_center.dart';

/// Money overview screen - Finance Hub
/// Purpose: Money management & transactions
class MoneyOverviewScreen extends ConsumerWidget {
  const MoneyOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalBalance = ref.watch(totalBalanceProvider);
    final accounts = ref.watch(accountsProvider);
    // Use stream provider for reactive transactions
    final transactionsStream = ref.watch(transactionsStreamProvider);
    final budgetsStream = ref.watch(budgetsStreamProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // No AppBar here - global AppBar is in AppShell
    return Scaffold(
      body: DictionarySelectionArea(
        child: ResponsiveCenter(
          maxWidth: ResponsiveBreakpoints.contentMaxWidth,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Balance Hero - Above the fold
                totalBalance.when(
                  data: (balance) {
                    final dollars = balance ~/ 100;
                    final cents = (balance % 100).abs();
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 32,
                        horizontal: 24,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primaryContainer,
                            colorScheme.primaryContainer.withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Available Balance',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.onPrimaryContainer.withValues(
                                alpha: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '\$$dollars.${cents.toString().padLeft(2, '0')}',
                            style: theme.textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => Container(
                    width: double.infinity,
                    height: 120,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, _) => Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Error loading balance',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Primary Actions - Above the fold
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _PrimaryActionButton(
                      icon: Icons.call_split,
                      label: 'Split Bill',
                      onTap: () => context.push(RouteNames.billSplit),
                    ),
                    _PrimaryActionButton(
                      icon: Icons.qr_code_scanner,
                      label: 'Scan',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Coming soon!')),
                        );
                      },
                    ),
                    _PrimaryActionButton(
                      icon: Icons.send,
                      label: 'Send Money',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Coming soon!')),
                        );
                      },
                    ),
                    _PrimaryActionButton(
                      icon: Icons.request_page,
                      label: 'Request',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Coming soon!')),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Accounts section
                Text('Accounts', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                accounts.when(
                  data: (accountsList) {
                    if (accountsList.isEmpty) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const ListTile(
                                title: Text('No accounts yet'),
                                subtitle: Text(
                                  'Add your first account to get started',
                                ),
                                leading: Icon(Icons.account_balance_wallet),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () {
                                  // TODO: Navigate to add account screen
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Add Account'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: accountsList
                              .map(
                                (account) => ListTile(
                                  title: Text(account.name),
                                  subtitle: Text(account.type),
                                  trailing: Text(
                                    account.balanceFormatted,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    );
                  },
                  loading: () => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (_, _) => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Error loading accounts'),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Recent transactions section
                Text(
                  'Recent Transactions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                transactionsStream.when(
                  data: (txnList) {
                    if (txnList.isEmpty) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No transactions yet',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add your first expense to start tracking',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: () => _navigateToAddExpense(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Expense'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            ...txnList
                                .take(5)
                                .map(
                                  (txn) => ListTile(
                                    title: Text(txn.description),
                                    subtitle: Text(txn.category),
                                    trailing: Text(
                                      txn.amountFormatted,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: txn.isExpense
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                    ),
                                  ),
                                ),
                            if (txnList.length > 5)
                              TextButton(
                                onPressed: () =>
                                    _navigateToAllTransactions(context),
                                child: const Text('View All Transactions'),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                  loading: () => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (_, _) => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Error loading transactions'),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Budgets section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Budgets',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    TextButton(
                      onPressed: () => _navigateToBudgets(context),
                      child: const Text('Manage'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                budgetsStream.when(
                  data: (budgetList) {
                    if (budgetList.isEmpty) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(
                                Icons.trending_down,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No budgets yet',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Create budgets to track your spending',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: () => _navigateToBudgets(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Create Budget'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: budgetList.map((budget) {
                            // Color based on warning level
                            Color progressColor;
                            switch (budget.warningLevel) {
                              case BudgetWarningLevel.exceeded:
                                progressColor = Colors.red;
                                break;
                              case BudgetWarningLevel.warning:
                                progressColor = Colors.orange;
                                break;
                              case BudgetWarningLevel.normal:
                                progressColor = Colors.green;
                                break;
                            }
                            return Column(
                              children: [
                                ListTile(
                                  title: Text(budget.tag),
                                  subtitle: Text(
                                    '${budget.usedFormatted} / ${budget.limitFormatted}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (budget.warningLevel !=
                                          BudgetWarningLevel.normal)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 4,
                                          ),
                                          child: Icon(
                                            budget.warningLevel ==
                                                    BudgetWarningLevel.exceeded
                                                ? Icons.error
                                                : Icons.warning_amber,
                                            color: progressColor,
                                            size: 18,
                                          ),
                                        ),
                                      Text(
                                        '${(budget.percentageUsed * 100).toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          color: progressColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                LinearProgressIndicator(
                                  value: budget.percentageUsedClamped,
                                  color: progressColor,
                                ),
                                const SizedBox(height: 12),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                  loading: () => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (_, _) => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Error loading budgets'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddExpense(context),
        tooltip: 'Add Money',
        icon: const Icon(Icons.add),
        label: const Text('Add Money'),
      ),
    );
  }

  void _navigateToAddExpense(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddExpenseScreen()));
  }

  void _navigateToBudgets(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const BudgetsScreen()));
  }

  void _navigateToAllTransactions(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TransactionsListScreen()));
  }

  // ignore: unused_element
  void _showQuickLookup(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.menu_book),
            SizedBox(width: 12),
            Text('Quick Lookup'),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Enter a word',
            hintText: 'e.g., serendipity',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (word) {
            if (word.trim().isNotEmpty) {
              Navigator.of(context).pop();
              DictionaryPopup.showAdaptive(context, word.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              final word = controller.text.trim();
              if (word.isNotEmpty) {
                Navigator.of(context).pop();
                DictionaryPopup.showAdaptive(context, word);
              }
            },
            icon: const Icon(Icons.search),
            label: const Text('Look Up'),
          ),
        ],
      ),
    );
  }
}

/// Primary action button for Coins screen
class _PrimaryActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PrimaryActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: colorScheme.onPrimaryContainer,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
