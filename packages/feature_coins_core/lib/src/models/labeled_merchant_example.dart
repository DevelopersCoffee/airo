import 'package:equatable/equatable.dart';

import 'merchant_category.dart';

/// One user-confirmed (or fallback-confirmed) merchant->category decision,
/// with its embedding precomputed once at correction time. [knn] never
/// re-embeds an example -- embedding is meant to run as a batch job off the
/// main isolate (COINS-AI-5 acceptance criterion), not per classification.
class LabeledMerchantExample extends Equatable {
  final String merchantText;
  final List<double> embedding;
  final MerchantCategory category;

  const LabeledMerchantExample({
    required this.merchantText,
    required this.embedding,
    required this.category,
  });

  @override
  List<Object?> get props => [merchantText, embedding, category];
}
