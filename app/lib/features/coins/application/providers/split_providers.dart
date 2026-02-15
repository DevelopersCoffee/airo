import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/shared_expense.dart';
import '../../domain/entities/split_entry.dart';
import '../../domain/services/split_calculator.dart';
import '../../domain/repositories/group_repository.dart';
import 'group_providers.dart';

/// Split calculator provider
///
/// Phase: 2 (Split Engine)
final splitCalculatorProvider = Provider<SplitCalculator>((ref) {
  return SplitCalculatorImpl();
});

/// Currently selected split type
final selectedSplitTypeProvider = StateProvider<SplitType>((ref) {
  return SplitType.equal;
});

/// Split preview - calculates splits before saving
final splitPreviewProvider = Provider.family<List<SplitEntry>, SplitPreviewParams>(
  (ref, params) {
    final calculator = ref.watch(splitCalculatorProvider);

    switch (params.splitType) {
      case SplitType.equal:
        return calculator.calculateEqualSplit(
          sharedExpenseId: params.expenseId,
          totalAmountCents: params.totalAmountCents,
          participantIds: params.participantIds,
        );
      case SplitType.percentage:
        return calculator.calculatePercentageSplit(
          sharedExpenseId: params.expenseId,
          totalAmountCents: params.totalAmountCents,
          percentages: params.percentages ?? {},
        );
      case SplitType.exact:
        return calculator.calculateExactSplit(
          sharedExpenseId: params.expenseId,
          totalAmountCents: params.totalAmountCents,
          amounts: params.exactAmounts ?? {},
        );
      case SplitType.shares:
        return calculator.calculateSharesSplit(
          sharedExpenseId: params.expenseId,
          totalAmountCents: params.totalAmountCents,
          shares: params.shares ?? {},
        );
      case SplitType.itemized:
        // TODO: Implement itemized split
        return [];
    }
  },
);

/// Parameters for split preview
class SplitPreviewParams {
  final String expenseId;
  final int totalAmountCents;
  final SplitType splitType;
  final List<String> participantIds;
  final Map<String, double>? percentages;
  final Map<String, int>? exactAmounts;
  final Map<String, int>? shares;

  const SplitPreviewParams({
    required this.expenseId,
    required this.totalAmountCents,
    required this.splitType,
    required this.participantIds,
    this.percentages,
    this.exactAmounts,
    this.shares,
  });
}

/// Add shared expense state notifier
final addSharedExpenseProvider = StateNotifierProvider.autoDispose<
    AddSharedExpenseNotifier, AsyncValue<SharedExpense?>>(
  (ref) => AddSharedExpenseNotifier(ref),
);

class AddSharedExpenseNotifier extends StateNotifier<AsyncValue<SharedExpense?>> {
  final Ref _ref;

  AddSharedExpenseNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> addExpense(SharedExpense expense) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(groupRepositoryProvider);
      final result = await repo.addExpense(expense);
      if (result.error != null) {
        state = AsyncValue.error(result.error!, StackTrace.current);
      } else {
        state = AsyncValue.data(result.data);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateExpense(SharedExpense expense) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(groupRepositoryProvider);
      final result = await repo.updateExpense(expense);
      if (result.error != null) {
        state = AsyncValue.error(result.error!, StackTrace.current);
      } else {
        state = AsyncValue.data(result.data);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(groupRepositoryProvider);
      await repo.deleteExpense(expenseId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

