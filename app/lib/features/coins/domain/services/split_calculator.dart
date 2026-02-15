import '../entities/split_entry.dart';

/// Split calculation service interface
///
/// Handles different split type calculations (equal, percentage, shares, etc.)
///
/// Phase: 2 (Split Engine)
/// See: docs/features/coins/ENGINEERING_TICKETS_PHASE_2.md (COINS-022)
abstract class SplitCalculator {
  /// Calculate equal split among participants
  ///
  /// Handles remainder distribution (e.g., ₹100 / 3 = ₹33.33 + remainder)
  List<SplitEntry> calculateEqualSplit({
    required String sharedExpenseId,
    required int totalAmountCents,
    required List<String> participantIds,
  });

  /// Calculate percentage-based split
  ///
  /// Percentages must sum to 100.0
  List<SplitEntry> calculatePercentageSplit({
    required String sharedExpenseId,
    required int totalAmountCents,
    required Map<String, double> percentages, // userId -> percentage
  });

  /// Calculate exact amount split
  ///
  /// Amounts must sum to totalAmountCents
  List<SplitEntry> calculateExactSplit({
    required String sharedExpenseId,
    required int totalAmountCents,
    required Map<String, int> amounts, // userId -> amountCents
  });

  /// Calculate shares-based split
  ///
  /// Each participant has N shares (e.g., 2x for double portion)
  List<SplitEntry> calculateSharesSplit({
    required String sharedExpenseId,
    required int totalAmountCents,
    required Map<String, int> shares, // userId -> number of shares
  });

  /// Validate that split amounts sum to total
  bool validateSplit(int totalAmountCents, List<SplitEntry> splits);
}

/// Default implementation of SplitCalculator
class SplitCalculatorImpl implements SplitCalculator {
  @override
  List<SplitEntry> calculateEqualSplit({
    required String sharedExpenseId,
    required int totalAmountCents,
    required List<String> participantIds,
  }) {
    if (participantIds.isEmpty) return [];

    final count = participantIds.length;
    final baseAmount = totalAmountCents ~/ count;
    final remainder = totalAmountCents % count;

    final now = DateTime.now();
    final splits = <SplitEntry>[];

    for (var i = 0; i < participantIds.length; i++) {
      // First N people get +1 cent to handle remainder
      final extra = i < remainder ? 1 : 0;
      splits.add(SplitEntry(
        id: '${sharedExpenseId}_split_$i',
        sharedExpenseId: sharedExpenseId,
        userId: participantIds[i],
        amountCents: baseAmount + extra,
        createdAt: now,
      ));
    }

    return splits;
  }

  @override
  List<SplitEntry> calculatePercentageSplit({
    required String sharedExpenseId,
    required int totalAmountCents,
    required Map<String, double> percentages,
  }) {
    // TODO: Implement percentage split
    // Validate percentages sum to 100
    // Handle rounding to ensure amounts sum to total
    throw UnimplementedError('calculatePercentageSplit not implemented');
  }

  @override
  List<SplitEntry> calculateExactSplit({
    required String sharedExpenseId,
    required int totalAmountCents,
    required Map<String, int> amounts,
  }) {
    // TODO: Implement exact split
    // Validate amounts sum to totalAmountCents
    throw UnimplementedError('calculateExactSplit not implemented');
  }

  @override
  List<SplitEntry> calculateSharesSplit({
    required String sharedExpenseId,
    required int totalAmountCents,
    required Map<String, int> shares,
  }) {
    // TODO: Implement shares split
    // Calculate total shares, then divide proportionally
    throw UnimplementedError('calculateSharesSplit not implemented');
  }

  @override
  bool validateSplit(int totalAmountCents, List<SplitEntry> splits) {
    final sum = splits.fold<int>(0, (sum, s) => sum + s.amountCents);
    return sum == totalAmountCents;
  }
}

