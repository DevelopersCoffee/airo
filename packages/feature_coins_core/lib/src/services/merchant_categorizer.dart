import '../models/labeled_merchant_example.dart';
import '../models/merchant_category.dart';
import 'embedding_knn_categorizer.dart';
import 'merchant_categorization_cache.dart';
import 'merchant_embedder.dart';
import 'regex_merchant_categorizer.dart';

/// Auto-categorization orchestrator (COINS-AI-5). Order of resolution:
///
/// 1. [MerchantCategorizationCache] -- if this merchant has ever been
///    decided before, that decision stands. This is the consistency
///    invariant: the same merchant always resolves to the same category.
/// 2. [EmbeddingKnnCategorizer] over accumulated corrections -- the
///    embeddings-first path research favored over prompting an LLM per
///    transaction.
/// 3. [RegexMerchantCategorizer] -- the no-model baseline/fallback.
///
/// LLM cold-start fallback (for unseen/abbreviated/multilingual merchants
/// the kNN path can't place) is COINS-AI-1-gated and deliberately not
/// wired here -- when it lands, it plugs in as an additional step between
/// 2 and 3, and its decision gets cached exactly like any other via
/// [recordCorrection].
class MerchantCategorizer {
  MerchantCategorizer({
    required this.embedder,
    MerchantCategorizationCache? cache,
    this.fallback = const RegexMerchantCategorizer(),
    this.knn = const EmbeddingKnnCategorizer(),
  }) : cache = cache ?? MerchantCategorizationCache();

  final MerchantEmbedder embedder;
  final MerchantCategorizationCache cache;
  final RegexMerchantCategorizer fallback;
  final EmbeddingKnnCategorizer knn;

  final List<LabeledMerchantExample> _examples = [];

  MerchantCategory categorize(String merchantText) {
    final cached = cache.lookup(merchantText);
    if (cached != null) return cached;

    final decision = _decide(merchantText);
    cache.record(merchantText, decision);
    return decision;
  }

  MerchantCategory _decide(String merchantText) {
    final queryEmbedding = embedder.embed(merchantText);
    final knnResult = knn.classify(queryEmbedding, _examples);
    return knnResult ?? fallback.categorize(merchantText);
  }

  /// A user (or, once wired, an LLM cold-start fallback) confirms this
  /// merchant's category. Overwrites any prior cached decision and adds a
  /// training example the kNN path uses for *other* merchants going
  /// forward -- this merchant itself now always resolves from the cache,
  /// never re-embedded or re-voted on.
  void recordCorrection(String merchantText, MerchantCategory category) {
    cache.record(merchantText, category);
    _examples.add(
      LabeledMerchantExample(
        merchantText: merchantText,
        embedding: embedder.embed(merchantText),
        category: category,
      ),
    );
  }
}
