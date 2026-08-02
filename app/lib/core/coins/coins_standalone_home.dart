import 'package:feature_coin/feature_coin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/coins/application/providers/expense_providers.dart';
import '../../features/coins/presentation/widgets/expense_card.dart';

/// Home screen for the standalone Airo Coins shell.
///
/// A lean, read-only money summary that mirrors the super-app Coins tab's
/// content-first feel — recent transactions plus an entry into the secure
/// vault — without dropping onto the biometric gate. It deliberately reuses
/// only the legacy read path (`recentExpensesProvider`) and display card;
/// the heavy add/split/group/budget flows (and their OCR, share, and uuid
/// dependencies) stay out of the standalone until the money dashboard is
/// migrated package-first into `feature_coin` (ADR-0010 interim exception;
/// Airo Coin phased epic #938–#942).
class CoinsStandaloneHome extends ConsumerWidget {
  const CoinsStandaloneHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentExpensesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Airo Coins')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(recentExpensesProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _VaultEntryCard(
              onOpen: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const VaultGateScreen(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Recent transactions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            recentAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('Could not load transactions: $error'),
              ),
              data: (transactions) => transactions.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No transactions yet. Your locally stored spending '
                        'will appear here.',
                      ),
                    )
                  : Column(
                      children: [
                        for (final transaction in transactions)
                          ExpenseCard(transaction: transaction),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VaultEntryCard extends StatelessWidget {
  const _VaultEntryCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerHighest,
      child: ListTile(
        leading: Icon(Icons.lock_outline, color: scheme.primary),
        title: const Text('Secure Vault'),
        subtitle: const Text(
          'Bank accounts, cards, and documents — unlocked with biometrics '
          'when you open a record.',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onOpen,
      ),
    );
  }
}
