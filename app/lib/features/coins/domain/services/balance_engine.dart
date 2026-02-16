import '../entities/shared_expense.dart';
import '../entities/settlement.dart';
import '../models/balance_summary.dart';
import '../models/debt_entry.dart';
import 'debt_simplifier.dart';

/// Balance calculation engine interface
///
/// Calculates net balances and debts within a group.
///
/// Phase: 2 (Split Engine)
/// See: docs/features/coins/ENGINEERING_TICKETS_PHASE_2.md (COINS-025)
abstract class BalanceEngine {
  /// Calculate net balances for all members in a group
  ///
  /// Returns a map of userId -> net balance in cents
  /// Positive = they are owed money
  /// Negative = they owe money
  Future<Map<String, int>> calculateNetBalances({
    required List<SharedExpense> expenses,
    required List<Settlement> settlements,
  });

  /// Calculate the full balance summary for a group
  Future<BalanceSummary> calculateBalanceSummary({
    required String groupId,
    required List<SharedExpense> expenses,
    required List<Settlement> settlements,
  });

  /// Get individual debts (who owes whom, how much)
  List<DebtEntry> calculateDebts(Map<String, int> netBalances);

  /// Get a user's balance in the group
  int getUserBalance(String userId, Map<String, int> netBalances);
}

/// Default implementation of BalanceEngine
class BalanceEngineImpl implements BalanceEngine {
  final DebtSimplifier _simplifier;

  BalanceEngineImpl({DebtSimplifier? simplifier})
    : _simplifier = simplifier ?? DebtSimplifierImpl();

  @override
  Future<Map<String, int>> calculateNetBalances({
    required List<SharedExpense> expenses,
    required List<Settlement> settlements,
  }) async {
    final balances = <String, int>{};

    // Process expenses
    for (final expense in expenses) {
      if (expense.isDeleted) continue;

      // Add to payer's balance (they are owed)
      balances[expense.paidByUserId] =
          (balances[expense.paidByUserId] ?? 0) + expense.totalAmountCents;

      // Subtract from each split participant
      for (final split in expense.splits) {
        balances[split.userId] =
            (balances[split.userId] ?? 0) - split.amountCents;
      }
    }

    // Process settlements
    for (final settlement in settlements) {
      if (settlement.status != SettlementStatus.completed) continue;

      // fromUser paid, so their balance increases
      balances[settlement.fromUserId] =
          (balances[settlement.fromUserId] ?? 0) + settlement.amountCents;

      // toUser received, so their balance decreases
      balances[settlement.toUserId] =
          (balances[settlement.toUserId] ?? 0) - settlement.amountCents;
    }

    return balances;
  }

  @override
  Future<BalanceSummary> calculateBalanceSummary({
    required String groupId,
    required List<SharedExpense> expenses,
    required List<Settlement> settlements,
  }) async {
    final netBalances = await calculateNetBalances(
      expenses: expenses,
      settlements: settlements,
    );

    final debts = calculateDebts(netBalances);
    final simplifiedDebts = _simplifier.simplify(debts);

    final totalExpenses = expenses
        .where((e) => !e.isDeleted)
        .fold<int>(0, (sum, e) => sum + e.totalAmountCents);

    final totalSettlements = settlements
        .where((s) => s.status == SettlementStatus.completed)
        .fold<int>(0, (sum, s) => sum + s.amountCents);

    return BalanceSummary(
      groupId: groupId,
      netBalances: netBalances,
      debts: debts,
      simplifiedDebts: simplifiedDebts,
      totalExpensesCents: totalExpenses,
      totalSettlementsCents: totalSettlements,
      calculatedAt: DateTime.now(),
    );
  }

  @override
  List<DebtEntry> calculateDebts(Map<String, int> netBalances) {
    // Use the simplifier to convert net balances to minimal debt entries
    return _simplifier.fromNetBalances(netBalances);
  }

  @override
  int getUserBalance(String userId, Map<String, int> netBalances) {
    return netBalances[userId] ?? 0;
  }
}
