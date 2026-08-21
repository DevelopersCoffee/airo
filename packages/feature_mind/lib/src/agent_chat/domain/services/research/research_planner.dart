import '../../models/research_request.dart';
import 'research_interpreter.dart';
import 'research_strategy.dart';

enum PlanNodeKind { breadth, depth }

class ResearchPlanNode {
  const ResearchPlanNode({
    required this.id,
    required this.question,
    required this.kind,
    this.dependsOn = const [],
  });

  final String id;
  final String question;
  final PlanNodeKind kind;
  final List<String> dependsOn;
}

class ResearchPlan {
  const ResearchPlan({
    required this.rootQuestion,
    required this.nodes,
    this.strategyId = '',
  });

  final String rootQuestion;
  final String strategyId;
  final List<ResearchPlanNode> nodes;
}

/// Intent → strategy → DAG. No model call.
class ResearchPlanner {
  const ResearchPlanner({this.interpreter = const ResearchInterpreter()});

  final ResearchInterpreter interpreter;

  ResearchPlan plan(ResearchRequest request) {
    final goal = interpreter.interpret(request);
    return strategyFor(goal.intent).createPlan(request, goal);
  }
}
