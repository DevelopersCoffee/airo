import '../../domain/entities/shared_expense.dart';
import '../../domain/entities/settlement.dart';
import '../../domain/repositories/group_repository.dart';
import '../../domain/repositories/settlement_repository.dart';
import '../../domain/services/balance_engine.dart';
import '../../domain/services/debt_simplifier.dart';
import '../../domain/models/balance_summary.dart';
import '../../domain/models/debt_entry.dart';

/// Result type for use case operations
typedef Result<T> = ({T? data, String? error});

/// Use case for calculating group balances
///
/// Calculates net balances and simplified debts for a group.
///
/// Phase: 2 (Split Engine)
/// See: docs/features/coins/ENGINEERING_TICKETS_PHASE_2.md (COINS-025)
class CalculateBalancesUseCase {
  final GroupRepository _groupRepository;
  final SettlementRepository _settlementRepository;
  final BalanceEngine _balanceEngine;
  final DebtSimplifier _debtSimplifier;

  CalculateBalancesUseCase(
    this._groupRepository,
    this._settlementRepository,
    this._balanceEngine,
    this._debtSimplifier,
  );

  /// Calculate full balance summary for a group
  Future<Result<BalanceSummary>> execute(String groupId) async {
    if (groupId.isEmpty) {
      return (data: null, error: 'Group ID is required');
    }

    // Fetch expenses and settlements
    final expensesResult = await _groupRepository.getExpenses(groupId);
    if (expensesResult.error != null) {
      return (data: null, error: expensesResult.error);
    }

    final settlementsResult = await _settlementRepository.findByGroup(groupId);
    if (settlementsResult.error != null) {
      return (data: null, error: settlementsResult.error);
    }

    final expenses = expensesResult.data ?? [];
    final settlements = settlementsResult.data ?? [];

    // Calculate balances
    final summary = await _balanceEngine.calculateBalanceSummary(
      groupId: groupId,
      expenses: expenses,
      settlements: settlements,
    );

    // Simplify debts
    final simplifiedDebts = _debtSimplifier.fromNetBalances(summary.netBalances);

    return (
      data: summary.copyWith(simplifiedDebts: simplifiedDebts),
      error: null,
    );
  }

  /// Get balance for a specific user in a group
  Future<Result<int>> getUserBalance(String groupId, String userId) async {
    final summaryResult = await execute(groupId);
    if (summaryResult.error != null) {
      return (data: null, error: summaryResult.error);
    }

    final balance = _balanceEngine.getUserBalance(
      userId,
      summaryResult.data!.netBalances,
    );

    return (data: balance, error: null);
  }

  /// Get simplified debts for a group
  Future<Result<List<DebtEntry>>> getSimplifiedDebts(String groupId) async {
    final summaryResult = await execute(groupId);
    if (summaryResult.error != null) {
      return (data: null, error: summaryResult.error);
    }

    return (data: summaryResult.data!.simplifiedDebts, error: null);
  }
}

