import '../../domain/models/agent_skill.dart';
import '../../domain/repositories/agent_skill_repository.dart';
import '../built_in_skills/calendar_today.dart';
import '../built_in_skills/create_calendar_event.dart';

class BuiltInAgentSkillRepository implements AgentSkillRepository {
  BuiltInAgentSkillRepository({
    List<AgentSkill>? skills,
    Map<String, bool> initialEnabledState = const {},
    this._onEnabledStateChanged,
  }) : _skills = {
         for (final skill in skills ?? builtInAgentSkills)
           skill.id: initialEnabledState.containsKey(skill.id)
               ? skill.copyWith(enabled: initialEnabledState[skill.id])
               : skill,
       };

  final Map<String, AgentSkill> _skills;
  final void Function(Map<String, bool> enabledState)? _onEnabledStateChanged;

  @override
  List<AgentSkill> getAllSkills() => List.unmodifiable(_skills.values);

  @override
  List<AgentSkill> getEnabledSkills() {
    return getAllSkills().where((skill) => skill.isEnabled).toList();
  }

  @override
  AgentSkill? getById(String id) => _skills[id];

  @override
  List<AgentSkill> search(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return getAllSkills();
    return getAllSkills().where((skill) {
      final searchable = [
        skill.id,
        skill.name,
        skill.description,
        ...skill.tools,
        ...skill.capabilities.map((capability) => capability.key),
      ].join(' ').toLowerCase();
      return searchable.contains(normalized);
    }).toList();
  }

  @override
  List<String> enabledSkillSummariesForPrompt() {
    return getEnabledSkills().map((skill) => skill.summaryForPrompt).toList();
  }

  @override
  void setSkillEnabled(String id, bool enabled) {
    final skill = _skills[id];
    if (skill == null) return;
    _skills[id] = skill.copyWith(enabled: enabled);
    _notifyEnabledStateChanged();
  }

  @override
  void enableAll() {
    for (final skill in getAllSkills()) {
      _skills[skill.id] = skill.copyWith(enabled: true);
    }
    _notifyEnabledStateChanged();
  }

  @override
  void disableAll() {
    for (final skill in getAllSkills()) {
      _skills[skill.id] = skill.copyWith(enabled: false);
    }
    _notifyEnabledStateChanged();
  }

  void _notifyEnabledStateChanged() {
    _onEnabledStateChanged?.call({
      for (final skill in getAllSkills()) skill.id: skill.isEnabled,
    });
  }
}

final builtInAgentSkills = <AgentSkill>[
  calendarTodaySkill,
  createCalendarEventSkill,
  AgentSkill(
    id: 'schedule-notification',
    name: 'Schedule Notification',
    description: 'Schedule a reminder notification.',
    instructions:
        'Use this when the user asks to create a reminder or notification. '
        'Gather title, message, hour, minute, whether it repeats daily, and '
        'date when needed. Then call schedule_notification.',
    tools: const ['get_current_date_time', 'schedule_notification'],
    capabilities: const [SkillCapability.notificationsSchedule],
  ),
  AgentSkill(
    id: 'query-lifetrack-status',
    name: 'LifeTrack Status',
    description:
        'Answer questions about active LifeTrack goals from local data.',
    instructions:
        'Use this when the user asks what is pending, what documents are '
        'needed, or what the status is for a LifeTrack goal. Call '
        'query_lifetrack_status with the original query and return the '
        'connector markdown directly without inventing missing data.',
    tools: const ['query_lifetrack_status'],
    capabilities: const [SkillCapability.lifeTrackRead],
  ),
  AgentSkill(
    id: 'open-airo-feature',
    name: 'Open Airo Feature',
    description: 'Open Money, Quest, Beats, Games, Stream, or Reader.',
    instructions: 'Use this when the user asks to open an Airo feature.',
    tools: const ['open_route'],
    capabilities: const [SkillCapability.routeOpen],
  ),
];
