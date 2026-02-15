import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/split_entry.dart';
import '../../application/providers/split_providers.dart';
import '../../application/providers/group_providers.dart';

/// Add Split Expense Screen
///
/// Screen for adding a shared expense with split options:
/// - Amount input
/// - Description
/// - Paid by selector
/// - Split type selection (equal, percentage, exact, shares)
/// - Participant selection
///
/// Phase: 2 (Split Engine)
/// See: docs/features/coins/UI_WIREFRAMES.md (Screen 7)
class AddSplitExpenseScreen extends ConsumerStatefulWidget {
  final String groupId;

  const AddSplitExpenseScreen({super.key, required this.groupId});

  @override
  ConsumerState<AddSplitExpenseScreen> createState() =>
      _AddSplitExpenseScreenState();
}

class _AddSplitExpenseScreenState extends ConsumerState<AddSplitExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  String? _paidByUserId;
  SplitType _splitType = SplitType.equal;
  List<String> _selectedParticipantIds = [];

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final selectedSplitType = ref.watch(selectedSplitTypeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
        actions: [
          TextButton(
            onPressed: _saveExpense,
            child: const Text('Save'),
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
              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                  hintText: '0.00',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What was this for?',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Paid by
              Text('Paid by', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              membersAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('Error loading members'),
                data: (members) => Wrap(
                  spacing: 8,
                  children: members.map((member) {
                    final isSelected = _paidByUserId == member.userId;
                    return ChoiceChip(
                      label: Text(member.displayName),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _paidByUserId = member.userId);
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Split Type
              Text('Split type', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<SplitType>(
                segments: SplitType.values
                    .where((t) => t != SplitType.itemized)
                    .map((type) => ButtonSegment(
                          value: type,
                          label: Text(type.displayName),
                        ))
                    .toList(),
                selected: {selectedSplitType},
                onSelectionChanged: (types) {
                  ref.read(selectedSplitTypeProvider.notifier).state = types.first;
                  setState(() => _splitType = types.first);
                },
              ),
              const SizedBox(height: 24),

              // Participants
              Text('Split between', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              membersAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('Error loading members'),
                data: (members) => Column(
                  children: members.map((member) {
                    final isSelected = _selectedParticipantIds.contains(member.userId);
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedParticipantIds.add(member.userId);
                          } else {
                            _selectedParticipantIds.remove(member.userId);
                          }
                        });
                      },
                      title: Text(member.displayName),
                      secondary: CircleAvatar(
                        child: Text(member.displayName.substring(0, 1)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Split Preview
              if (_selectedParticipantIds.isNotEmpty) ...[
                Text('Split preview', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _SplitPreviewCard(
                  groupId: widget.groupId,
                  totalAmountCents: _parseAmount(),
                  splitType: _splitType,
                  participantIds: _selectedParticipantIds,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  int _parseAmount() {
    final text = _amountController.text.replaceAll(',', '');
    final amount = double.tryParse(text) ?? 0;
    return (amount * 100).round();
  }

  void _saveExpense() {
    if (!_formKey.currentState!.validate()) return;
    if (_paidByUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select who paid')),
      );
      return;
    }
    if (_selectedParticipantIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select participants')),
      );
      return;
    }

    // TODO: Create and save the shared expense
    Navigator.pop(context);
  }
}

class _SplitPreviewCard extends ConsumerWidget {
  final String groupId;
  final int totalAmountCents;
  final SplitType splitType;
  final List<String> participantIds;

  const _SplitPreviewCard({
    required this.groupId,
    required this.totalAmountCents,
    required this.splitType,
    required this.participantIds,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (totalAmountCents <= 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Enter an amount to see split preview'),
        ),
      );
    }

    final splits = ref.watch(splitPreviewProvider(SplitPreviewParams(
      expenseId: 'preview',
      totalAmountCents: totalAmountCents,
      splitType: splitType,
      participantIds: participantIds,
    )));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: splits.map((split) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(split.userId),
              trailing: Text('₹${(split.amountCents / 100).toStringAsFixed(2)}'),
            );
          }).toList(),
        ),
      ),
    );
  }
}

