import '../../domain/entities/shared_expense.dart';
import '../../domain/entities/split_entry.dart';
import '../../domain/repositories/group_repository.dart';
import '../../domain/services/split_calculator.dart';

/// Result type for use case operations
typedef Result<T> = ({T? data, String? error});

/// Use case for adding a shared expense with splits
///
/// Phase: 2 (Split Engine)
/// See: docs/features/coins/ENGINEERING_TICKETS_PHASE_2.md (COINS-021)
class AddSplitUseCase {
  final GroupRepository _repository;
  final SplitCalculator _calculator;

  AddSplitUseCase(this._repository, this._calculator);

  /// Execute the use case
  Future<Result<SharedExpense>> execute(AddSplitParams params) async {
    // Validate
    if (params.description.trim().isEmpty) {
      return (data: null, error: 'Description is required');
    }

    if (params.totalAmountCents <= 0) {
      return (data: null, error: 'Amount must be greater than zero');
    }

    if (params.groupId.isEmpty) {
      return (data: null, error: 'Group is required');
    }

    if (params.paidByUserId.isEmpty) {
      return (data: null, error: 'Payer is required');
    }

    if (params.participantIds.isEmpty) {
      return (data: null, error: 'At least one participant is required');
    }

    // Calculate splits based on type
    List<SplitEntry> splits;
    final expenseId = _generateExpenseId();

    switch (params.splitType) {
      case SplitType.equal:
        splits = _calculator.calculateEqualSplit(
          sharedExpenseId: expenseId,
          totalAmountCents: params.totalAmountCents,
          participantIds: params.participantIds,
        );
        break;
      case SplitType.percentage:
        if (params.percentages == null) {
          return (
            data: null,
            error: 'Percentages required for percentage split',
          );
        }
        splits = _calculator.calculatePercentageSplit(
          sharedExpenseId: expenseId,
          totalAmountCents: params.totalAmountCents,
          percentages: params.percentages!,
        );
        break;
      case SplitType.exact:
        if (params.exactAmounts == null) {
          return (data: null, error: 'Amounts required for exact split');
        }
        splits = _calculator.calculateExactSplit(
          sharedExpenseId: expenseId,
          totalAmountCents: params.totalAmountCents,
          amounts: params.exactAmounts!,
        );
        break;
      case SplitType.shares:
        if (params.shares == null) {
          return (data: null, error: 'Shares required for shares split');
        }
        splits = _calculator.calculateSharesSplit(
          sharedExpenseId: expenseId,
          totalAmountCents: params.totalAmountCents,
          shares: params.shares!,
        );
        break;
      case SplitType.itemized:
        final itemizedItems = params.itemizedItems;
        if (itemizedItems == null || itemizedItems.isEmpty) {
          return (data: null, error: 'Items required for itemized split');
        }
        final itemizedResult = _calculateItemizedSplits(
          sharedExpenseId: expenseId,
          totalAmountCents: params.totalAmountCents,
          participantIds: params.participantIds,
          items: itemizedItems,
        );
        if (itemizedResult.error != null) {
          return (data: null, error: itemizedResult.error);
        }
        splits = itemizedResult.data!;
    }

    // Validate splits sum to total
    if (!_calculator.validateSplit(params.totalAmountCents, splits)) {
      return (data: null, error: 'Split amounts do not sum to total');
    }

    final now = DateTime.now();
    final expense = SharedExpense(
      id: expenseId,
      groupId: params.groupId,
      description: params.description.trim(),
      totalAmountCents: params.totalAmountCents,
      currencyCode: params.currencyCode,
      paidByUserId: params.paidByUserId,
      splitType: params.splitType,
      splits: splits,
      categoryId: params.categoryId ?? 'general',
      notes: params.notes,
      receiptId: params.receiptUrl,
      expenseDate: params.expenseDate ?? now,
      createdAt: now,
      isDeleted: false,
    );

    return _repository.addExpense(expense);
  }

