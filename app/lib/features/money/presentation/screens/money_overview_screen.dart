import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/dictionary/dictionary.dart';
import '../../../../core/routing/route_names.dart';
import '../../application/providers/money_provider.dart';
import '../widgets/transaction_upload_dialog.dart';
import '../../../quotes/presentation/widgets/daily_quote_card.dart';

/// Money overview screen
class MoneyOverviewScreen extends ConsumerWidget {
  const MoneyOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalBalance = ref.watch(totalBalanceProvider);
    final accounts = ref.watch(accountsProvider);
    final transactions = ref.watch(recentTransactionsProvider);
    final budgets = ref.watch(budgetsProvider);

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
              transactions.when(
                data: (txnList) {
                  if (txnList.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const ListTile(
                              title: Text('No transactions yet'),
                              subtitle: Text(
                                'Your transactions will appear here',
                              ),
                              leading: Icon(Icons.receipt),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                // TODO: Navigate to add transaction screen
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Add Transaction'),
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
                        children: txnList
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
                    child: Text('Error loading transactions'),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Budgets section
              Text('Budgets', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              budgets.when(
                data: (budgetList) {
                  if (budgetList.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const ListTile(
                              title: Text('No budgets yet'),
                              subtitle: Text(
                                'Create budgets to track your spending',
                              ),
                              leading: Icon(Icons.trending_down),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                // TODO: Navigate to add budget screen
                              },
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
                              (budget) => Column(
                                children: [
                                  ListTile(
                                    title: Text(budget.tag),
                                    subtitle: Text(
                                      '${budget.usedFormatted} / ${budget.limitFormatted}',
                                    ),
                                    trailing: Text(
                                      '${(budget.percentageUsed * 100).toStringAsFixed(0)}%',
                                    ),
                                  ),
                                  LinearProgressIndicator(
                                    value: budget.percentageUsed,
                                    color: budget.isExceeded
                                        ? Colors.red
                                        : Colors.green,
                                  ),
                                  const SizedBox(height: 12),
                                ],
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
                    child: Text('Error loading budgets'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => TransactionUploadDialog(
              onFileSelected: (fileName, filePath, fileType) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Uploaded: $fileName ($fileType)')),
                );
              },
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
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
