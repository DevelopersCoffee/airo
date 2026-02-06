import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/bill_split_providers.dart';

/// Widget for entering bill details
class BillInputCard extends ConsumerStatefulWidget {
  final VoidCallback onBillCreated;

  const BillInputCard({super.key, required this.onBillCreated});

  @override
  ConsumerState<BillInputCard> createState() => _BillInputCardState();
}

class _BillInputCardState extends ConsumerState<BillInputCard> {
  final _formKey = GlobalKey<FormState>();
  final _vendorController = TextEditingController();
  final _amountController = TextEditingController();
  final _taxController = TextEditingController(text: '0');
  final _tipController = TextEditingController(text: '0');
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _vendorController.dispose();
    _amountController.dispose();
    _taxController.dispose();
    _tipController.dispose();
    super.dispose();
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

  void _createBill() {
    if (_formKey.currentState!.validate()) {
      final controller = ref.read(billSplitControllerProvider);

      controller.createSimpleBill(
        vendor: _vendorController.text.isNotEmpty
            ? _vendorController.text
            : null,
        date: _selectedDate,
        totalAmount: double.parse(_amountController.text),
        taxAmount: double.tryParse(_taxController.text) ?? 0,
        tipAmount: double.tryParse(_tipController.text) ?? 0,
      );

      widget.onBillCreated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Text(
              'Enter Bill Details',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add the total amount and optional details',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // Vendor name (optional)
            TextFormField(
              controller: _vendorController,
              decoration: const InputDecoration(
                labelText: 'Vendor/Restaurant (Optional)',
                prefixIcon: Icon(Icons.store_outlined),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // Date picker
            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Total amount
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Total Amount (₹)',
                prefixIcon: Icon(Icons.currency_rupee),
                border: OutlineInputBorder(),
                hintText: '0.00',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the total amount';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Tax and Tip row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _taxController,
                    decoration: const InputDecoration(
                      labelText: 'Tax (₹)',
                      prefixIcon: Icon(Icons.receipt_long_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _tipController,
                    decoration: const InputDecoration(
                      labelText: 'Tip (₹)',
                      prefixIcon: Icon(Icons.volunteer_activism_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Continue button
            FilledButton.icon(
              onPressed: _createBill,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Add Participants'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
