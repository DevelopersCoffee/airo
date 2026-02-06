import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/money_provider.dart';
import '../../domain/models/money_models.dart';

/// Screen for managing budgets (CRUD)
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: budgetsAsync.when(
        data: (budgets) {
          if (budgets.isEmpty) {
            return _EmptyBudgetsPlaceholder(
              onCreateBudget: () => _showCreateBudgetDialog(context, ref),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: budgets.length,
            itemBuilder: (context, index) => _BudgetCard(
              budget: budgets[index],
              onEdit: () => _showEditBudgetDialog(context, ref, budgets[index]),
              onDelete: () => _confirmDelete(context, ref, budgets[index]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateBudgetDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateBudgetDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _BudgetFormDialog(
        onSave: (tag, limitCents) async {
          final controller = ref.read(moneyControllerProvider);
          await controller.createBudget(tag: tag, limitCents: limitCents);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _showEditBudgetDialog(
    BuildContext context,
    WidgetRef ref,
    Budget budget,
  ) {
    showDialog(
      context: context,
      builder: (context) => _BudgetFormDialog(
        budget: budget,
        onSave: (tag, limitCents) async {
          final controller = ref.read(moneyControllerProvider);
          final updated = Budget(
            id: budget.id,
            tag: tag,
            limitCents: limitCents,
            usedCents: budget.usedCents,
            createdAt: budget.createdAt,
            updatedAt: DateTime.now(),
          );
          await controller.updateBudget(updated);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Budget budget) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Budget'),
        content: Text('Delete budget for "${budget.tag}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final controller = ref.read(moneyControllerProvider);
              await controller.deleteBudget(budget.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _EmptyBudgetsPlaceholder extends StatelessWidget {
  final VoidCallback onCreateBudget;

  const _EmptyBudgetsPlaceholder({required this.onCreateBudget});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.trending_down, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No budgets yet', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Create budgets to track your spending',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onCreateBudget,
            icon: const Icon(Icons.add),
            label: const Text('Create Budget'),
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final Budget budget;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BudgetCard({
    required this.budget,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final progress = budget.percentageUsedClamped;
    final warningLevel = budget.warningLevel;
    final percentText = '${(budget.percentageUsed * 100).toStringAsFixed(0)}%';

    // Color based on warning level
    Color progressColor;
    switch (warningLevel) {
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

    return Semantics(
      label:
          '${budget.tag} budget, ${budget.usedFormatted} of ${budget.limitFormatted} used, $percentText${warningLevel == BudgetWarningLevel.exceeded
              ? ', exceeded'
              : warningLevel == BudgetWarningLevel.warning
              ? ', approaching limit'
              : ''}',
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    budget.tag,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Budget options',
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${budget.usedFormatted} / ${budget.limitFormatted}'),
                  Text(
                    percentText,
                    style: TextStyle(
                      color: progressColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Semantics(
                label: 'Budget progress $percentText',
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  color: progressColor,
                  backgroundColor: Colors.grey[300],
                ),
              ),
              // Warning message at 80% threshold
              if (warningLevel == BudgetWarningLevel.warning)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber,
                        color: Colors.orange,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Approaching budget limit - ₹${(budget.remainingCents / 100).toStringAsFixed(2)} remaining',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Exceeded message at 100%
              if (warningLevel == BudgetWarningLevel.exceeded)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Budget exceeded by ₹${((budget.usedCents - budget.limitCents) / 100).toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetFormDialog extends StatefulWidget {
  final Budget? budget;
  final Future<void> Function(String tag, int limitCents) onSave;

  const _BudgetFormDialog({this.budget, required this.onSave});

  @override
  State<_BudgetFormDialog> createState() => _BudgetFormDialogState();
}

class _BudgetFormDialogState extends State<_BudgetFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tagController;
  late final TextEditingController _limitController;
  bool _isLoading = false;

  static const _categories = [
    'Food & Drink',
    'Transportation',
    'Entertainment',
    'Shopping',
    'Bills & Utilities',
    'Healthcare',
    'Education',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _tagController = TextEditingController(
      text: widget.budget?.tag ?? _categories.first,
    );
    _limitController = TextEditingController(
      text: widget.budget != null
          ? (widget.budget!.limitCents / 100).toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _tagController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final limitCents = (double.parse(_limitController.text) * 100).round();
      await widget.onSave(_tagController.text, limitCents);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.budget != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Budget' : 'Create Budget'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _tagController.text,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: _categories
                  .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                  .toList(),
              onChanged: (value) {
                if (value != null) _tagController.text = value;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _limitController,
              decoration: const InputDecoration(
                labelText: 'Monthly Limit',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) return 'Enter a limit';
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0)
                  return 'Enter a valid amount';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
