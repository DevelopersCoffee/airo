import '../models/merchant_category.dart';
import 'merchant_key.dart';

/// Per-merchant category verdicts, once decided by a user correction or a
/// cold-start fallback. The consistency invariant COINS-AI-5 requires
/// ("same merchant → same category always") lives here: [lookup] is the
/// only read path [MerchantCategorizer] uses once a merchant has an entry,
/// so a later kNN or fallback call can never silently override it.
///
/// In-memory only. Persistence (surviving app restarts) is app-layer
/// wiring, out of scope for this pure-Dart package.
class MerchantCategorizationCache {
  final Map<String, MerchantCategory> _decisions = {};

  MerchantCategory? lookup(String merchantText) =>
      _decisions[normalizeMerchantKey(merchantText)];

  /// Records a verdict for a merchant. Called both for explicit user
  /// corrections and for a cold-start fallback's first decision -- either
  /// way, this merchant now always resolves to [category].
  void record(String merchantText, MerchantCategory category) {
    _decisions[normalizeMerchantKey(merchantText)] = category;
  }

  bool contains(String merchantText) =>
      _decisions.containsKey(normalizeMerchantKey(merchantText));
}
