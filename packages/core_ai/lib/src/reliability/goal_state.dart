import 'package:meta/meta.dart';

import 'reasoning_reliability.dart';

enum GoalStatus { created, executing, verifying, completed, failed }

/// Fail-closed turn state. The model cannot mark completion.
@immutable
class ChatTurnGoal {
  const ChatTurnGoal({required this.goal, this.status = GoalStatus.created});

  final String goal;
  final GoalStatus status;

  ChatTurnGoal start() =>
      ChatTurnGoal(goal: goal, status: GoalStatus.executing);

  ChatTurnGoal verify(OutputVerification verification) {
    if (status == GoalStatus.completed) {
      throw StateError('model cannot skip to completed');
    }
    return switch (verification) {
      OutputVerification.passed => ChatTurnGoal(
        goal: goal,
        status: GoalStatus.completed,
      ),
      OutputVerification.failed || OutputVerification.incomplete =>
        ChatTurnGoal(goal: goal, status: GoalStatus.failed),
    };
  }

  bool get succeeded => status == GoalStatus.completed;
}
