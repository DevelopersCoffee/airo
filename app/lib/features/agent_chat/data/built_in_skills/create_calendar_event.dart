import '../../domain/models/agent_skill.dart';

final createCalendarEventSkill = AgentSkill(
  id: 'create-calendar-event',
  name: 'Create Calendar Event',
  description: 'Prepare a calendar event after user confirmation.',
  instructions:
      'Use this when the user asks to create, add, or schedule a calendar '
      'event. Gather title, date, start time, and end time before calling '
      'create_calendar_event. Writes require explicit user confirmation.',
  tools: const [
    'calendar_permission_status',
    'get_current_date_time',
    'create_calendar_event',
  ],
  capabilities: const [SkillCapability.calendarWrite],
  enabled: false,
);
