/// Abstract micro-units. Wikipedia has no USD price; the UI can format this.
class ResearchCostModel {
  const ResearchCostModel({
    this.microsPerSearch = 1000,
    this.microsPerFetch = 500,
    this.microsPerToken = 1,
  });

  final int microsPerSearch;
  final int microsPerFetch;
  final int microsPerToken;

  int estimate({
    required int searches,
    required int fetches,
    required int tokens,
  }) {
    return microsPerSearch * searches +
        microsPerFetch * fetches +
        microsPerToken * tokens;
  }
}

/// Job counters the UI may show. Not chain-of-thought.
class ResearchMetrics {
  const ResearchMetrics({
    this.duration = Duration.zero,
    this.searches = 0,
    this.sourcesUsed = 0,
    this.sourcesRejected = 0,
    this.claims = 0,
    this.contradictions = 0,
    this.tokens = 0,
    this.costMicros = 0,
  });

  final Duration duration;
  final int searches;
  final int sourcesUsed;
  final int sourcesRejected;
  final int claims;
  final int contradictions;
  final int tokens;
  final int costMicros;

  ResearchMetrics withCost(ResearchCostModel model) {
    return ResearchMetrics(
      duration: duration,
      searches: searches,
      sourcesUsed: sourcesUsed,
      sourcesRejected: sourcesRejected,
      claims: claims,
      contradictions: contradictions,
      tokens: tokens,
      costMicros: model.estimate(
        searches: searches,
        fetches: sourcesUsed,
        tokens: tokens,
      ),
    );
  }

  String markdown() {
    return [
      '## Observability',
      '',
      'Duration: ${duration.inMilliseconds} ms',
      'Searches: $searches',
      'Sources used: $sourcesUsed',
      'Sources rejected: $sourcesRejected',
      'Claims: $claims',
      'Contradictions: $contradictions',
      'Tokens: $tokens',
      'Cost: $costMicros µ',
    ].join('\n');
  }
}
