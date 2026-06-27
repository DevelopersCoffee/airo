import 'package:equatable/equatable.dart';

enum SkillCapability {
  calendarRead('calendar.read', 'Calendar read'),
  calendarWrite('calendar.write', 'Calendar write'),
  notificationsSchedule('notifications.schedule', 'Notifications'),
  locationRead('location.read', 'Location read'),
  webFetch('web.fetch', 'Web fetch'),
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

enum SkillRuntime {
  native('native');

  const SkillRuntime(this.key);

  final String key;

  static SkillRuntime? fromKey(String key) {
    for (final runtime in values) {
      if (runtime.key == key) return runtime;
    }
    return null;
  }
}

enum SkillSource { builtIn, local, remote }

enum SkillInstallState { enabled, disabled, notInstalled }

class AgentSkillManifest extends Equatable {
  final String id;
  final String name;
  final String description;
  final String version;
  final String author;
  final SkillRuntime runtime;
  final SkillSource source;
  final SkillInstallState installState;
  final List<SkillCapability> capabilities;
  final List<String> tools;

  const AgentSkillManifest({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.author,
    required this.runtime,
    required this.source,
    required this.installState,
    required this.capabilities,
    required this.tools,
  });

  AgentSkillManifest copyWith({SkillInstallState? installState}) {
    return AgentSkillManifest(
      id: id,
      name: name,
      description: description,
      version: version,
      author: author,
      runtime: runtime,
      source: source,
      installState: installState ?? this.installState,
      capabilities: capabilities,
      tools: tools,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    version,
    author,
    runtime,
    source,
    installState,
    capabilities,
    tools,
  ];
}

class AgentSkill extends Equatable {
  final AgentSkillManifest manifest;
  final String instructions;

  AgentSkill({
    required String id,
    required String name,
    required String description,
    String version = '1.0.0',
    String author = 'Airo',
    SkillRuntime runtime = SkillRuntime.native,
    SkillSource source = SkillSource.builtIn,
    bool enabled = true,
    List<String> tools = const [],
    List<SkillCapability> capabilities = const [],
    required this.instructions,
  }) : manifest = AgentSkillManifest(
         id: id,
         name: name,
         description: description,
         version: version,
         author: author,
         runtime: runtime,
         source: source,
         installState: enabled
             ? SkillInstallState.enabled
             : SkillInstallState.disabled,
         capabilities: capabilities,
         tools: tools,
       );

  const AgentSkill.fromManifest({
    required this.manifest,
    required this.instructions,
  });

  String get id => manifest.id;
  String get name => manifest.name;
  String get description => manifest.description;
  List<String> get tools => manifest.tools;
  List<SkillCapability> get capabilities => manifest.capabilities;
  SkillRuntime get runtime => manifest.runtime;
  bool get enabled => manifest.installState == SkillInstallState.enabled;
  bool get isEnabled => enabled;

  String get summaryForPrompt {
    final normalizedDescription = description.endsWith('.')
        ? description.substring(0, description.length - 1)
        : description;
    return '- $id: $name — $normalizedDescription. Tools: ${tools.join(', ')}';
  }

  AgentSkill copyWith({bool? enabled}) {
    return AgentSkill.fromManifest(
      manifest: manifest.copyWith(
        installState: enabled == null
            ? manifest.installState
            : (enabled
                  ? SkillInstallState.enabled
                  : SkillInstallState.disabled),
      ),
      instructions: instructions,
    );
  }

  @override
  List<Object?> get props => [manifest, instructions];
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
