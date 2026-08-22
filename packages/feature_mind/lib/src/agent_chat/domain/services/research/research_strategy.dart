import '../../models/research_request.dart';
import 'research_interpreter.dart';
import 'research_planner.dart';

abstract class ResearchStrategy {
  String get id;

  ResearchPlan createPlan(ResearchRequest request, InterpretedGoal goal);
}

ResearchStrategy strategyFor(ResearchIntent intent) {
  switch (intent) {
    case ResearchIntent.comparison:
      return const ComparisonStrategy();
    case ResearchIntent.decisionSupport:
      return const DecisionStrategy();
    case ResearchIntent.factFinding:
      return const FactFindingStrategy();
    case ResearchIntent.academicResearch:
      return const FactFindingStrategy();
    default:
      return const DecisionStrategy();
  }
}

int _cap(ResearchMode mode) {
  switch (mode) {
    case ResearchMode.quick:
      return 3;
    case ResearchMode.standard:
      return 8;
    case ResearchMode.deep:
      return 16;
    case ResearchMode.exhaustive:
      return 32;
  }
}

class ComparisonStrategy implements ResearchStrategy {
  const ComparisonStrategy();

  @override
  String get id => 'comparison';

  @override
  ResearchPlan createPlan(ResearchRequest request, InterpretedGoal goal) {
    final subjects = ResearchInterpreter.splitSubjects(goal.topic);
    final nodes = <ResearchPlanNode>[];
    final subjectIds = <String>[];
    for (var i = 0; i < subjects.length; i++) {
      final id = 's$i';
      subjectIds.add(id);
      nodes.add(
        ResearchPlanNode(
          id: id,
          question: subjects[i],
          kind: PlanNodeKind.breadth,
        ),
      );
      if (request.mode != ResearchMode.quick) {
        final facets = goal.dimensions.take(4).toList();
        for (var f = 0; f < facets.length; f++) {
          nodes.add(
            ResearchPlanNode(
              id: 's${i}d$f',
              question: '${subjects[i]} ${facets[f]}',
              kind: PlanNodeKind.depth,
              dependsOn: [id],
            ),
          );
        }
      }
    }
    if (request.mode != ResearchMode.quick) {
      nodes.add(
        ResearchPlanNode(
          id: 'counter',
          question: '${goal.topic} limitations and contradictory evidence',
          kind: PlanNodeKind.depth,
          dependsOn: subjectIds,
        ),
      );
    }
    return ResearchPlan(
      rootQuestion: goal.topic,
      strategyId: id,
      nodes: nodes.take(_cap(request.mode)).toList(growable: false),
    );
  }
}

class DecisionStrategy implements ResearchStrategy {
  const DecisionStrategy();

  @override
  String get id => 'decision';

  @override
  ResearchPlan createPlan(ResearchRequest request, InterpretedGoal goal) {
    final nodes = <ResearchPlanNode>[
      ResearchPlanNode(
        id: 'root',
        question: goal.topic,
        kind: PlanNodeKind.breadth,
      ),
    ];
    if (request.mode != ResearchMode.quick) {
      for (var i = 0; i < goal.dimensions.length; i++) {
        nodes.add(
          ResearchPlanNode(
            id: 'd$i',
            question: '${goal.topic} — ${goal.dimensions[i]}',
            kind: PlanNodeKind.depth,
            dependsOn: const ['root'],
          ),
        );
      }
      nodes.add(
        ResearchPlanNode(
          id: 'counter',
          question: 'reasons not to choose: ${goal.topic}',
          kind: PlanNodeKind.depth,
          dependsOn: const ['root'],
        ),
      );
    }
    return ResearchPlan(
      rootQuestion: goal.topic,
      strategyId: id,
      nodes: nodes.take(_cap(request.mode)).toList(growable: false),
    );
  }
}

class FactFindingStrategy implements ResearchStrategy {
  const FactFindingStrategy();

  @override
  String get id => 'fact_finding';

  @override
  ResearchPlan createPlan(ResearchRequest request, InterpretedGoal goal) {
    final nodes = <ResearchPlanNode>[
      ResearchPlanNode(
        id: 'root',
        question: goal.topic,
        kind: PlanNodeKind.breadth,
      ),
    ];
    if (request.mode != ResearchMode.quick) {
      nodes.add(
        ResearchPlanNode(
          id: 'official',
          question: '${goal.topic} official documentation',
          kind: PlanNodeKind.depth,
          dependsOn: const ['root'],
        ),
      );
    }
    return ResearchPlan(
      rootQuestion: goal.topic,
      strategyId: id,
      nodes: nodes.take(_cap(request.mode)).toList(growable: false),
    );
  }
}
