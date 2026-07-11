import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/locale_settings.dart';
import '../../domain/entities/split_entry.dart';
import '../../application/providers/split_providers.dart';
import '../../application/providers/group_providers.dart';
import '../../application/use_cases/add_split_use_case.dart';

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
  final Map<String, TextEditingController> _percentageControllers = {};
  final Map<String, TextEditingController> _exactAmountControllers = {};
  final Map<String, TextEditingController> _shareControllers = {};

  String? _paidByUserId;
  SplitType _splitType = SplitType.equal;
  final List<String> _selectedParticipantIds = [];
  bool _isSaving = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    for (final controller in _percentageControllers.values) {
      controller.dispose();
    }
    for (final controller in _exactAmountControllers.values) {
      controller.dispose();
    }
    for (final controller in _shareControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final currencyFormatter = ref.watch(currencyFormatterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveExpense,
            child: _isSaving ? const Text('Saving...') : const Text('Save'),
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
                key: const ValueKey('add_split_amount_field'),
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  hintText: '0.00',
                ).copyWith(prefixText: '${currencyFormatter.currency.symbol} '),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                key: const ValueKey('add_split_desc_field'),
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
                error: (error, stackTrace) =>
                    const Text('Error loading members'),
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
              Text(
                'Split type',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<SplitType>(
                segments: SplitType.values
                    .where((t) => t != SplitType.itemized)
                    .map(
                      (type) => ButtonSegment(
                        value: type,
                        label: Text(type.displayName),
                      ),
                    )
                    .toList(),
                selected: {_splitType},
                onSelectionChanged: (types) {
                  ref.read(selectedSplitTypeProvider.notifier).state =
                      types.first;
                  setState(() => _splitType = types.first);
                },
              ),
              const SizedBox(height: 24),

              // Participants
              Text(
                'Split between',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              membersAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (error, stackTrace) =>
                    const Text('Error loading members'),
                data: (members) => Column(
                  children: members.map((member) {
                    final isSelected = _selectedParticipantIds.contains(
                      member.userId,
                    );
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedParticipantIds.add(member.userId);
                            _ensureCustomControllers(member.userId);
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

              if (_splitType != SplitType.equal &&
                  _selectedParticipantIds.isNotEmpty) ...[
                Text(
                  'Custom split',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                membersAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (error, stackTrace) =>
                      const Text('Error loading members'),
                  data: (members) {
                    final namesByUserId = {
                      for (final member in members)
                        member.userId: member.displayName,
                    };
                    return _CustomSplitInputList(
                      splitType: _splitType,
                      participantIds: _selectedParticipantIds,
                      namesByUserId: namesByUserId,
                      percentageControllers: _percentageControllers,
                      exactAmountControllers: _exactAmountControllers,
                      shareControllers: _shareControllers,
                      onChanged: () => setState(() {}),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],

              // Split Preview
              if (_selectedParticipantIds.isNotEmpty) ...[
                Text(
                  'Split preview',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _SplitPreviewCard(
                  groupId: widget.groupId,
                  totalAmountCents: _parseAmount(),
                  splitType: _splitType,
                  participantIds: _selectedParticipantIds,
                  percentages: _splitType == SplitType.percentage
                      ? _parsePercentages()
                      : null,
                  exactAmounts: _splitType == SplitType.exact
                      ? _parseExactAmounts()
                      : null,
                  shares: _splitType == SplitType.shares
                      ? _parseShares()
                      : null,
                  validationMessage: _customSplitValidationMessage(),
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

  double _parseDecimal(String text) {
    return double.tryParse(text.trim().replaceAll(',', '')) ?? 0;
  }

  Map<String, double> _parsePercentages() {
    return {
      for (final userId in _selectedParticipantIds)
        userId: _parseDecimal(_percentageControllers[userId]?.text ?? ''),
    };
  }

  Map<String, int> _parseExactAmounts() {
    return {
      for (final userId in _selectedParticipantIds)
        userId:
            (_parseDecimal(_exactAmountControllers[userId]?.text ?? '') * 100)
                .round(),
    };
  }

  Map<String, int> _parseShares() {
    return {
      for (final userId in _selectedParticipantIds)
        userId: int.tryParse(_shareControllers[userId]?.text.trim() ?? '') ?? 0,
    };
  }

  String? _customSplitValidationMessage() {
    if (_splitType == SplitType.equal || _selectedParticipantIds.isEmpty) {
      return null;
    }

    switch (_splitType) {
      case SplitType.percentage:
        final total = _parsePercentages().values.fold<double>(
          0,
          (sum, value) => sum + value,
        );
        if ((total - 100).abs() > 0.01) {
          return 'Enter percentages that total 100';
        }
        return null;
      case SplitType.exact:
        final total = _parseExactAmounts().values.fold<int>(
          0,
          (sum, value) => sum + value,
        );
        if (total != _parseAmount()) {
          return 'Enter amounts that total the expense amount';
        }
        return null;
      case SplitType.shares:
        final total = _parseShares().values.fold<int>(
          0,
          (sum, value) => sum + value,
        );
        if (total <= 0) {
          return 'Enter at least one share';
        }
        return null;
      case SplitType.equal:
      case SplitType.itemized:
        return null;
    }
  }

  void _ensureCustomControllers(String userId) {
    _percentageControllers.putIfAbsent(userId, TextEditingController.new);
    _exactAmountControllers.putIfAbsent(userId, TextEditingController.new);
    _shareControllers.putIfAbsent(userId, TextEditingController.new);
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    if (_paidByUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select who paid')));
      return;
    }
    if (_selectedParticipantIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select participants')),
      );
      return;
    }
    final customSplitError = _customSplitValidationMessage();
    if (customSplitError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(customSplitError)));
      return;
    }

    setState(() => _isSaving = true);
    final result = await ref
        .read(addSplitUseCaseProvider)
        .execute(
          AddSplitParams(
            groupId: widget.groupId,
            description: _descriptionController.text,
            totalAmountCents: _parseAmount(),
            currencyCode: ref.read(currencyFormatterProvider).currency.code,
            paidByUserId: _paidByUserId!,
            splitType: _splitType,
            participantIds: List.unmodifiable(_selectedParticipantIds),
            percentages: _splitType == SplitType.percentage
                ? _parsePercentages()
                : null,
            exactAmounts: _splitType == SplitType.exact
                ? _parseExactAmounts()
                : null,
            shares: _splitType == SplitType.shares ? _parseShares() : null,
          ),
        );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.error!)));
      return;
    }

    ref.invalidate(groupExpensesProvider(widget.groupId));
    Navigator.pop(context);
  }
}

class _CustomSplitInputList extends StatelessWidget {
  final SplitType splitType;
  final List<String> participantIds;
  final Map<String, String> namesByUserId;
  final Map<String, TextEditingController> percentageControllers;
  final Map<String, TextEditingController> exactAmountControllers;
  final Map<String, TextEditingController> shareControllers;
  final VoidCallback onChanged;

  const _CustomSplitInputList({
    required this.splitType,
    required this.participantIds,
    required this.namesByUserId,
    required this.percentageControllers,
    required this.exactAmountControllers,
    required this.shareControllers,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: participantIds.map((userId) {
        final name = namesByUserId[userId] ?? userId;
        final controller = switch (splitType) {
          SplitType.percentage => percentageControllers[userId]!,
          SplitType.exact => exactAmountControllers[userId]!,
          SplitType.shares => shareControllers[userId]!,
          SplitType.equal ||
          SplitType.itemized => percentageControllers[userId]!,
        };
        final label = switch (splitType) {
          SplitType.percentage => '$name %',
          SplitType.exact => '$name amount',
          SplitType.shares => '$name shares',
          SplitType.equal || SplitType.itemized => name,
        };
        final suffix = switch (splitType) {
          SplitType.percentage => '%',
          SplitType.exact => null,
          SplitType.shares => 'shares',
          SplitType.equal || SplitType.itemized => null,
        };

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: label, suffixText: suffix),
            onChanged: (_) => onChanged(),
          ),
        );
      }).toList(),
    );
  }
}

class _SplitPreviewCard extends ConsumerWidget {
  final String groupId;
  final int totalAmountCents;
  final SplitType splitType;
  final List<String> participantIds;
  final Map<String, double>? percentages;
  final Map<String, int>? exactAmounts;
  final Map<String, int>? shares;
  final String? validationMessage;

  const _SplitPreviewCard({
    required this.groupId,
    required this.totalAmountCents,
    required this.splitType,
    required this.participantIds,
    this.percentages,
    this.exactAmounts,
    this.shares,
    this.validationMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = ref.watch(currencyFormatterProvider);
    if (totalAmountCents <= 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Enter an amount to see split preview'),
        ),
      );
    }

    if (validationMessage != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(validationMessage!),
        ),
      );
    }

    final splits = ref.watch(
      splitPreviewProvider(
        SplitPreviewParams(
          expenseId: 'preview',
          totalAmountCents: totalAmountCents,
          splitType: splitType,
          participantIds: participantIds,
          percentages: percentages,
          exactAmounts: exactAmounts,
          shares: shares,
        ),
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: splits.map((split) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(split.userId),
              trailing: Text(formatter.formatCents(split.amountCents)),
            );
          }).toList(),
        ),
      ),
    );
  }
}
