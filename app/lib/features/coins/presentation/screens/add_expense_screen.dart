import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../bill_split/domain/models/receipt_item.dart';
import '../../../bill_split/domain/services/receipt_parser_service.dart';
import '../../../../core/utils/locale_settings.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/category.dart' as coins;
import '../../domain/entities/transaction.dart';
import '../../domain/services/quick_add_expense_parser.dart';
import '../../application/providers/expense_providers.dart';
import '../../application/use_cases/add_expense_use_case.dart';

/// Provider for receipt parser service
final _receiptParserProvider = Provider<ReceiptParserService>((ref) {
  return MLKitReceiptParserService();
});

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
  final QuickExpenseDraft? initialDraft;

  const AddExpenseScreen({super.key, this.initialDraft});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _budgetTagController = TextEditingController();
  final _imagePicker = ImagePicker();

  String? _selectedCategoryId;
  String? _selectedAccountId;
  String? _categoryError;
  String? _accountError;
  DateTime _selectedDate = DateTime.now();
  TransactionType _transactionType = TransactionType.expense;
  bool _isRecurring = false;

  // Receipt scanning state
  bool _isScanning = false;
  ParsedReceipt? _scannedReceipt;
  String? _receiptImagePath;

  @override
  void initState() {
    super.initState();
    final draft = widget.initialDraft;
    if (draft == null) return;

    _descriptionController.text = draft.description;
    _amountController.text = (draft.amountCents / 100).toStringAsFixed(2);
    _budgetTagController.text = draft.budgetTag;
    _selectedCategoryId = draft.categoryId;
    _isRecurring = draft.isRecurring;
    if (draft.isSplit && draft.participants.isNotEmpty) {
      _notesController.text = 'Split with ${draft.participants.join(', ')}';
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _budgetTagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final addExpenseState = ref.watch(addExpenseProvider);
    final categories = ref.watch(expenseCategoryOptionsProvider);
    final accountsAsync = ref.watch(expenseAccountOptionsProvider);
    final currencyFormatter = ref.watch(currencyFormatterProvider);

    ref.listen<AsyncValue<void>>(addExpenseProvider, (_, state) {
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
              _AmountInputField(
                controller: _amountController,
                currencySymbol: currencyFormatter.currency.symbol,
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                key: const ValueKey('add_expense_description_field'),
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Example: Dinner at Haldiram\'s',
                  helperText: 'Merchant or short note',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Description is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _CategorySelector(
                categories: categories
                    .where(
                      (category) =>
                          category.type == coins.CategoryType.expense ||
                          category.type == coins.CategoryType.both,
                    )
                    .toList(),
                selectedCategoryId: _selectedCategoryId,
                errorText: _categoryError,
                onSelected: (categoryId) {
                  setState(() {
                    _selectedCategoryId = categoryId;
                    _categoryError = null;
                  });
                },
              ),
              const SizedBox(height: 16),

              _AccountSelector(
                accountsAsync: accountsAsync,
                selectedAccountId: _selectedAccountId,
                errorText: _accountError,
                onSelected: (accountId) {
                  setState(() {
                    _selectedAccountId = accountId;
                    _accountError = null;
                  });
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                key: const ValueKey('add_expense_budget_tag_field'),
                controller: _budgetTagController,
                decoration: const InputDecoration(
                  labelText: 'Budget tag',
                  hintText: 'Food, Travel, Bills',
                  helperText: 'Optional: connects this expense to budget views',
                  prefixIcon: Icon(Icons.sell_outlined),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 8),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Recurring expense'),
                subtitle: const Text('Mark rent, subscriptions, or bills'),
                value: _isRecurring,
                onChanged: (value) => setState(() => _isRecurring = value),
              ),
              const SizedBox(height: 8),

              // Date Picker
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Date'),
                subtitle: Text(
                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                ),
                onTap: _selectDate,
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                key: const ValueKey('add_expense_notes_field'),
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
              _buildReceiptSection(),
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
    final hasSelectionErrors =
        _selectedCategoryId == null || _selectedAccountId == null;
    if (hasSelectionErrors) {
      setState(() {
        _categoryError = _selectedCategoryId == null
            ? 'Choose a category'
            : null;
        _accountError = _selectedAccountId == null ? 'Choose who paid' : null;
      });
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

    final tags = <String>[
      if (_budgetTagController.text.trim().isNotEmpty)
        _budgetTagController.text.trim(),
      if (_isRecurring) 'recurring',
    ];

    ref
        .read(addExpenseProvider.notifier)
        .addExpenseFromInput(
          AddExpenseParams(
            description: _descriptionController.text,
            amountCents: amountCents,
            type: _transactionType,
            categoryId: _selectedCategoryId!,
            accountId: _selectedAccountId!,
            transactionDate: _selectedDate,
            notes: _notesController.text.isEmpty ? null : _notesController.text,
            receiptId: _receiptImagePath,
            tags: tags,
          ),
        );
  }

  /// Build the receipt scanning section
  Widget _buildReceiptSection() {
    if (_isScanning) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Scanning receipt...'),
              SizedBox(height: 8),
              Text(
                'Using on-device AI for privacy',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_scannedReceipt != null) {
      return _buildScannedReceiptCard();
    }

    return OutlinedButton.icon(
      onPressed: _showImageSourceDialog,
      icon: const Icon(Icons.camera_alt_outlined),
      label: const Text('Scan Receipt'),
    );
  }

  /// Show scanned receipt details
  Widget _buildScannedReceiptCard() {
    final receipt = _scannedReceipt!;
    final formatter = ref.watch(currencyFormatterProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    receipt.vendor ?? 'Receipt Scanned',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() {
                    _scannedReceipt = null;
                    _receiptImagePath = null;
                  }),
                ),
              ],
            ),
            const Divider(),
            Text(
              '${receipt.items.length} items detected',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            // Show first 3 items
            ...receipt.items
                .take(3)
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(formatter.formatCents(item.totalPricePaise)),
                      ],
                    ),
                  ),
                ),
            if (receipt.items.length > 3)
              Text(
                '...and ${receipt.items.length - 3} more',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  formatter.formatCents(receipt.grandTotalPaise),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _applyReceiptToForm(receipt),
                icon: const Icon(Icons.check),
                label: const Text('Use This Amount'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show dialog to choose image source
  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              subtitle: const Text('Capture receipt with camera'),
              enabled: !kIsWeb,
              onTap: kIsWeb
                  ? null
                  : () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              subtitle: const Text('Select an existing photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Pick image and scan receipt
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        await _scanReceipt(image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  /// Scan receipt using ML Kit OCR + AI
  Future<void> _scanReceipt(String imagePath) async {
    setState(() => _isScanning = true);

    try {
      final parser = ref.read(_receiptParserProvider);
      final file = File(imagePath);

      if (!await file.exists()) {
        throw Exception('Image file not found');
      }

      final receipt = await parser.parseReceipt(file);

      if (mounted) {
        setState(() {
          _scannedReceipt = receipt;
          _receiptImagePath = imagePath;
          _isScanning = false;
        });

        // Show success message
        final formatter = ref.read(currencyFormatterProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Found ${receipt.items.length} items totaling ${formatter.formatCents(receipt.grandTotalPaise)}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to scan receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Apply scanned receipt data to the form
  void _applyReceiptToForm(ParsedReceipt receipt) {
    final amount = receipt.grandTotalPaise / 100;
    _amountController.text = amount.toStringAsFixed(2);

    // Set description from vendor or items
    if (receipt.vendor != null) {
      _descriptionController.text = receipt.vendor!;
    } else if (receipt.items.isNotEmpty) {
      _descriptionController.text = receipt.items.length == 1
          ? receipt.items.first.name
          : '${receipt.items.length} items';
    }

    // Add item details to notes
    final formatter = ref.read(currencyFormatterProvider);
    final itemsList = receipt.items
        .map(
          (item) =>
              '• ${item.name}: ${formatter.formatCents(item.totalPricePaise)}',
        )
        .join('\n');
    _notesController.text = 'Receipt items:\n$itemsList';
    if (receipt.vendor != null && _budgetTagController.text.isEmpty) {
      _budgetTagController.text = _suggestBudgetTag(receipt.vendor!);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Receipt data applied to form'),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _suggestBudgetTag(String merchant) {
    final text = merchant.toLowerCase();
    if (text.contains('uber') || text.contains('ola')) return 'Travel';
    if (text.contains('netflix') || text.contains('spotify')) {
      return 'Entertainment';
    }
    if (text.contains('mart') || text.contains('grocery')) return 'Groceries';
    return 'Food';
  }
}

class _AmountInputField extends StatelessWidget {
  final TextEditingController controller;
  final String currencySymbol;
  const _AmountInputField({
    required this.controller,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: const ValueKey('add_expense_amount_field'),
      controller: controller,
      keyboardType: TextInputType.number,
      autofocus: true,
      textInputAction: TextInputAction.next,
      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: 'Amount',
        prefixText: '$currencySymbol ',
        hintText: '0.00',
        helperText: 'Example: 250.00',
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Amount is required';
        return null;
      },
    );
  }
}

class _CategorySelector extends StatelessWidget {
  final List<coins.Category> categories;
  final String? selectedCategoryId;
  final String? errorText;
  final ValueChanged<String> onSelected;

  const _CategorySelector({
    required this.categories,
    required this.selectedCategoryId,
    required this.errorText,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Category', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((category) {
            return ChoiceChip(
              label: Text(category.name),
              selected: selectedCategoryId == category.id,
              onSelected: (_) => onSelected(category.id),
            );
          }).toList(),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _AccountSelector extends StatelessWidget {
  final AsyncValue<List<Account>> accountsAsync;
  final String? selectedAccountId;
  final String? errorText;
  final ValueChanged<String> onSelected;

  const _AccountSelector({
    required this.accountsAsync,
    required this.selectedAccountId,
    required this.errorText,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return accountsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text('Error loading accounts: $error'),
      data: (accounts) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Who paid?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: accounts.map((account) {
              return ChoiceChip(
                label: Text(account.name),
                selected: selectedAccountId == account.id,
                onSelected: (_) => onSelected(account.id),
              );
            }).toList(),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              errorText!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
