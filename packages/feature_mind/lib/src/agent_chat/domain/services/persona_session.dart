import '../../../runtime/models/capability_models.dart';
import '../models/agent_skill.dart';

/// Resolves a pinned Jan-style assistant versus unpinned (normal) chat.
///
/// Unpinned chat auto-selects tool skills. A pinned persona owns the
/// conversation: its instructions replace the generic Airo voice, its
/// declared tools are the only connectors it may call, and its safety
/// class drives the banner.
class PersonaSession {
  const PersonaSession({this.pinned});

  final AgentSkill? pinned;

  bool get isPinned => pinned != null;

  String? get pinnedId => pinned?.id;

  CapabilitySafetyClass? get safetyClass {
    final persona = pinned;
    if (persona == null) return null;
    if (persona.safetyClass != CapabilitySafetyClass.general) {
      return persona.safetyClass;
    }
    return resolvePersonaSafetyClass(persona);
  }

  List<String> get starterPrompts => pinned?.starterPrompts ?? const [];

  /// Exclusive playbook when pinned. Empty in normal chat so callers keep
  /// injecting every enabled generative plugin.
  List<String> playbooks() {
    final persona = pinned;
    if (persona == null) return const [];
    final lines = <String>['${persona.name}: ${persona.instructions}'];
    switch (persona.followUpPolicy) {
      case SkillFollowUpPolicy.offerCalendar:
        lines.add(
          'Follow-up: offer to add deadlines and the next action to the calendar.',
        );
      case SkillFollowUpPolicy.dailyUntilDone:
        lines.add(
          'Follow-up: offer a daily reminder until the current next action is done.',
        );
      case SkillFollowUpPolicy.none:
        break;
    }
    final templateId = persona.lifeTrackTemplateId;
    if (templateId != null && templateId.isNotEmpty) {
      lines.add(
        'When asked what is pending or the next to-do, use LifeTrack '
        '(template $templateId) rather than inventing tasks.',
      );
    }
    return lines;
  }

  String identityPreamble() {
    final persona = pinned;
    if (persona == null) return '';
    return 'You are ${persona.name}, a private on-device Airo assistant. '
        'Chats stay on this device. Stay in this role until the user '
        'switches assistants. ${persona.description}';
  }

  bool usesTool(String tool) => pinned?.tools.contains(tool) ?? false;
}

CapabilitySafetyClass? resolvePersonaSafetyClass(AgentSkill skill) {
  if (skill.safetyClass != CapabilitySafetyClass.general) {
    return skill.safetyClass;
  }
  return null;
}

String familyLabel(AgentPersonaFamily family) => switch (family) {
  AgentPersonaFamily.general => 'General',
  AgentPersonaFamily.teacher => 'Teacher',
  AgentPersonaFamily.law => 'Law',
  AgentPersonaFamily.health => 'Health',
  AgentPersonaFamily.insurance => 'Insurance',
  AgentPersonaFamily.property => 'Property',
  AgentPersonaFamily.education => 'Education',
  AgentPersonaFamily.vehicle => 'Vehicle',
  AgentPersonaFamily.project => 'Project',
};
