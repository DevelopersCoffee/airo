import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/money_provider.dart';
import '../../domain/models/money_models.dart';

/// Screen for viewing all transactions with pagination and filters
class TransactionsListScreen extends ConsumerStatefulWidget {
  const TransactionsListScreen({super.key});

  @override
  ConsumerState<TransactionsListScreen> createState() =>
      _TransactionsListScreenState();
}

class _TransactionsListScreenState
    extends ConsumerState<TransactionsListScreen> {
  final _scrollController = ScrollController();
  int _currentPage = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  final List<Transaction> _transactions = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialPage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreIfNeeded();
    }
  }

  Future<void> _loadInitialPage() async {
    setState(() {
      _currentPage = 0;
      _transactions.clear();
      _hasMore = true;
    });
    await _loadPage(0);
  }

  Future<void> _loadMoreIfNeeded() async {
    if (!_hasMore || _isLoadingMore) return;
    await _loadPage(_currentPage + 1);
  }

  Future<void> _loadPage(int page) async {
    setState(() => _isLoadingMore = true);
    try {
      final newTxns = await ref.read(
        paginatedTransactionsProvider(page).future,
      );
      if (mounted) {
        setState(() {
          _currentPage = page;
          _transactions.addAll(newTxns);
          _hasMore = newTxns.length >= 20;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading: $e')));
      }
    }
  }

  void _showFilterSheet() {
    final filter = ref.read(transactionFilterProvider);
    final categories = ref.read(availableCategoriesProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _FilterSheet(
        currentFilter: filter,
        categories: categories,
        onApply: (newFilter) {
          ref.read(transactionFilterProvider.notifier).state = newFilter;
          Navigator.pop(ctx);
          _loadInitialPage();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(transactionFilterProvider);
    final hasFilter = filter.category != null || filter.startDate != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Transactions'),
        actions: [
          Badge(
            isLabelVisible: hasFilter,
            child: IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showFilterSheet,
            ),
          ),
        ],
      ),
      body: _transactions.isEmpty && !_isLoadingMore
          ? _buildEmpty()
          : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('No transactions found'),
          TextButton.icon(
            onPressed: _showFilterSheet,
            icon: const Icon(Icons.filter_list),
            label: const Text('Adjust filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _loadInitialPage,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _transactions.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= _transactions.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return _TxnTile(txn: _transactions[i]);
        },
      ),
    );
  }
}

class _TxnTile extends StatelessWidget {
  final Transaction txn;
  const _TxnTile({required this.txn});

  @override
  Widget build(BuildContext context) {
    final isExp = txn.isExpense;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (isExp ? Colors.red : Colors.green).withOpacity(0.1),
          child: Icon(
            isExp ? Icons.arrow_upward : Icons.arrow_downward,
            color: isExp ? Colors.red : Colors.green,
          ),
        ),
        title: Text(
          txn.description,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text('${txn.category} • ${_fmtDate(txn.timestamp)}'),
        trailing: Text(
          txn.amountFormatted,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isExp ? Colors.red : Colors.green,
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final diff = DateTime.now().difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return '${d.day}/${d.month}/${d.year}';
  }
}

class _FilterSheet extends StatefulWidget {
  final TransactionFilter currentFilter;
  final List<String> categories;
  final void Function(TransactionFilter) onApply;
  const _FilterSheet({
    required this.currentFilter,
    required this.categories,
    required this.onApply,
  });
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _cat;
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    _cat = widget.currentFilter.category;
    _start = widget.currentFilter.startDate;
    _end = widget.currentFilter.endDate;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (ctx, sc) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Filters', style: Theme.of(ctx).textTheme.titleLarge),
                TextButton(
                  onPressed: () => setState(() {
                    _cat = null;
                    _start = null;
                    _end = null;
                  }),
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Category', style: Theme.of(ctx).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.categories
                  .map(
                    (c) => FilterChip(
                      label: Text(c),
                      selected: _cat == c,
                      onSelected: (sel) =>
                          setState(() => _cat = sel ? c : null),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Text('Date Range', style: Theme.of(ctx).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _dateBtn(
                    'Start',
                    _start,
                    (d) => setState(() => _start = d),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _dateBtn('End', _end, (d) => setState(() => _end = d)),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => widget.onApply(
                  TransactionFilter(
                    category: _cat,
                    startDate: _start,
                    endDate: _end,
                  ),
                ),
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateBtn(String lbl, DateTime? dt, void Function(DateTime) onPick) {
    return OutlinedButton.icon(
      onPressed: () async {
        final p = await showDatePicker(
          context: context,
          initialDate: dt ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (p != null) onPick(p);
      },
      icon: const Icon(Icons.calendar_today, size: 16),
      label: Text(dt != null ? '${dt.day}/${dt.month}' : lbl),
    );
  }
}
