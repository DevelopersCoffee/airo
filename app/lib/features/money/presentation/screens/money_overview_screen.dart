import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/dictionary/dictionary.dart';
import '../../application/providers/money_provider.dart';
import '../../domain/models/money_models.dart';
// ignore: unused_import
import '../widgets/transaction_upload_dialog.dart';
import 'add_expense_screen.dart';
import 'budgets_screen.dart';
import 'transactions_list_screen.dart';

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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DictionarySelectionArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _CoinsHeroSection(
                totalBalance: totalBalance,
                onAddExpense: () => _navigateToAddExpense(context),
                onTransactions: () => _navigateToAllTransactions(context),
              ),
              _CoinsDemoSection(
                transactionsStream: transactionsStream,
                onAddExpense: () => _navigateToAddExpense(context),
              ),
              _CoinsFeatureGrid(
                accounts: accounts,
                transactionsStream: transactionsStream,
                budgetsStream: budgetsStream,
                onAddExpense: () => _navigateToAddExpense(context),
                onBudgets: () => _navigateToBudgets(context),
                onTransactions: () => _navigateToAllTransactions(context),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddExpense(context),
        tooltip: 'Add Expense',
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
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

class _CoinsHeroSection extends StatelessWidget {
  const _CoinsHeroSection({
    required this.totalBalance,
    required this.onAddExpense,
    required this.onTransactions,
  });

  final AsyncValue<int> totalBalance;
  final VoidCallback onAddExpense;
  final VoidCallback onTransactions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return _HermesSection(
      minHeight: MediaQuery.sizeOf(context).height * 0.5,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'OPEN FINANCE • AIRO COINS',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary.withValues(alpha: 0.72),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  'THE MONEY THAT\nWORKS WITH YOU.',
                  style: theme.textTheme.displayLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                totalBalance.when(
                  data: (balance) {
                    final dollars = balance ~/ 100;
                    final cents = (balance % 100).abs();
                    return Text(
                      'Available balance: \$$dollars.${cents.toString().padLeft(2, '0')}',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.primary.withValues(alpha: 0.64),
                      ),
                      textAlign: TextAlign.center,
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (_, _) => Text(
                    'Balance temporarily unavailable',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                _CommandRow(
                  index: '1.',
                  title: 'Create',
                  command: 'add expense --split equal --settle later',
                  onCopy: onAddExpense,
                ),
                const SizedBox(height: 18),
                _CommandRow(
                  index: '2.',
                  title: 'Review',
                  command: 'open ledger --recent --budget warnings',
                  onCopy: onTransactions,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoinsDemoSection extends StatelessWidget {
  const _CoinsDemoSection({
    required this.transactionsStream,
    required this.onAddExpense,
  });

  final AsyncValue<List<Transaction>> transactionsStream;
  final VoidCallback onAddExpense;

  @override
  Widget build(BuildContext context) {
    final lines = transactionsStream.maybeWhen(
      data: (transactions) {
        if (transactions.isEmpty) {
          return const [
            '> Create a dinner expense and split it with the group',
            '',
            'expense create "Team dinner"        0.2s',
            'split equal --participants 4       0.1s',
            'budget check dining                0.1s',
            'settlement preview                 0.3s',
            '',
            'No transactions yet. Add the first expense.',
          ];
        }
        return [
          '> Review recent Airo Coins activity',
          '',
          for (final txn in transactions.take(5))
            '${txn.description.padRight(28).substring(0, 28)} ${txn.amountFormatted}',
          '',
          'Found ${transactions.length} ledger entries.',
        ];
      },
      orElse: () => const ['> Loading the Airo ledger...'],
    );

    return _HermesTwoColumnSection(
      left: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle('SEE IT IN ACTION'),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: _TerminalPanel(lines: lines, onAddExpense: onAddExpense),
            ),
          ],
        ),
      ),
      right: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/hermes/images/filler-bg0.jpg',
            fit: BoxFit.cover,
            color: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.45),
            colorBlendMode: BlendMode.modulate,
          ),
          Positioned(
            right: 20,
            bottom: 18,
            child: Text(
              'AIRO COINS',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinsFeatureGrid extends StatelessWidget {
  const _CoinsFeatureGrid({
    required this.accounts,
    required this.transactionsStream,
    required this.budgetsStream,
    required this.onAddExpense,
    required this.onBudgets,
    required this.onTransactions,
  });

  final AsyncValue<List<MoneyAccount>> accounts;
  final AsyncValue<List<Transaction>> transactionsStream;
  final AsyncValue<List<Budget>> budgetsStream;
  final VoidCallback onAddExpense;
  final VoidCallback onBudgets;
  final VoidCallback onTransactions;

  @override
  Widget build(BuildContext context) {
    return _HermesSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: _SectionTitle('FEATURES'),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 920
                  ? 3
                  : constraints.maxWidth >= 620
                  ? 2
                  : 1;
              return GridView.count(
                crossAxisCount: columns,
                childAspectRatio: columns == 1 ? 3.2 : 2.3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _FeatureCell(
                    title: 'Accounts',
                    body: accounts.when(
                      data: (items) => items.isEmpty
                          ? 'Add checking, savings, or credit accounts to make the ledger real.'
                          : items
                                .map((a) => '${a.name}: ${a.balanceFormatted}')
                                .join('\n'),
                      loading: () => 'Loading account balances...',
                      error: (_, _) => 'Account balances unavailable.',
                    ),
                  ),
                  _FeatureCell(
                    title: 'Expense Workflow',
                    body:
                        'Create expenses, tag categories, attach receipts, and route splits from one action.',
                    onTap: onAddExpense,
                  ),
                  _FeatureCell(
                    title: 'Recent Ledger',
                    body: transactionsStream.when(
                      data: (items) => items.isEmpty
                          ? 'No transactions yet. Add the first expense to start tracking.'
                          : items
                                .take(3)
                                .map(
                                  (t) =>
                                      '${t.description}: ${t.amountFormatted}',
                                )
                                .join('\n'),
                      loading: () => 'Loading recent transactions...',
                      error: (_, _) => 'Recent transactions unavailable.',
                    ),
                    onTap: onTransactions,
                  ),
                  _FeatureCell(
                    title: 'Budgets',
                    body: budgetsStream.when(
                      data: (items) => items.isEmpty
                          ? 'Create budgets to track dining, travel, and recurring spending.'
                          : items
                                .take(3)
                                .map(
                                  (b) =>
                                      '${b.tag}: ${b.usedFormatted} / ${b.limitFormatted}',
                                )
                                .join('\n'),
                      loading: () => 'Loading budget controls...',
                      error: (_, _) => 'Budget controls unavailable.',
                    ),
                    onTap: onBudgets,
                  ),
                  const _FeatureCell(
                    title: 'Splitwise Defaults',
                    body:
                        'Equal split first, itemized split when needed, settlement preview before saving.',
                  ),
                  const _FeatureCell(
                    title: 'Investment Ready',
                    body:
                        'The finance shell is ready for net worth, positions, and credit-card intelligence.',
                  ),
                ],
              );
            },
          ),
          _HermesFooterStrip(onAddExpense: onAddExpense, onBudgets: onBudgets),
        ],
      ),
    );
  }
}

