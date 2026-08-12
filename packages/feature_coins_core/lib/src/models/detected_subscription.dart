import 'package:equatable/equatable.dart';

import '../entities/transaction.dart';
import 'recurrence_cycle.dart';

/// A recurring-charge candidate inferred by [RecurrenceAnomalyDetector] from
/// raw transaction history — not yet a user-confirmed [Subscription] record.
///
/// Deliberately carries no narration or copy: any human-readable digest
/// sentence is built from this data by a separate layer (COINS-AI-1's
/// grammar-constrained narration), never invented here.
class DetectedSubscription extends Equatable {
  /// Normalized grouping key (`description.trim().toLowerCase()`).
  final String merchantKey;

  /// Most recent transaction's original-case description, for display.
  final String merchantLabel;

  final RecurrenceCycle cycle;

  /// The latest stable amount, in the smallest currency unit.
  final int currentAmountCents;

  /// All transactions that make up this candidate, oldest first.
  final List<Transaction> occurrences;

  /// Heuristic confidence in `[0.5, 1.0]` — more occurrences, more
  /// confidence. Not a probability; a ranking signal only.
  final double confidence;

  const DetectedSubscription({
    required this.merchantKey,
    required this.merchantLabel,
    required this.cycle,
    required this.currentAmountCents,
    required this.occurrences,
    required this.confidence,
  });

  Transaction get latestOccurrence => occurrences.last;

  @override
  List<Object?> get props => [
    merchantKey,
    merchantLabel,
    cycle,
    currentAmountCents,
    occurrences,
    confidence,
  ];
}
