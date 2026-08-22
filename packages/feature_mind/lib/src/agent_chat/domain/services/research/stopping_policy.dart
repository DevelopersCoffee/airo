class ResearchProgress {
  const ResearchProgress({
    required this.searchesUsed,
    required this.maxSearches,
    required this.sources,
    required this.uncoveredNodes,
    required this.iterationsUsed,
    required this.maxIterations,
  });

  final int searchesUsed;
  final int maxSearches;
  final int sources;
  final int uncoveredNodes;
  final int iterationsUsed;
  final int maxIterations;
}

enum StopDecision { continueWork, stopCoverage, stopBudget, stopIterations }

abstract class StoppingPolicy {
  StopDecision shouldStop(ResearchProgress progress);
}

/// Budget is a ceiling. Coverage is why we stop early.
class EvidenceSufficiencyPolicy implements StoppingPolicy {
  const EvidenceSufficiencyPolicy();

  @override
  StopDecision shouldStop(ResearchProgress progress) {
    if (progress.uncoveredNodes == 0 && progress.sources > 0) {
      return StopDecision.stopCoverage;
    }
    if (progress.searchesUsed >= progress.maxSearches) {
      return StopDecision.stopBudget;
    }
    if (progress.iterationsUsed >= progress.maxIterations &&
        progress.sources > 0) {
      return StopDecision.stopIterations;
    }
    return StopDecision.continueWork;
  }
}
