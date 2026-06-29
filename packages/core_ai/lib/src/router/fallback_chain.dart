import '../provider/ai_provider.dart';

/// Ordered fallback providers for a routing attempt.
class FallbackChain {
  FallbackChain(List<AIProvider> providers) : chain = _dedupe(providers);

  final List<AIProvider> chain;

  List<AIProvider> alternativesFor(AIProvider current) {
    return [
      for (final provider in chain)
        if (provider != current) provider,
    ];
  }

  static List<AIProvider> _dedupe(List<AIProvider> providers) {
    final seen = <AIProvider>{};
    final ordered = <AIProvider>[];
    for (final provider in providers) {
      if (seen.add(provider)) {
        ordered.add(provider);
      }
    }
    return ordered;
  }
}
