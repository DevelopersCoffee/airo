import '../models/merchant_category.dart';

/// Keyword-based category baseline. Extracted from [QuickAddExpenseParser]
/// so [MerchantCategorizer] (COINS-AI-5) has a real, shared baseline to beat
/// rather than a private copy that could drift out of sync -- per #941's
/// acceptance criteria, the embeddings-first path must be benchmarked
/// against this classifier, not against a reimplementation of it.
///
/// This is also the low-tier/no-model fallback: on a device that can't run
/// on-device embeddings, this is what runs instead.
class RegexMerchantCategorizer {
  const RegexMerchantCategorizer();

  MerchantCategory categorize(String text) {
    final lower = text.toLowerCase();
    if (_containsAny(lower, [
      'uber',
      'ola',
      'cab',
      'taxi',
      'metro',
      'flight',
    ])) {
      return const MerchantCategory('transport', 'Travel');
    }
    if (_containsAny(lower, [
      'netflix',
      'spotify',
      'movie',
      'cinema',
      'game',
    ])) {
      return const MerchantCategory('shopping', 'Entertainment');
    }
    if (_containsAny(lower, ['salary', 'bonus', 'income'])) {
      return const MerchantCategory('salary', 'Income');
    }
    if (_containsAny(lower, [
      'pizza',
      'dinner',
      'lunch',
      'coffee',
      'food',
      'restaurant',
      'swiggy',
      'zomato',
    ])) {
      return const MerchantCategory('food', 'Food');
    }
    return const MerchantCategory('shopping', 'Shopping');
  }

  bool _containsAny(String text, List<String> needles) {
    return needles.any(text.contains);
  }
}