  String _generateExpenseId() {
    return 'expense_${DateTime.now().millisecondsSinceEpoch}';
  }
}

/// Parameters for adding a split expense
class AddSplitParams {
  final String groupId;
  final String description;
  final int totalAmountCents;
  final String currencyCode;
  final String paidByUserId;
  final SplitType splitType;
  final List<String> participantIds;
  final Map<String, double>? percentages;
  final Map<String, int>? exactAmounts;
  final Map<String, int>? shares;
  final List<ItemizedSplitInput>? itemizedItems;
  final String? categoryId;
  final String? notes;
  final String? receiptUrl;
  final DateTime? expenseDate;

  const AddSplitParams({
    required this.groupId,
    required this.description,
    required this.totalAmountCents,
    this.currencyCode = 'INR',
    required this.paidByUserId,
    this.splitType = SplitType.equal,
    required this.participantIds,
    this.percentages,
    this.exactAmounts,
    this.shares,
    this.itemizedItems,
    this.categoryId,
    this.notes,
    this.receiptUrl,
    this.expenseDate,
  });
}

/// A receipt line item selected for an itemized split.
class ItemizedSplitInput {
  final String itemId;
  final String name;
  final int amountCents;
  final List<String> participantIds;

  const ItemizedSplitInput({
    required this.itemId,
    required this.name,
    required this.amountCents,
    required this.participantIds,
  });
}

Result<List<SplitEntry>> _calculateItemizedSplits({
  required String sharedExpenseId,
  required int totalAmountCents,
  required List<String> participantIds,
  required List<ItemizedSplitInput> items,
}) {
  final participantSet = participantIds.toSet();
  final totals = <String, int>{for (final id in participantIds) id: 0};
  final itemIdsByParticipant = <String, List<String>>{
    for (final id in participantIds) id: <String>[],
  };

  var itemTotal = 0;
  for (final item in items) {
    if (item.itemId.trim().isEmpty || item.name.trim().isEmpty) {
      return (data: null, error: 'Every item needs a name and ID');
    }
    if (item.amountCents <= 0) {
      return (data: null, error: 'Item amounts must be greater than zero');
    }

    final assignedIds = item.participantIds.isEmpty
        ? participantIds
        : item.participantIds;
    if (assignedIds.isEmpty) {
      return (data: null, error: 'Every item needs at least one participant');
    }
    String? unknownParticipant;
    for (final id in assignedIds) {
      if (!participantSet.contains(id)) {
        unknownParticipant = id;
        break;
      }
    }
    if (unknownParticipant != null) {
      return (
        data: null,
        error: 'Item assigned to unknown participant: $unknownParticipant',
      );
    }

    itemTotal += item.amountCents;
    final baseAmount = item.amountCents ~/ assignedIds.length;
    final remainder = item.amountCents % assignedIds.length;
    for (var i = 0; i < assignedIds.length; i++) {
      final participantId = assignedIds[i];
      totals[participantId] =
          (totals[participantId] ?? 0) + baseAmount + (i < remainder ? 1 : 0);
      itemIdsByParticipant[participantId]!.add(item.itemId);
    }
  }

  if (itemTotal != totalAmountCents) {
    return (data: null, error: 'Itemized amounts do not sum to total');
  }

  final now = DateTime.now();
  var index = 0;
  final splits = <SplitEntry>[];
  for (final participantId in participantIds) {
    final amountCents = totals[participantId] ?? 0;
    final itemIds = itemIdsByParticipant[participantId] ?? const <String>[];
    if (amountCents == 0 && itemIds.isEmpty) continue;
    splits.add(
      SplitEntry(
        id: '${sharedExpenseId}_split_$index',
        sharedExpenseId: sharedExpenseId,
        userId: participantId,
        amountCents: amountCents,
        itemIds: List.unmodifiable(itemIds),
        createdAt: now,
      ),
    );
    index++;
  }

  return (data: splits, error: null);
}
