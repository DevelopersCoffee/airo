import '../models/agent_skill.dart';

class AgentSkillRegistry {
  AgentSkillRegistry({List<AgentSkill>? skills})
    : _skills = {for (final skill in skills ?? builtInSkills) skill.id: skill};

  final Map<String, AgentSkill> _skills;

  static const builtInSkills = [
    AgentSkill(
      id: 'read-calendar-events',
      name: 'Read Calendar Events',
      description: 'Read OS calendar events for a specific date.',
      instructions:
          'Use this when the user asks about their schedule, agenda, '
          'meetings, appointments, or calendar events. First call '
          'get_current_date_time. Then call read_calendar_events with date in '
          'YYYY-MM-DD format. Summarize events by time. If there are no '
          'events, say there are no events scheduled.',
      tools: ['get_current_date_time', 'read_calendar_events'],
      capabilities: [SkillCapability.calendarRead],
    ),
    AgentSkill(
      id: 'create-calendar-event',
      name: 'Create Calendar Event',
      description: 'Prepare a calendar event after user confirmation.',
      instructions:
          'Use this when the user asks to create, add, or schedule a calendar '
          'event. Gather title, date, start time, and end time before calling '
          'create_calendar_event.',
      tools: ['get_current_date_time', 'create_calendar_event'],
      capabilities: [SkillCapability.calendarWrite],
      enabled: false,
    ),
    AgentSkill(
      id: 'schedule-notification',
      name: 'Schedule Notification',
      description: 'Schedule a reminder notification.',
      instructions:
          'Use this when the user asks to create a reminder or notification.',
      tools: ['get_current_date_time'],
      capabilities: [SkillCapability.notificationsSchedule],
      enabled: false,
    ),
    AgentSkill(
      id: 'open-airo-feature',
      name: 'Open Airo Feature',
      description: 'Open Money, Quest, Beats, Games, Stream, or Reader.',
      instructions: 'Use this when the user asks to open an Airo feature.',
      tools: ['open_route'],
      capabilities: [SkillCapability.routeOpen],
      enabled: true,
    ),
  ];

  List<AgentSkill> getAllSkills() => _skills.values.toList();

  List<AgentSkill> getEnabledSkills() {
    return getAllSkills().where((skill) => skill.enabled).toList();
  }

  AgentSkill? getById(String id) => _skills[id];

  void setSkillEnabled(String id, bool enabled) {
    final skill = _skills[id];
    if (skill == null) return;
    _skills[id] = skill.copyWith(enabled: enabled);
  }

  void enableAll() {
    for (final skill in getAllSkills()) {
      _skills[skill.id] = skill.copyWith(enabled: true);
    }
  }

  void disableAll() {
    for (final skill in getAllSkills()) {
      _skills[skill.id] = skill.copyWith(enabled: false);
    }
  }
}
