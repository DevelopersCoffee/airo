import 'package:equatable/equatable.dart';

/// A category verdict for a merchant/transaction description, paired with
/// its budget grouping. Shared value type between [RegexMerchantCategorizer]
/// (the keyword baseline) and [MerchantCategorizer] (the kNN-first
/// classifier it's benchmarked against).
class MerchantCategory extends Equatable {
  final String categoryId;
  final String budgetTag;

  const MerchantCategory(this.categoryId, this.budgetTag);

  @override
  List<Object?> get props => [categoryId, budgetTag];
}