class _CommandRow extends StatelessWidget {
  const _CommandRow({
    required this.index,
    required this.title,
    required this.command,
    required this.onCopy,
  });

  final String index;
  final String title;
  final String command;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$index  $title'.toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.primary.withValues(alpha: 0.56),
              ),
            ),
            const Spacer(),
            TextButton(onPressed: onCopy, child: const Text('COPY')),
          ],
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.32),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Text(
            command,
            style: const TextStyle(
              fontFamily: 'Courier',
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _HermesSection extends StatelessWidget {
  const _HermesSection({required this.child, this.minHeight});

  final Widget child;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: minHeight ?? 0),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: colorScheme.outlineVariant),
          right: BorderSide(color: colorScheme.outlineVariant),
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: child,
    );
  }
}

class _HermesTwoColumnSection extends StatelessWidget {
  const _HermesTwoColumnSection({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _HermesSection(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 760) {
            return Column(
              children: [
                left,
                SizedBox(height: 280, child: right),
              ],
            );
          }
          return SizedBox(
            height: 420,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: left),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: colorScheme.outlineVariant),
                      ),
                    ),
                    child: right,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TerminalPanel extends StatelessWidget {
  const _TerminalPanel({required this.lines, required this.onAddExpense});

  final List<String> lines;
  final VoidCallback onAddExpense;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onAddExpense,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.36),
          border: Border.all(color: colorScheme.primary, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  for (final alpha in const [1.0, 0.6, 0.3]) ...[
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: alpha),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                  ],
                  const SizedBox(width: 6),
                  Text(
                    'AIRO',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary.withValues(alpha: 0.42),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Text(
                  lines.join('\n'),
                  style: TextStyle(
                    fontFamily: 'Courier',
                    color: colorScheme.primary.withValues(alpha: 0.84),
                    fontSize: 14,
                    height: 1.7,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.headlineSmall);
  }
}

class _FeatureCell extends StatelessWidget {
  const _FeatureCell({required this.title, required this.body, this.onTap});

  final String title;
  final String body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: colorScheme.outlineVariant),
            right: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                body,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.primary.withValues(alpha: 0.68),
                ),
                overflow: TextOverflow.fade,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HermesFooterStrip extends StatelessWidget {
  const _HermesFooterStrip({
    required this.onAddExpense,
    required this.onBudgets,
  });

  final VoidCallback onAddExpense;
  final VoidCallback onBudgets;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: SizedBox(
        height: 66,
        child: Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: onAddExpense,
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Text('ADD EXPENSE'),
                  ),
                ),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: onBudgets,
                child: const Text('MANAGE BUDGETS'),
              ),
            ),
            const Expanded(child: Text('AIRO COINS v0.13.0')),
          ],
        ),
      ),
    );
  }
}
