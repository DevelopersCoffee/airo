import 'package:flutter/material.dart';
import '../../../shared/widgets/money_card.dart';
import '../../../core/models/wallet.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock data for demonstration
    final mockWallets = [
      Wallet(
        id: '1',
        name: 'Main Wallet',
        description: 'Primary spending account',
        balance: 2500.50,
        type: WalletType.cash,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now(),
      ),
      Wallet(
        id: '2',
        name: 'Savings Account',
        description: 'Emergency fund',
        balance: 15000.00,
        type: WalletType.bank,
        bankName: 'Chase Bank',
        accountNumber: '1234567890',
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
        updatedAt: DateTime.now(),
      ),
      Wallet(
        id: '3',
        name: 'Credit Card',
        description: 'Chase Freedom',
        balance: -850.25,
        type: WalletType.credit,
        bankName: 'Chase Bank',
        accountNumber: '9876543210',
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
        updatedAt: DateTime.now(),
      ),
      Wallet(
        id: '4',
        name: 'Investment Portfolio',
        description: 'Stock investments',
        balance: 25000.75,
        type: WalletType.investment,
        createdAt: DateTime.now().subtract(const Duration(days: 120)),
        updatedAt: DateTime.now(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Navigate to add wallet
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total net worth
            MoneyCard(
              title: 'Net Worth',
              amount: mockWallets.fold(0.0, (sum, wallet) => sum + wallet.balance),
              subtitle: 'Total across all accounts',
              icon: Icons.account_balance_wallet,
              color: Colors.blue,
              showTrend: true,
              trendValue: 5.2,
              isPositiveTrend: true,
            ),
            const SizedBox(height: 24),

            // Wallets section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Wallets',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    // TODO: Navigate to add wallet
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Wallet'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Wallets list
            Expanded(
              child: ListView.builder(
                itemCount: mockWallets.length,
                itemBuilder: (context, index) {
                  final wallet = mockWallets[index];
                  return _buildWalletCard(context, wallet);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCard(BuildContext context, Wallet wallet) {
    final theme = Theme.of(context);
    final color = _getWalletColor(wallet.type);
    final icon = _getWalletIcon(wallet.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        title: Text(
          wallet.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (wallet.description != null)
              Text(
                wallet.description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  _getWalletTypeDisplayName(wallet.type),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (wallet.bankName != null) ...[
                  const Text(' • '),
                  Text(
                    wallet.bankName!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            if (wallet.accountNumber != null)
              Text(
                wallet.maskedAccountNumber,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              wallet.formattedBalance,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: wallet.balance >= 0 ? Colors.green : Colors.red,
              ),
            ),
            Text(
              wallet.currency,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        onTap: () {
          // TODO: Navigate to wallet details
        },
      ),
    );
  }

  Color _getWalletColor(WalletType type) {
    switch (type) {
      case WalletType.cash:
        return Colors.green;
      case WalletType.bank:
        return Colors.blue;
      case WalletType.credit:
        return Colors.orange;
      case WalletType.investment:
        return Colors.purple;
      case WalletType.crypto:
        return Colors.amber;
    }
  }

  IconData _getWalletIcon(WalletType type) {
    switch (type) {
      case WalletType.cash:
        return Icons.account_balance_wallet_outlined;
      case WalletType.bank:
        return Icons.account_balance_outlined;
      case WalletType.credit:
        return Icons.credit_card_outlined;
      case WalletType.investment:
        return Icons.trending_up_outlined;
      case WalletType.crypto:
        return Icons.currency_bitcoin_outlined;
    }
  }

  String _getWalletTypeDisplayName(WalletType type) {
    switch (type) {
      case WalletType.cash:
        return 'Cash';
      case WalletType.bank:
        return 'Bank Account';
      case WalletType.credit:
        return 'Credit Card';
      case WalletType.investment:
        return 'Investment';
      case WalletType.crypto:
        return 'Cryptocurrency';
    }
  }
}
