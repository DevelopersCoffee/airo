import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/dictionary/dictionary.dart';
import '../../../../core/routing/route_names.dart';
import '../../application/providers/money_provider.dart';
import '../../domain/models/money_models.dart';
import '../widgets/transaction_upload_dialog.dart';
import '../../../quotes/presentation/widgets/daily_quote_card.dart';
import 'add_expense_screen.dart';
import 'budgets_screen.dart';
import 'transactions_list_screen.dart';

/// Money overview screen
class MoneyOverviewScreen extends ConsumerWidget {
  const MoneyOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalBalance = ref.watch(totalBalanceProvider);
    final accounts = ref.watch(accountsProvider);
    // Use stream provider for reactive transactions
    final transactionsStream = ref.watch(transactionsStreamProvider);
    final budgetsStream = ref.watch(budgetsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coins'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book),
            onPressed: () => _showQuickLookup(context),
            tooltip: 'Quick Dictionary Lookup',
          ),
        ],
      ),
      body: DictionarySelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Daily quote card
              const DailyQuoteCard(
                padding: EdgeInsets.only(bottom: 16),
                elevation: 1,
              ),

              // Quick Actions
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _QuickActionCard(
                      icon: Icons.call_split,
                      label: 'Split Bill',
                      color: Colors.orange,
                      onTap: () => context.push(RouteNames.billSplit),
                    ),
                    _QuickActionCard(
                      icon: Icons.receipt_long,
                      label: 'Scan Receipt',
                      color: Colors.blue,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Coming soon!')),
                        );
                      },
                    ),
                    _QuickActionCard(
                      icon: Icons.send,
                      label: 'Send Money',
                      color: Colors.green,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Coming soon!')),
                        );
                      },
                    ),
                    _QuickActionCard(
                      icon: Icons.request_page,
                      label: 'Request',
                      color: Colors.purple,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Coming soon!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Total balance card
              totalBalance.when(
                data: (balance) {
                  final dollars = balance ~/ 100;
                  final cents = (balance % 100).abs();
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Balance',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '\$$dollars.${cents.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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
                error: (_, __) => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Error loading balance'),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Accounts section
              Text('Accounts', style: Theme.of(context).textTheme.titleLarge),
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
                error: (_, __) => const Card(
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
                            Icon(Icons.receipt_long, size: 48, color: Colors.grey[400]),
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
                          ...txnList.take(5)
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
                              onPressed: () => _navigateToAllTransactions(context),
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
                error: (_, __) => const Card(
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
                  Text('Budgets', style: Theme.of(context).textTheme.titleLarge),
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
                            Icon(Icons.trending_down, size: 48, color: Colors.grey[400]),
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
                        children: budgetList
                            .map(
                              (budget) {
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
                                          if (budget.warningLevel != BudgetWarningLevel.normal)
                                            Padding(
                                              padding: const EdgeInsets.only(right: 4),
                                              child: Icon(
                                                budget.warningLevel == BudgetWarningLevel.exceeded
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
                              },
                            )
                            .toList(),
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
                error: (_, __) => const Card(
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddExpense(context),
        tooltip: 'Add Expense',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _navigateToAddExpense(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
    );
  }

  void _navigateToBudgets(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BudgetsScreen()),
    );
  }

  void _navigateToAllTransactions(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TransactionsListScreen()),
    );
  }

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
              DictionaryPopup.showBottomSheet(context, word.trim());
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
                DictionaryPopup.showBottomSheet(context, word);
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

/// Quick action card widget for money screen
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 90,
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
