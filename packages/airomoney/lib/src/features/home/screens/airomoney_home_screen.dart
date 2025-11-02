import 'package:flutter/material.dart';
import '../../../shared/widgets/money_card.dart';
import '../../../core/models/wallet.dart';
import '../../../core/models/transaction.dart';

class AiroMoneyHomeScreen extends StatelessWidget {
  const AiroMoneyHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock data for demonstration
    final mockWallets = [
      Wallet(
        id: '1',
        name: 'Main Wallet',
        balance: 2500.50,
        type: WalletType.cash,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Wallet(
        id: '2',
        name: 'Savings Account',
        balance: 15000.00,
        type: WalletType.bank,
        bankName: 'Chase Bank',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    final mockTransactions = [
      Transaction(
        id: '1',
        title: 'Coffee Shop',
        amount: 4.50,
        type: TransactionType.expense,
        category: TransactionCategory.food,
        date: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Transaction(
        id: '2',
        title: 'Salary',
        amount: 3000.00,
        type: TransactionType.income,
        category: TransactionCategory.salary,
        date: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('AiroMoney'),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome section
            Text(
              'Welcome back!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage your finances with ease',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // Total balance card
            MoneyCard(
              title: 'Total Balance',
              amount: mockWallets.fold(0.0, (sum, wallet) => sum + wallet.balance),
              subtitle: 'Across all accounts',
              icon: Icons.account_balance_wallet,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),

            // Quick actions
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    context,
                    'Add Income',
                    Icons.add_circle_outline,
                    Colors.green,
                    () {
                      // TODO: Navigate to add income
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    context,
                    'Add Expense',
                    Icons.remove_circle_outline,
                    Colors.red,
                    () {
                      // TODO: Navigate to add expense
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    context,
                    'Transfer',
                    Icons.swap_horiz,
                    Colors.orange,
                    () {
                      // TODO: Navigate to transfer
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    context,
                    'Analytics',
                    Icons.analytics_outlined,
                    Colors.purple,
                    () {
                      // TODO: Navigate to analytics
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Recent transactions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Transactions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // TODO: Navigate to all transactions
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...mockTransactions.map((transaction) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: transaction.type == TransactionType.income
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  child: Icon(
                    transaction.type == TransactionType.income
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    color: transaction.type == TransactionType.income
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
                title: Text(transaction.title),
                subtitle: Text(
                  '${transaction.category.name} • ${_formatDate(transaction.date)}',
                ),
                trailing: Text(
                  '${transaction.type == TransactionType.income ? '+' : '-'}\$${transaction.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: transaction.type == TransactionType.income
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Navigate to add transaction
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

// Keep the old class for backward compatibility
class AiroMoneyHello extends AiroMoneyHomeScreen {
  const AiroMoneyHello({super.key});
}
