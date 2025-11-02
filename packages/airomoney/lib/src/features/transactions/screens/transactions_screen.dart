import 'package:flutter/material.dart';
import '../../../shared/widgets/transaction_tile.dart';
import '../../../core/models/transaction.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Income', 'Expense', 'Transfer'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mock data for demonstration
    final mockTransactions = _generateMockTransactions();
    final filteredTransactions = _filterTransactions(mockTransactions);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (context) => _filters
                .map((filter) => PopupMenuItem(
                      value: filter,
                      child: Text(filter),
                    ))
                .toList(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Recent'),
            Tab(text: 'Summary'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRecentTab(filteredTransactions),
          _buildSummaryTab(mockTransactions),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Navigate to add transaction
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildRecentTab(List<Transaction> transactions) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first transaction to get started',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Group transactions by date
    final groupedTransactions = <String, List<Transaction>>{};
    for (final transaction in transactions) {
      final dateKey = _getDateKey(transaction.date);
      groupedTransactions.putIfAbsent(dateKey, () => []).add(transaction);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedTransactions.length,
      itemBuilder: (context, index) {
        final dateKey = groupedTransactions.keys.elementAt(index);
        final dayTransactions = groupedTransactions[dateKey]!;
        final totalAmount = dayTransactions.fold<double>(
          0,
          (sum, t) => sum + (t.type == TransactionType.income ? t.amount : -t.amount),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateKey,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${totalAmount >= 0 ? '+' : ''}\$${totalAmount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: totalAmount >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ...dayTransactions.map((transaction) => TransactionTile(
                  transaction: transaction,
                  showDate: false,
                  onTap: () {
                    // TODO: Navigate to transaction details
                  },
                )),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildSummaryTab(List<Transaction> transactions) {
    final incomeTransactions = transactions.where((t) => t.type == TransactionType.income).toList();
    final expenseTransactions = transactions.where((t) => t.type == TransactionType.expense).toList();
    final transferTransactions = transactions.where((t) => t.type == TransactionType.transfer).toList();

    final totalIncome = incomeTransactions.fold<double>(0, (sum, t) => sum + t.amount);
    final totalExpense = expenseTransactions.fold<double>(0, (sum, t) => sum + t.amount);
    final totalTransfer = transferTransactions.fold<double>(0, (sum, t) => sum + t.amount);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Overview cards
        Row(
          children: [
            Expanded(
              child: Card(
                color: Colors.green.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.arrow_downward, color: Colors.green, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        'Income',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '\$${totalIncome.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Card(
                color: Colors.red.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.arrow_upward, color: Colors.red, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        'Expense',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '\$${totalExpense.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Net income card
        Card(
          color: (totalIncome - totalExpense) >= 0 
              ? Colors.green.withOpacity(0.1) 
              : Colors.red.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Net Income',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '\$${(totalIncome - totalExpense).toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: (totalIncome - totalExpense) >= 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Category breakdown
        Text(
          'By Category',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        // Group by category
        ..._buildCategorySummary(transactions),
      ],
    );
  }

  List<Widget> _buildCategorySummary(List<Transaction> transactions) {
    final categoryTotals = <TransactionCategory, double>{};
    final categoryCounts = <TransactionCategory, int>{};

    for (final transaction in transactions) {
      categoryTotals[transaction.category] = 
          (categoryTotals[transaction.category] ?? 0) + transaction.amount;
      categoryCounts[transaction.category] = 
          (categoryCounts[transaction.category] ?? 0) + 1;
    }

    return categoryTotals.entries.map((entry) {
      final category = entry.key;
      final amount = entry.value;
      final count = categoryCounts[category]!;
      final isIncome = _isIncomeCategory(category);

      return TransactionSummaryTile(
        title: _getCategoryDisplayName(category),
        amount: amount,
        count: count,
        color: isIncome ? Colors.green : Colors.red,
        icon: _getCategoryIcon(category),
        onTap: () {
          // TODO: Navigate to category details
        },
      );
    }).toList();
  }

  List<Transaction> _generateMockTransactions() {
    final now = DateTime.now();
    return [
      Transaction(
        id: '1',
        title: 'Salary',
        amount: 3000.00,
        type: TransactionType.income,
        category: TransactionCategory.salary,
        date: now.subtract(const Duration(days: 1)),
      ),
      Transaction(
        id: '2',
        title: 'Coffee Shop',
        amount: 4.50,
        type: TransactionType.expense,
        category: TransactionCategory.food,
        date: now.subtract(const Duration(hours: 2)),
      ),
      Transaction(
        id: '3',
        title: 'Uber Ride',
        amount: 12.30,
        type: TransactionType.expense,
        category: TransactionCategory.transport,
        date: now.subtract(const Duration(hours: 5)),
      ),
      Transaction(
        id: '4',
        title: 'Freelance Project',
        amount: 500.00,
        type: TransactionType.income,
        category: TransactionCategory.freelance,
        date: now.subtract(const Duration(days: 2)),
      ),
      Transaction(
        id: '5',
        title: 'Grocery Shopping',
        amount: 85.20,
        type: TransactionType.expense,
        category: TransactionCategory.food,
        date: now.subtract(const Duration(days: 3)),
      ),
    ];
  }

  List<Transaction> _filterTransactions(List<Transaction> transactions) {
    if (_selectedFilter == 'All') return transactions;
    
    final filterType = TransactionType.values.firstWhere(
      (type) => type.name.toLowerCase() == _selectedFilter.toLowerCase(),
      orElse: () => TransactionType.income,
    );
    
    return transactions.where((t) => t.type == filterType).toList();
  }

  String _getDateKey(DateTime date) {
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

  bool _isIncomeCategory(TransactionCategory category) {
    return [
      TransactionCategory.salary,
      TransactionCategory.freelance,
      TransactionCategory.investment,
      TransactionCategory.gift,
      TransactionCategory.other_income,
    ].contains(category);
  }

  String _getCategoryDisplayName(TransactionCategory category) {
    // Implementation similar to transaction_tile.dart
    switch (category) {
      case TransactionCategory.salary:
        return 'Salary';
      case TransactionCategory.freelance:
        return 'Freelance';
      case TransactionCategory.food:
        return 'Food & Dining';
      case TransactionCategory.transport:
        return 'Transportation';
      // Add other cases...
      default:
        return category.name;
    }
  }

  IconData _getCategoryIcon(TransactionCategory category) {
    // Implementation similar to transaction_tile.dart
    switch (category) {
      case TransactionCategory.salary:
        return Icons.work_outline;
      case TransactionCategory.food:
        return Icons.restaurant_outlined;
      case TransactionCategory.transport:
        return Icons.directions_car_outlined;
      // Add other cases...
      default:
        return Icons.category_outlined;
    }
  }
}
