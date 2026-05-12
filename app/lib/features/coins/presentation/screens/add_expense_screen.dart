import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../bill_split/domain/models/receipt_item.dart';
import '../../../bill_split/domain/services/receipt_parser_service.dart';
import '../../domain/entities/transaction.dart';
import '../../application/providers/expense_providers.dart';

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
  const AddExpenseScreen({super.key});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _imagePicker = ImagePicker();

  String? _selectedCategoryId;
  String? _selectedAccountId;
  DateTime _selectedDate = DateTime.now();
  TransactionType _transactionType = TransactionType.expense;

  // Receipt scanning state
  bool _isScanning = false;
  ParsedReceipt? _scannedReceipt;
  String? _receiptImagePath;

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
              const _PlaceholderField(
                label: 'Category',
                icon: Icons.category_outlined,
              ),
              const SizedBox(height: 16),

              // Account Selector
              // TODO: Implement account picker
              const _PlaceholderField(
                label: 'Account',
                icon: Icons.account_balance_wallet_outlined,
              ),
              const SizedBox(height: 16),

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
      receiptId: _receiptImagePath,
      tags: [],
      createdAt: DateTime.now(),
      isDeleted: false,
    );

    ref.read(addExpenseProvider.notifier).addExpense(transaction);
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
                        Text(
                          '₹${(item.totalPricePaise / 100).toStringAsFixed(2)}',
                        ),
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
                  '₹${(receipt.grandTotalPaise / 100).toStringAsFixed(2)}',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Found ${receipt.items.length} items totaling ₹${(receipt.grandTotalPaise / 100).toStringAsFixed(2)}',
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
    final itemsList = receipt.items
        .map(
          (item) =>
              '• ${item.name}: ₹${(item.totalPricePaise / 100).toStringAsFixed(2)}',
        )
        .join('\n');
    _notesController.text = 'Receipt items:\n$itemsList';

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Receipt data applied to form'),
        backgroundColor: Colors.green,
      ),
    );
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
