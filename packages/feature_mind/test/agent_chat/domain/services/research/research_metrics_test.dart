import 'package:feature_mind/src/agent_chat/domain/models/research_request.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_metrics.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/stopping_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cost is deterministic abstract micros, not invented USD', () {
    const model = ResearchCostModel();
    expect(
      model.estimate(searches: 2, fetches: 3, tokens: 10),
      2000 + 1500 + 10,
    );
    expect(model.estimate(searches: 0, fetches: 0, tokens: 0), 0);
  });

  test('metrics markdown names every locked counter', () {
    const metrics = ResearchMetrics(
      duration: Duration(milliseconds: 1200),
      searches: 4,
      sourcesUsed: 3,
      sourcesRejected: 1,
      claims: 6,
      contradictions: 2,
      tokens: 40,
    );
    final text = metrics.withCost(const ResearchCostModel()).markdown();
    expect(text, contains('## Observability'));
    expect(text, contains('Duration: 1200 ms'));
    expect(text, contains('Searches: 4'));
    expect(text, contains('Sources used: 3'));
    expect(text, contains('Sources rejected: 1'));
    expect(text, contains('Claims: 6'));
    expect(text, contains('Contradictions: 2'));
    expect(text, contains('Tokens: 40'));
    expect(text, contains('Cost: 5540 µ'));
  });

  test('deep budget includes a cost ceiling', () {
    final budget = ResearchBudget.forMode(ResearchMode.deep);
    expect(budget.maxCostMicros, greaterThan(0));
    expect(
      budget.maxCostMicros,
      greaterThan(ResearchBudget.forMode(ResearchMode.quick).maxCostMicros),
    );
  });

  test(
    'stopping honors a spent cost ceiling without treating search count as done',
    () {
      const policy = EvidenceSufficiencyPolicy();
      expect(
        policy.shouldStop(
          const ResearchProgress(
            searchesUsed: 2,
            maxSearches: 40,
            sources: 1,
            uncoveredNodes: 3,
            iterationsUsed: 1,
            maxIterations: 8,
            costUsed: 150_000,
            maxCost: 150_000,
          ),
        ),
        StopDecision.stopBudget,
      );
      expect(
        policy.shouldStop(
          const ResearchProgress(
            searchesUsed: 10,
            maxSearches: 40,
            sources: 0,
            uncoveredNodes: 3,
            iterationsUsed: 1,
            maxIterations: 8,
          ),
        ),
        StopDecision.continueWork,
      );
    },
  );
}
