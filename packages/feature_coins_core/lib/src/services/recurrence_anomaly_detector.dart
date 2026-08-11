import '../entities/transaction.dart';
import '../models/detected_subscription.dart';
import '../models/recurrence_cycle.dart';
import '../models/spending_anomaly.dart';

/// One billing cadence the detector knows how to recognize, expressed as a
/// tolerance band on the gap (in days) between consecutive charges.
class _CycleBand {
  const _CycleBand(this.cycle, this.minDays, this.maxDays);

  final RecurrenceCycle cycle;
  final int minDays;
  final int maxDays;
}

/// Deterministic subscription and spending-anomaly detection over raw
/// transaction history. No model, no network, no arithmetic performed by an
/// LLM anywhere in this file -- per COINS-AI's non-negotiable architecture
/// rule, this is the code that computes; any narration layer only fills
/// phrasing slots around numbers this class already produced.
///
/// Two independent signals:
/// - [detectSubscriptions]: same merchant, charges land on a consistent
///   cycle, amount is stable (allowing at most one deliberate price change).
/// - [detectAnomalies]: a detected subscription's price moved, or a brand
///   new merchant charged far more than the user's typical transaction.
class RecurrenceAnomalyDetector {
  const RecurrenceAnomalyDetector({
    this.minOccurrences = 3,
    this.stableAmountToleranceRatio = 0.03,
    this.priceChangeMinRatio = 0.03,
    this.priceChangeMaxRatio = 0.5,
    this.newMerchantSpikeMultiplier = 3.0,
    this.minTransactionsForSpikeBaseline = 5,
  });

  /// Fewer occurrences than this can't distinguish a real cycle from
  /// coincidence -- two dates always technically form "an interval".
  final int minOccurrences;

  /// Consecutive amounts within this fraction of each other count as the
  /// same stable price.
  final double stableAmountToleranceRatio;

  /// A single jump inside this range is treated as a deliberate price
  /// change, not noise -- the subscription survives it.
  final double priceChangeMinRatio;
  final double priceChangeMaxRatio;

  /// A first-time merchant charging at least this many times the typical
  /// transaction size is flagged as a spike.
  final double newMerchantSpikeMultiplier;

  /// Below this many total expense transactions, there isn't enough
  /// history to establish a meaningful "typical transaction size".
  final int minTransactionsForSpikeBaseline;

  static const _bands = [
    _CycleBand(RecurrenceCycle.weekly, 5, 9),
    _CycleBand(RecurrenceCycle.monthly, 25, 35),
    _CycleBand(RecurrenceCycle.quarterly, 81, 101),
    _CycleBand(RecurrenceCycle.yearly, 350, 380),
  ];

  String _merchantKey(Transaction t) => t.description.trim().toLowerCase();

  List<Transaction> _activeExpenses(List<Transaction> transactions) {
    return transactions
        .where((t) => t.type == TransactionType.expense && !t.isDeleted)
        .toList();
  }

  Map<String, List<Transaction>> _groupByMerchant(List<Transaction> txs) {
    final groups = <String, List<Transaction>>{};
    for (final t in txs) {
      groups.putIfAbsent(_merchantKey(t), () => []).add(t);
    }
    for (final group in groups.values) {
      group.sort((a, b) => a.transactionDate.compareTo(b.transactionDate));
    }
    return groups;
  }

  RecurrenceCycle? _consistentCycle(List<Transaction> occurrences) {
    final gaps = <int>[];
    for (var i = 1; i < occurrences.length; i++) {
      gaps.add(
        occurrences[i].transactionDate
            .difference(occurrences[i - 1].transactionDate)
            .inDays,
      );
    }
    for (final band in _bands) {
      final allMatch = gaps.every(
        (g) => g >= band.minDays && g <= band.maxDays,
      );
      if (allMatch) return band.cycle;
    }
    return null;
  }

