import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/transaction.dart';
import '../../application/providers/expense_providers.dart';

/// Add Expense Screen
///
/// Screen for adding a new expense with:
/// - Amount input (numpad style)
/// - Category selection
/// - Account selection
/// - Date picker
/// - Notes/description
/// - Receipt attachment option
///
/// Phase: 1 (Foundation)
/// See: docs/features/coins/UI_WIREFRAMES.md (Screen 2)
class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedCategoryId;
  String? _selectedAccountId;
  DateTime _selectedDate = DateTime.now();
  TransactionType _transactionType = TransactionType.expense;

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final addExpenseState = ref.watch(addExpenseProvider);

    ref.listen<AsyncValue<void>>(addExpenseProvider, (_, state) {
      state.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
          );
        },
        data: (_) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense added successfully')),
          );
        },
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
        actions: [
          TextButton(
            onPressed: addExpenseState.isLoading ? null : _saveExpense,
            child: addExpenseState.isLoading
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Transaction Type Toggle
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text('Expense'),
                    icon: Icon(Icons.remove_circle_outline),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text('Income'),
                    icon: Icon(Icons.add_circle_outline),
                  ),
                ],
                selected: {_transactionType},
                onSelectionChanged: (types) {
                  setState(() => _transactionType = types.first);
                },
              ),
              const SizedBox(height: 24),

              // Amount Input
              _AmountInputField(controller: _amountController),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What was this for?',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Description is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category Selector
              // TODO: Implement category picker
              const _PlaceholderField(label: 'Category', icon: Icons.category_outlined),
              const SizedBox(height: 16),

              // Account Selector
              // TODO: Implement account picker
              const _PlaceholderField(label: 'Account', icon: Icons.account_balance_wallet_outlined),
              const SizedBox(height: 16),

              // Date Picker
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Date'),
                subtitle: Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                onTap: _selectDate,
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Add any additional details',
                  prefixIcon: Icon(Icons.note_outlined),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Receipt Attachment
              OutlinedButton.icon(
                onPressed: () {
                  // TODO: Implement receipt scanning
                },
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Attach Receipt'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _saveExpense() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null || _selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select category and account')),
      );
      return;
    }

    final amountText = _amountController.text.replaceAll(',', '');
    final amount = double.tryParse(amountText) ?? 0;
    final amountCents = (amount * 100).round();

    if (amountCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final transaction = Transaction(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      description: _descriptionController.text,
      amountCents: amountCents,
      type: _transactionType,
      categoryId: _selectedCategoryId!,
      accountId: _selectedAccountId!,
      transactionDate: _selectedDate,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      tags: [],
      createdAt: DateTime.now(),
      isDeleted: false,
    );

    ref.read(addExpenseProvider.notifier).addExpense(transaction);
  }
}

class _AmountInputField extends StatelessWidget {
  final TextEditingController controller;
  const _AmountInputField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
      decoration: const InputDecoration(
        labelText: 'Amount',
        prefixText: '₹ ',
        hintText: '0.00',
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Amount is required';
        return null;
      },
    );
  }
}

class _PlaceholderField extends StatelessWidget {
  final String label;
  final IconData icon;
  const _PlaceholderField({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: const Text('Tap to select'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        // TODO: Implement picker
      },
    );
  }
}

