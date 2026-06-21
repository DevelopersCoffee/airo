import '../../domain/models/agent_skill.dart';

final calendarTodaySkill = AgentSkill(
  id: 'read-calendar-events',
  name: 'Read Calendar Events',
  description: 'Read OS calendar events for a specific date.',
  instructions:
      'Use this when the user asks about their schedule, agenda, meetings, '
      'appointments, or calendar events. First call get_current_date_time. '
      'Then call read_calendar_events with date in YYYY-MM-DD format. '
      'Summarize events by time. If there are no events, say there are no '
      'events scheduled.',
  tools: const ['get_current_date_time', 'read_calendar_events'],
  capabilities: const [SkillCapability.calendarRead],
);
