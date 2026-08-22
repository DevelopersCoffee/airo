import 'package:feature_mind/src/agent_chat/domain/models/research_request.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compare questions fan out per subject with depth facets', () {
    const request = ResearchRequest(
      question: 'Compare Qwen, Llama and Gemma for offline mobile AI in 2026.',
    );

    final plan = ResearchPlanner().plan(request);

    expect(plan.rootQuestion, contains('Qwen'));
    expect(
      plan.nodes.map((node) => node.question),
      anyElement(contains('Qwen')),
    );
    expect(
      plan.nodes.map((node) => node.question),
      anyElement(contains('Llama')),
    );
    expect(
      plan.nodes.map((node) => node.question),
      anyElement(contains('Gemma')),
    );
    expect(plan.strategyId, 'comparison');
    expect(
      plan.nodes.any(
        (node) =>
            node.kind == PlanNodeKind.depth &&
            node.question.toLowerCase().contains('licensing'),
      ),
      isTrue,
    );
    expect(plan.nodes.length, greaterThan(3));
    expect(plan.nodes.length, lessThanOrEqualTo(16));
  });

  test('quick mode stays a shallow breadth pass', () {
    const request = ResearchRequest(
      question: 'Compare Qwen, Llama and Gemma',
      mode: ResearchMode.quick,
    );

    final plan = ResearchPlanner().plan(request);

    expect(plan.nodes.length, lessThanOrEqualTo(3));
    expect(
      plan.nodes.every((node) => node.kind == PlanNodeKind.breadth),
      isTrue,
    );
  });
}
