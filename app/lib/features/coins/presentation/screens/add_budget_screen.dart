import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/locale_settings.dart';
import '../../domain/entities/budget.dart';
import '../../application/providers/budget_providers.dart';

/// Screen for adding or editing a budget
///
/// Phase: 1 (Foundation)
class AddBudgetScreen extends ConsumerStatefulWidget {
  const AddBudgetScreen({super.key});

  @override
  ConsumerState<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends ConsumerState<AddBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _limitController = TextEditingController();
  String _selectedCategory = 'food';

  final List<({String id, String label, IconData icon})> _categories = [
    (id: 'food', label: 'Food & Drink', icon: Icons.restaurant),
    (id: 'transport', label: 'Transport', icon: Icons.directions_car),
    (id: 'bills', label: 'Bills', icon: Icons.receipt_long),
    (id: 'shopping', label: 'Shopping', icon: Icons.shopping_bag),
    (id: 'entertainment', label: 'Entertainment', icon: Icons.movie),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  void _saveBudget() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final limitDouble = double.tryParse(_limitController.text.trim()) ?? 0.0;
    final limitCents = (limitDouble * 100).round();

    if (limitCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid limit')),
      );
      return;
    }

    final budget = Budget(
      id: const Uuid().v4(),
      name: name.isEmpty ? null : name,
      categoryId: _selectedCategory,
      limitCents: limitCents,
      period: BudgetPeriod.monthly,
      startDate: DateTime.now(),
      createdAt: DateTime.now(),
    );

    ref.read(setBudgetProvider.notifier).setBudget(budget);
  }

  @override
  Widget build(BuildContext context) {
    final saveState = ref.watch(setBudgetProvider);
    final currencyFormatter = ref.watch(currencyFormatterProvider);

    ref.listen<AsyncValue<void>>(setBudgetProvider, (_, state) {
      state.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $error'),
              backgroundColor: Colors.red,
            ),
          );
        },
        data: (_) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Budget saved successfully')),
          );
        },
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Budget'),
        actions: [
          TextButton(
            key: const ValueKey('add_budget_save_button'),
            onPressed: saveState.isLoading ? null : _saveBudget,
            child: saveState.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Name Field
            TextFormField(
              key: const ValueKey('add_budget_name_field'),
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Budget Name (optional)',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 20),

            // Limit Field
            TextFormField(
              key: const ValueKey('add_budget_limit_field'),
              controller: _limitController,
              decoration: InputDecoration(
                labelText: 'Monthly Limit',
                prefixText: '${currencyFormatter.currency.symbol} ',
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Limit is required';
                }
                if (double.tryParse(value.trim()) == null) {
                  return 'Enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 28),

            // Category Selector
            Text(
              'Select Category',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat.id;
                return ChoiceChip(
                  key: ValueKey('add_budget_category_${cat.id}'),
                  avatar: Icon(
                    cat.icon,
                    size: 18,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.primary,
                  ),
                  label: Text(cat.label),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedCategory = cat.id);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
