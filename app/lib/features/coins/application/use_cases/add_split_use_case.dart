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
          return (data: null, error: 'Percentages required for percentage split');
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
        // TODO: Implement itemized split
        return (data: null, error: 'Itemized split not yet implemented');
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
      categoryId: params.categoryId,
      notes: params.notes,
      receiptUrl: params.receiptUrl,
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
    this.categoryId,
    this.notes,
    this.receiptUrl,
    this.expenseDate,
  });
}