  /// True if [amounts] holds steady, with at most one deliberate jump
  /// (a price change). Wildly varying amounts (a weekly grocery run) or
  /// more than one jump fail this check.
  bool _amountsFormStablePattern(List<int> amounts) {
    var sawJump = false;
    for (var i = 1; i < amounts.length; i++) {
      final prev = amounts[i - 1];
      final curr = amounts[i];
      if (prev <= 0) return false;
      final ratio = (curr - prev).abs() / prev;
      if (ratio <= stableAmountToleranceRatio) continue;
      if (ratio >= priceChangeMinRatio &&
          ratio <= priceChangeMaxRatio &&
          !sawJump) {
        sawJump = true;
        continue;
      }
      return false;
    }
    return true;
  }

  double _confidence(int occurrenceCount) {
    const fullConfidenceAt = 6;
    final clamped = occurrenceCount.clamp(minOccurrences, fullConfidenceAt);
    return clamped / fullConfidenceAt;
  }

  List<DetectedSubscription> detectSubscriptions(List<Transaction> transactions) {
    final groups = _groupByMerchant(_activeExpenses(transactions));
    final results = <DetectedSubscription>[];

    for (final entry in groups.entries) {
      final occurrences = entry.value;
      if (occurrences.length < minOccurrences) continue;

      final cycle = _consistentCycle(occurrences);
      if (cycle == null) continue;

      final amounts = occurrences.map((t) => t.amountCents).toList();
      if (!_amountsFormStablePattern(amounts)) continue;

      results.add(
        DetectedSubscription(
          merchantKey: entry.key,
          merchantLabel: occurrences.last.description,
          cycle: cycle,
          currentAmountCents: occurrences.last.amountCents,
          occurrences: occurrences,
          confidence: _confidence(occurrences.length),
        ),
      );
    }
    return results;
  }

  List<SpendingAnomaly> _priceChangeAnomalies(List<Transaction> transactions) {
    final anomalies = <SpendingAnomaly>[];
    for (final subscription in detectSubscriptions(transactions)) {
      final occurrences = subscription.occurrences;
      for (var i = 1; i < occurrences.length; i++) {
        final prev = occurrences[i - 1].amountCents;
        final curr = occurrences[i].amountCents;
        if (prev <= 0) continue;
        final ratio = (curr - prev).abs() / prev;
        if (ratio < priceChangeMinRatio || ratio > priceChangeMaxRatio) {
          continue;
        }
        anomalies.add(
          SpendingAnomaly(
            type: curr > prev
                ? SpendingAnomalyType.priceIncrease
                : SpendingAnomalyType.priceDecrease,
            transaction: occurrences[i],
            previousAmountCents: prev,
            deltaCents: curr - prev,
            deltaPercent: ((curr - prev) / prev) * 100,
          ),
        );
      }
    }
    return anomalies;
  }

  int _median(List<int> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return ((sorted[mid - 1] + sorted[mid]) / 2).round();
  }

  List<SpendingAnomaly> _newMerchantSpikeAnomalies(
    List<Transaction> transactions,
  ) {
    final expenses = _activeExpenses(transactions);
    if (expenses.length < minTransactionsForSpikeBaseline) return [];

    final baseline = _median(expenses.map((t) => t.amountCents).toList());
    if (baseline <= 0) return [];

    final groups = _groupByMerchant(expenses);
    final anomalies = <SpendingAnomaly>[];
    for (final occurrences in groups.values) {
      if (occurrences.length != 1) continue;
      final tx = occurrences.single;
      if (tx.amountCents < baseline * newMerchantSpikeMultiplier) continue;
      anomalies.add(
        SpendingAnomaly(
          type: SpendingAnomalyType.newMerchantSpike,
          transaction: tx,
          previousAmountCents: null,
          deltaCents: tx.amountCents - baseline,
          deltaPercent: ((tx.amountCents - baseline) / baseline) * 100,
        ),
      );
    }
    return anomalies;
  }

  List<SpendingAnomaly> detectAnomalies(List<Transaction> transactions) {
    return [
      ..._priceChangeAnomalies(transactions),
      ..._newMerchantSpikeAnomalies(transactions),
    ];
  }
}
