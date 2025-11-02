import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/money_provider.dart';
import '../widgets/transaction_upload_dialog.dart';

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
      appBar: AppBar(title: const Text('Coins'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
}
