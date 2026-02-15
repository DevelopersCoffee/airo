import 'package:equatable/equatable.dart';
import 'debt_entry.dart';

/// Balance summary for a group
///
/// Aggregates all balances within a group showing who owes whom.
///
/// Phase: 2 (Split Engine)
/// See: docs/features/coins/ENGINEERING_TICKETS_PHASE_2.md (COINS-025)
class BalanceSummary extends Equatable {
  final String groupId;
  final Map<String, int> netBalances; // userId -> net balance in cents
  final List<DebtEntry> debts; // Simplified debts
  final List<DebtEntry> simplifiedDebts; // After debt simplification
  final int totalExpensesCents;
  final int totalSettlementsCents;
  final DateTime calculatedAt;

  const BalanceSummary({
    required this.groupId,
    required this.netBalances,
    required this.debts,
    required this.simplifiedDebts,
    required this.totalExpensesCents,
    required this.totalSettlementsCents,
    required this.calculatedAt,
  });

  /// Get a user's net balance
  /// Positive = they are owed money
  /// Negative = they owe money
  int getUserBalance(String userId) => netBalances[userId] ?? 0;

  /// Check if group is settled (all balances are 0)
  bool get isSettled => netBalances.values.every((b) => b == 0);

  /// Get users who owe money
  List<String> get debtors =>
      netBalances.entries.where((e) => e.value < 0).map((e) => e.key).toList();

  /// Get users who are owed money
  List<String> get creditors =>
      netBalances.entries.where((e) => e.value > 0).map((e) => e.key).toList();

  /// Get minimum number of transactions to settle all debts
  int get minimumTransactions => simplifiedDebts.length;

  /// Create an empty balance summary
  factory BalanceSummary.empty(String groupId) {
    return BalanceSummary(
      groupId: groupId,
      netBalances: const {},
      debts: const [],
      simplifiedDebts: const [],
      totalExpensesCents: 0,
      totalSettlementsCents: 0,
      calculatedAt: DateTime.now(),
    );
  }

  /// Create a copy with updated fields
  BalanceSummary copyWith({
    String? groupId,
    Map<String, int>? netBalances,
    List<DebtEntry>? debts,
    List<DebtEntry>? simplifiedDebts,
    int? totalExpensesCents,
    int? totalSettlementsCents,
    DateTime? calculatedAt,
  }) {
    return BalanceSummary(
      groupId: groupId ?? this.groupId,
      netBalances: netBalances ?? this.netBalances,
      debts: debts ?? this.debts,
      simplifiedDebts: simplifiedDebts ?? this.simplifiedDebts,
      totalExpensesCents: totalExpensesCents ?? this.totalExpensesCents,
      totalSettlementsCents:
          totalSettlementsCents ?? this.totalSettlementsCents,
      calculatedAt: calculatedAt ?? this.calculatedAt,
    );
  }

  @override
  List<Object?> get props => [
        groupId,
        netBalances,
        debts,
        simplifiedDebts,
        totalExpensesCents,
        totalSettlementsCents,
        calculatedAt,
      ];
}

