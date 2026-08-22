import 'package:feature_mind/src/agent_chat/domain/models/research_request.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/query_generator.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_interpreter.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/stopping_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compare vs best-for vs what-is select different intents', () {
    const interpreter = ResearchInterpreter();
    expect(
      interpreter
          .interpret(
            const ResearchRequest(question: 'Compare Qwen, Llama and Gemma'),
          )
          .intent,
      ResearchIntent.comparison,
    );
    expect(
      interpreter
          .interpret(
            const ResearchRequest(
              question: 'Research the best LLM for Airo Mind.',
            ),
          )
          .intent,
      ResearchIntent.decisionSupport,
    );
    expect(
      interpreter
          .interpret(const ResearchRequest(question: 'What is Qwen?'))
          .intent,
      ResearchIntent.factFinding,
    );
    expect(
      ResearchInterpreter.classify('Research Rust FFI for Flutter'),
      ResearchIntent.technicalResearch,
    );
  });

  test('stopping does not treat a search count as done', () {
    const policy = EvidenceSufficiencyPolicy();
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
    expect(
      policy.shouldStop(
        const ResearchProgress(
          searchesUsed: 4,
          maxSearches: 40,
          sources: 3,
          uncoveredNodes: 0,
          iterationsUsed: 1,
          maxIterations: 8,
        ),
      ),
      StopDecision.stopCoverage,
    );
  });

  test('query generation always includes a disconfirming search', () {
    final set = const QueryGenerator().queriesFor(
      'Is Qwen3 good for mobile inference?',
    );
    expect(set.counterargument.toLowerCase(), contains('limitations'));
    expect(set.alternatives, anyElement(contains('benchmark')));
  });
}
