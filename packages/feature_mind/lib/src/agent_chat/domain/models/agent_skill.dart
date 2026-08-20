import 'package:equatable/equatable.dart';

import '../../../runtime/models/capability_models.dart';
import 'data_volume_measurement.dart';
import 'grounded_citation.dart';

enum SkillCapability {
  calendarRead('calendar.read', 'Calendar read'),
  calendarWrite('calendar.write', 'Calendar write'),
  notificationsSchedule('notifications.schedule', 'Notifications'),
  lifeTrackRead('lifetrack.read', 'LifeTrack read'),
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

/// A pin-able Jan-style assistant versus an auto-selected tool skill.
enum AgentSkillMode {
  skill('skill'),
  persona('persona');

  const AgentSkillMode(this.key);

  final String key;

  static AgentSkillMode? fromKey(String key) {
    for (final mode in values) {
      if (mode.key == key) return mode;
    }
    return null;
  }
}

/// Domain family for grouping assistants in the switcher.
enum AgentPersonaFamily {
  general('general'),
  teacher('teacher'),
  law('law'),
  health('health'),
  insurance('insurance'),
  property('property'),
  education('education'),
  vehicle('vehicle'),
  project('project');

  const AgentPersonaFamily(this.key);

  final String key;

  static AgentPersonaFamily? fromKey(String key) {
    for (final family in values) {
      if (family.key == key) return family;
    }
    return null;
  }
}

enum SkillFollowUpPolicy {
  none('none'),
  dailyUntilDone('daily_until_done'),
  offerCalendar('offer_calendar');

  const SkillFollowUpPolicy(this.key);

  final String key;

  static SkillFollowUpPolicy? fromKey(String key) {
    for (final policy in values) {
      if (policy.key == key) return policy;
    }
    return null;
  }
}

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
  final AgentSkillMode mode;
  final AgentPersonaFamily family;
  final CapabilitySafetyClass safetyClass;
  final List<String> starterPrompts;
  final SkillFollowUpPolicy followUpPolicy;
  final String? lifeTrackTemplateId;

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
    this.mode = AgentSkillMode.skill,
    this.family = AgentPersonaFamily.general,
    this.safetyClass = CapabilitySafetyClass.general,
    this.starterPrompts = const [],
    this.followUpPolicy = SkillFollowUpPolicy.none,
    this.lifeTrackTemplateId,
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
      mode: mode,
      family: family,
      safetyClass: safetyClass,
      starterPrompts: starterPrompts,
      followUpPolicy: followUpPolicy,
      lifeTrackTemplateId: lifeTrackTemplateId,
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
    mode,
    family,
    safetyClass,
    starterPrompts,
    followUpPolicy,
    lifeTrackTemplateId,
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
    AgentSkillMode mode = AgentSkillMode.skill,
    AgentPersonaFamily family = AgentPersonaFamily.general,
    CapabilitySafetyClass safetyClass = CapabilitySafetyClass.general,
    List<String> starterPrompts = const [],
    SkillFollowUpPolicy followUpPolicy = SkillFollowUpPolicy.none,
    String? lifeTrackTemplateId,
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
         mode: mode,
         family: family,
         safetyClass: safetyClass,
         starterPrompts: starterPrompts,
         followUpPolicy: followUpPolicy,
         lifeTrackTemplateId: lifeTrackTemplateId,
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
  AgentSkillMode get mode => manifest.mode;
  AgentPersonaFamily get family => manifest.family;
  CapabilitySafetyClass get safetyClass => manifest.safetyClass;
  List<String> get starterPrompts => manifest.starterPrompts;
  SkillFollowUpPolicy get followUpPolicy => manifest.followUpPolicy;
  String? get lifeTrackTemplateId => manifest.lifeTrackTemplateId;
  bool get enabled => manifest.installState == SkillInstallState.enabled;
  bool get isEnabled => enabled;
  bool get isPersona => mode == AgentSkillMode.persona;

  /// No native tools — the chat model follows [instructions] as a plugin.
  bool get isGenerativePlugin => tools.isEmpty;

  String get summaryForPrompt {
    final normalizedDescription = description.endsWith('.')
        ? description.substring(0, description.length - 1)
        : description;
    if (isPersona) {
      return '- $id: $name — $normalizedDescription. Pinned assistant';
    }
    if (isGenerativePlugin) {
      return '- $id: $name — $normalizedDescription. Plugin for the chat model';
    }
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
  final int? durationMs;

  /// How much data this call measurably moved. Null when nothing was
  /// measured — a failed call swallows nothing, but it also asserts nothing.
  final DataVolumeMeasurement? dataVolume;

  const AgentActionTrace({
    required this.title,
    required this.detail,
    this.parameters = const {},
    this.success = true,
    this.durationMs,
    this.dataVolume,
  });

  @override
  List<Object?> get props => [
    title,
    detail,
    parameters,
    success,
    durationMs,
    dataVolume,
  ];
}

class AgentRunResult extends Equatable {
  final bool handled;
  final String message;
  final List<AgentActionTrace> traces;
  final bool isError;
  final String? route;
  final Map<String, dynamic> parameters;
  final Map<String, dynamic>? pendingCalendarEvent;
  final bool pendingCalendarPermission;

  /// Ops the final answer was replayed from. Empty unless [groundingState]
  /// is [GroundingState.grounded].
  final List<GroundedCitation> citations;

  /// Whether [message] is backed by a real op. Defaults to
  /// [GroundingState.notApplicable]: a navigation result or an error carries
  /// no factual claim to ground in the first place.
  final GroundingState groundingState;

  /// The safety banner this answer's capability requires, if any.
  final CapabilitySafetyClass? safetyClass;

  const AgentRunResult({
    required this.handled,
    required this.message,
    this.traces = const [],
    this.isError = false,
    this.route,
    this.parameters = const {},
    this.pendingCalendarEvent,
    this.pendingCalendarPermission = false,
    this.citations = const [],
    this.groundingState = GroundingState.notApplicable,
    this.safetyClass,
  });

  const AgentRunResult.notHandled()
    : handled = false,
      message = '',
      traces = const [],
      isError = false,
      route = null,
      parameters = const {},
      pendingCalendarEvent = null,
      pendingCalendarPermission = false,
      citations = const [],
      groundingState = GroundingState.notApplicable,
      safetyClass = null;

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
    pendingCalendarPermission,
    citations,
    groundingState,
    safetyClass,
  ];
}
