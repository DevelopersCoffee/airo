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
      splits.add(
        SplitEntry(
          id: '${sharedExpenseId}_split_$i',
          sharedExpenseId: sharedExpenseId,
          userId: participantIds[i],
          amountCents: baseAmount + extra,
          createdAt: now,
        ),
      );
    }

    return splits;
  }

  @override
  List<SplitEntry> calculatePercentageSplit({
    required String sharedExpenseId,
    required int totalAmountCents,
    required Map<String, double> percentages,
  }) {
    if (percentages.isEmpty) return [];

    // Validate percentages sum to ~100 (allow small floating point error)
    final percentageSum = percentages.values.fold<double>(
      0,
      (sum, p) => sum + p,
    );
    if ((percentageSum - 100.0).abs() > 0.01) {
      throw ArgumentError('Percentages must sum to 100, got $percentageSum');
    }

    final now = DateTime.now();
    final splits = <SplitEntry>[];
    var allocatedCents = 0;
    final entries = percentages.entries.toList();

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final isLast = i == entries.length - 1;

      // Calculate amount, giving remainder to last person
      final calculatedAmount = (totalAmountCents * entry.value / 100).round();
      final amountCents = isLast
          ? totalAmountCents - allocatedCents
          : calculatedAmount;

      allocatedCents += amountCents;

      splits.add(
        SplitEntry(
          id: '${sharedExpenseId}_split_$i',
          sharedExpenseId: sharedExpenseId,
          userId: entry.key,
          amountCents: amountCents,
          createdAt: now,
        ),
      );
    }

    return splits;
  }

  @override
  List<SplitEntry> calculateExactSplit({
    required String sharedExpenseId,
    required int totalAmountCents,
    required Map<String, int> amounts,
  }) {
    if (amounts.isEmpty) return [];

    // Validate amounts sum to totalAmountCents
    final amountSum = amounts.values.fold<int>(0, (sum, a) => sum + a);
    if (amountSum != totalAmountCents) {
      throw ArgumentError(
        'Amounts must sum to $totalAmountCents, got $amountSum',
      );
    }

    final now = DateTime.now();
    final splits = <SplitEntry>[];
    var i = 0;

    for (final entry in amounts.entries) {
      splits.add(
        SplitEntry(
          id: '${sharedExpenseId}_split_$i',
          sharedExpenseId: sharedExpenseId,
          userId: entry.key,
          amountCents: entry.value,
          createdAt: now,
        ),
      );
      i++;
    }

    return splits;
  }

  @override
  List<SplitEntry> calculateSharesSplit({
    required String sharedExpenseId,
    required int totalAmountCents,
    required Map<String, int> shares,
  }) {
    if (shares.isEmpty) return [];

    // Validate no negative shares
    if (shares.values.any((s) => s < 0)) {
      throw ArgumentError('Shares cannot be negative');
    }

    final totalShares = shares.values.fold<int>(0, (sum, s) => sum + s);
    if (totalShares == 0) return [];

    final now = DateTime.now();
    final splits = <SplitEntry>[];
    var allocatedCents = 0;
    final entries = shares.entries.toList();

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final isLast = i == entries.length - 1;

      // Calculate proportional amount, giving remainder to last person
      final calculatedAmount = (totalAmountCents * entry.value / totalShares)
          .floor();
      final amountCents = isLast
          ? totalAmountCents - allocatedCents
          : calculatedAmount;

      allocatedCents += amountCents;

      splits.add(
        SplitEntry(
          id: '${sharedExpenseId}_split_$i',
          sharedExpenseId: sharedExpenseId,
          userId: entry.key,
          amountCents: amountCents,
          createdAt: now,
        ),
      );
    }

    return splits;
  }

  @override
  bool validateSplit(int totalAmountCents, List<SplitEntry> splits) {
    final sum = splits.fold<int>(0, (sum, s) => sum + s.amountCents);
    return sum == totalAmountCents;
  }
}
