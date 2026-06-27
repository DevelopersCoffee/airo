import 'package:equatable/equatable.dart';

enum SkillCapability {
  calendarRead('calendar.read', 'Calendar read'),
  calendarWrite('calendar.write', 'Calendar write'),
  notificationsSchedule('notifications.schedule', 'Notifications'),
  routeOpen('route.open', 'Open route');

  const SkillCapability(this.key, this.label);

  final String key;
  final String label;

  static SkillCapability? fromKey(String key) {
    for (final capability in values) {
      if (capability.key == key) return capability;
    }
    return null;
  }
}

enum SkillRuntime { native }

class AgentSkill extends Equatable {
  final String id;
  final String name;
  final String description;
  final String instructions;
  final List<String> tools;
  final List<SkillCapability> capabilities;
  final SkillRuntime runtime;
  final bool enabled;

  const AgentSkill({
    required this.id,
    required this.name,
    required this.description,
    required this.instructions,
    required this.tools,
    required this.capabilities,
    this.runtime = SkillRuntime.native,
    this.enabled = true,
  });

  AgentSkill copyWith({bool? enabled}) {
    return AgentSkill(
      id: id,
      name: name,
      description: description,
      instructions: instructions,
      tools: tools,
      capabilities: capabilities,
      runtime: runtime,
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    instructions,
    tools,
    capabilities,
    runtime,
    enabled,
  ];
}

class AgentActionTrace extends Equatable {
  final String title;
  final String detail;
  final Map<String, dynamic> parameters;
  final bool success;

  const AgentActionTrace({
    required this.title,
    required this.detail,
    this.parameters = const {},
    this.success = true,
  });

  @override
  List<Object?> get props => [title, detail, parameters, success];
}

class AgentRunResult extends Equatable {
  final bool handled;
  final String message;
  final List<AgentActionTrace> traces;
  final bool isError;
  final String? route;
  final Map<String, dynamic> parameters;
  final Map<String, dynamic>? pendingCalendarEvent;

  const AgentRunResult({
    required this.handled,
    required this.message,
    this.traces = const [],
    this.isError = false,
    this.route,
    this.parameters = const {},
    this.pendingCalendarEvent,
  });

  const AgentRunResult.notHandled()
    : handled = false,
      message = '',
      traces = const [],
      isError = false,
      route = null,
      parameters = const {},
      pendingCalendarEvent = null;

  bool get shouldNavigate => route != null && route != '/agent';

  @override
  List<Object?> get props => [
    handled,
    message,
    traces,
    isError,
    route,
    parameters,
    pendingCalendarEvent,
  ];
}
