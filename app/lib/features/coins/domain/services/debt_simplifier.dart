import '../models/debt_entry.dart';

/// Debt simplification service interface
///
/// Reduces the number of transactions needed to settle all debts.
/// Uses a greedy algorithm to minimize total number of payments.
///
/// Phase: 2 (Split Engine)
/// See: docs/features/coins/ENGINEERING_TICKETS_PHASE_2.md (COINS-026)
abstract class DebtSimplifier {
  /// Simplify a list of debts to minimize transactions
  ///
  /// Example:
  /// Input: A owes B ₹100, B owes C ₹100
  /// Output: A owes C ₹100 (direct payment, skipping B)
  List<DebtEntry> simplify(List<DebtEntry> debts);

  /// Convert net balances to simplified debts
  ///
  /// Takes a map of userId -> net balance and returns minimum transactions
  List<DebtEntry> fromNetBalances(
    Map<String, int> balances, {
    String currencyCode = 'INR',
  });
}

/// Default implementation using greedy algorithm
class DebtSimplifierImpl implements DebtSimplifier {
  @override
  List<DebtEntry> simplify(List<DebtEntry> debts) {
    // Calculate net balances from debts
    final balances = <String, int>{};
    for (final debt in debts) {
      balances[debt.fromUserId] =
          (balances[debt.fromUserId] ?? 0) - debt.amountCents;
      balances[debt.toUserId] =
          (balances[debt.toUserId] ?? 0) + debt.amountCents;
    }

    return fromNetBalances(balances);
  }

  @override
  List<DebtEntry> fromNetBalances(
    Map<String, int> balances, {
    String currencyCode = 'INR',
  }) {
    // Separate debtors (negative balance) and creditors (positive balance)
    final debtors = <MapEntry<String, int>>[];
    final creditors = <MapEntry<String, int>>[];

    for (final entry in balances.entries) {
      if (entry.value < 0) {
        debtors.add(MapEntry(entry.key, -entry.value)); // Convert to positive
      } else if (entry.value > 0) {
        creditors.add(entry);
      }
    }

    // Sort by amount (largest first for greedy matching)
    debtors.sort((a, b) => b.value.compareTo(a.value));
    creditors.sort((a, b) => b.value.compareTo(a.value));

    final result = <DebtEntry>[];
    var debtorIdx = 0;
    var creditorIdx = 0;

    // Mutable copies for tracking remaining amounts
    final debtorAmounts = debtors.map((e) => e.value).toList();
    final creditorAmounts = creditors.map((e) => e.value).toList();

    while (debtorIdx < debtors.length && creditorIdx < creditors.length) {
      final debtorId = debtors[debtorIdx].key;
      final creditorId = creditors[creditorIdx].key;
      final debtorOwes = debtorAmounts[debtorIdx];
      final creditorOwed = creditorAmounts[creditorIdx];

      // Transfer minimum of what debtor owes and creditor is owed
      final transferAmount =
          debtorOwes < creditorOwed ? debtorOwes : creditorOwed;

      if (transferAmount > 0) {
        result.add(DebtEntry(
          fromUserId: debtorId,
          toUserId: creditorId,
          amountCents: transferAmount,
          currencyCode: currencyCode,
        ));

        debtorAmounts[debtorIdx] -= transferAmount;
        creditorAmounts[creditorIdx] -= transferAmount;
      }

      // Move to next debtor/creditor if fully settled
      if (debtorAmounts[debtorIdx] == 0) debtorIdx++;
      if (creditorAmounts[creditorIdx] == 0) creditorIdx++;
    }

    return result;
  }
}

