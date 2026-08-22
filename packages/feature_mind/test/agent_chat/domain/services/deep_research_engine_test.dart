import 'package:feature_mind/src/agent_chat/domain/models/research_event.dart';
import 'package:feature_mind/src/agent_chat/domain/models/research_request.dart';
import 'package:feature_mind/src/agent_chat/domain/services/deep_research_engine.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_orchestrator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deep mode is a budget, not a hardcoded search count', () {
    const request = ResearchRequest(question: 'Compare Qwen, Llama and Gemma');
    expect(request.mode, ResearchMode.deep);
    expect(request.budget.maxSearches, 40);
    expect(request.budget.maxIterations, 8);
    expect(
      ResearchBudget.forMode(ResearchMode.quick).maxSearches,
      lessThan(request.budget.maxSearches),
    );
  });

  test('empty questions fail instead of inventing a report', () async {
    final events = await LocalDeepResearchEngine(
      orchestrator: const ResearchOrchestrator(engines: []),
    ).run(const ResearchRequest(question: '   ')).toList();
    expect(events.single.kind, ResearchEventKind.researchFailed);
  });
}
