import 'package:equatable/equatable.dart';

import '../entities/transaction.dart';

/// What kind of deviation [RecurrenceAnomalyDetector.detectAnomalies] found.
enum SpendingAnomalyType {
  /// A detected subscription's amount rose between consecutive charges.
  priceIncrease,

  /// A detected subscription's amount fell between consecutive charges.
  priceDecrease,

  /// A merchant seen for the first time, priced well above the user's
  /// typical transaction.
  newMerchantSpike,
}

/// One deviation flagged by the detector. Descriptive only — every field is
/// a number or a reference to a real [Transaction]; nothing here is
/// prescriptive copy. Any narration ("your Netflix went up ₹100") is built
/// from these fields by a separate template/LLM layer, never invented here.
class SpendingAnomaly extends Equatable {
  final SpendingAnomalyType type;

  /// The transaction that triggered the anomaly.
  final Transaction transaction;

  /// Null for [SpendingAnomalyType.newMerchantSpike], which has no prior
  /// occurrence to compare against.
  final int? previousAmountCents;

  /// `transaction.amountCents - (previousAmountCents ?? baselineCents)`.
  final int deltaCents;

  /// Signed percentage change relative to the comparison baseline.
  final double deltaPercent;

  const SpendingAnomaly({
    required this.type,
    required this.transaction,
    required this.previousAmountCents,
    required this.deltaCents,
    required this.deltaPercent,
  });

  @override
  List<Object?> get props => [
    type,
    transaction,
    previousAmountCents,
    deltaCents,
    deltaPercent,
  ];
}
