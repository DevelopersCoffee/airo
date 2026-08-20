import '../../domain/models/agent_skill.dart';
import '../../domain/services/agent_connector.dart';

/// Wellbeing is a skill plugin, not a shell destination.
///
/// Breathing and reflection run through tools. Chat loads this skill and
/// calls the connectors; there is no framework Wellbeing tab.
final wellbeingSkill = AgentSkill(
  id: 'wellbeing-check-in',
  name: 'Wellbeing',
  description:
      'Breathing reset, reflection, and a short check-in via skills and tools.',
  instructions:
      'When the user wants to calm down, breathe, reflect, or check in, '
      'load this skill. Call guide_breathing for a timed reset, or '
      'log_reflection to capture how the day feels. Answer from the tool '
      'result. Do not open a Wellbeing screen or invent a streak.',
  tools: const ['guide_breathing', 'log_reflection'],
);

class GuideBreathingConnector implements AgentConnector {
  @override
  String get name => 'guide_breathing';

  @override
  Set<SkillCapability> get requiredCapabilities => const {};

  @override
  Future<ConnectorResult> execute(Map<String, dynamic> arguments) async {
    return const ConnectorResult(
      data: {
        'exercise': 'box_breathing',
        'duration_seconds': 60,
        'steps': [
          'Inhale for 4 seconds',
          'Hold for 4 seconds',
          'Exhale for 4 seconds',
          'Hold for 4 seconds',
          'Repeat until a minute has passed',
        ],
      },
      message: '60-second box breathing is ready. Guide the user through it.',
    );
  }
}

class LogReflectionConnector implements AgentConnector {
  @override
  String get name => 'log_reflection';

  @override
  Set<SkillCapability> get requiredCapabilities => const {};

  @override
  Future<ConnectorResult> execute(Map<String, dynamic> arguments) async {
    final note = (arguments['note'] as String?)?.trim() ?? '';
    return ConnectorResult(
      data: {
        'prompt': 'What felt heavy or light today?',
        'note': note,
        'saved_locally': note.isNotEmpty,
      },
      message: note.isEmpty
          ? 'Ask one short reflection question, then call again with note.'
          : 'Reflection captured.',
    );
  }
}
