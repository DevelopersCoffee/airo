import 'package:meta/meta.dart';

import '../skills/ai_trajectory_trace.dart';

/// Compile-time inspector switch. Default on so debug and tests persist
/// traces; release can pass `--dart-define=MIND_CHAT_TURN_INSPECTOR=false`.
const bool kMindChatTurnInspector = bool.fromEnvironment(
  'MIND_CHAT_TURN_INSPECTOR',
  defaultValue: true,
);

/// Stream / orchestration lifecycle for one chat turn.
enum ChatTurnLifecycle {
  started,
  firstToken,
  streaming,
  finished,
  aborted,
  failed,
}

/// Why generation or orchestration stopped.
enum ChatTurnStopReason {
  eos,
  maxTokens,
  userCancel,
  processKilled,
  engineError,
  emptyOutput,
  unknown,
}

/// Local vs cloud routing recorded on the turn, not the Health Center model.
enum ChatTurnRouting { local, cloud, unavailable }

/// One scalar constraint that changed between history and the current send.
@immutable
class ChatTurnInertiaDelta {
  const ChatTurnInertiaDelta({
    required this.kindId,
    required this.previousValue,
    required this.currentValue,
  });

  final String kindId;
  final int previousValue;
  final int currentValue;

  Map<String, Object?> toJson() => {
    'id': kindId,
    'previous': previousValue,
    'current': currentValue,
  };

  factory ChatTurnInertiaDelta.fromJson(Map<String, Object?> json) {
    return ChatTurnInertiaDelta(
      kindId: json['id'] as String? ?? '',
      previousValue: (json['previous'] as num?)?.toInt() ?? 0,
      currentValue: (json['current'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Grammar / prefix constraint attached to this generate.
@immutable
class ChatTurnConstraint {
  const ChatTurnConstraint({required this.gbnfAttached, this.prefixHash});

  static const none = ChatTurnConstraint(gbnfAttached: false);

  final bool gbnfAttached;
  final String? prefixHash;

  Map<String, Object?> toJson() => {
    'gbnf_attached': gbnfAttached,
    if (prefixHash != null) 'prefix_hash': prefixHash,
  };

  factory ChatTurnConstraint.fromJson(Map<String, Object?> json) {
    return ChatTurnConstraint(
      gbnfAttached: json['gbnf_attached'] == true,
      prefixHash: json['prefix_hash'] as String?,
    );
  }
}

/// Timing and token stats for the generate.
@immutable
class ChatTurnStats {
  const ChatTurnStats({
    this.prefillMs,
    this.generatedTokens,
    this.maxOutputTokens,
    this.timeToFirstTokenMs,
  });

  static const empty = ChatTurnStats();

  final int? prefillMs;
  final int? generatedTokens;
  final int? maxOutputTokens;
  final int? timeToFirstTokenMs;

  Map<String, Object?> toJson() => {
    if (prefillMs != null) 'prefill_ms': prefillMs,
    if (generatedTokens != null) 'generated_tokens': generatedTokens,
    if (maxOutputTokens != null) 'max_output_tokens': maxOutputTokens,
    if (timeToFirstTokenMs != null)
      'time_to_first_token_ms': timeToFirstTokenMs,
  };

  factory ChatTurnStats.fromJson(Map<String, Object?> json) {
    return ChatTurnStats(
      prefillMs: (json['prefill_ms'] as num?)?.toInt(),
      generatedTokens: (json['generated_tokens'] as num?)?.toInt(),
      maxOutputTokens: (json['max_output_tokens'] as num?)?.toInt(),
      timeToFirstTokenMs: (json['time_to_first_token_ms'] as num?)?.toInt(),
    );
  }
}

/// One user send that entered orchestration or generate.
@immutable
class ChatTurnTrace {
  const ChatTurnTrace({
    required this.runId,
    required this.startedAt,
    required this.lifecycle,
    required this.stopReason,
    required this.runtimeId,
    required this.routing,
    required this.constraint,
    required this.inertia,
    required this.stats,
    required this.trajectory,
    this.parentRunId,
    this.endedAt,
    this.pluginId,
    this.skillId,
    this.promptRef,
    this.systemRef,
    this.answerRef,
  });

  static const int schemaVersion = 1;

  final String runId;
  final String? parentRunId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final ChatTurnLifecycle lifecycle;
  final ChatTurnStopReason stopReason;
  final String runtimeId;
  final ChatTurnRouting routing;
  final String? pluginId;
  final String? skillId;
  final ChatTurnConstraint constraint;
  final List<ChatTurnInertiaDelta> inertia;
  final ChatTurnStats stats;
  final AiTrajectoryTrace trajectory;
  final String? promptRef;
  final String? systemRef;
  final String? answerRef;

  static String promptUri(String runId) => 'local://turn/$runId/prompt';
  static String systemUri(String runId) => 'local://turn/$runId/system';
  static String answerUri(String runId) => 'local://turn/$runId/answer';

  Duration? get duration {
    final end = endedAt;
    if (end == null) return null;
    return end.difference(startedAt);
  }

  Map<String, Object?> toJson() => {
    'schema_version': schemaVersion,
    'run_id': runId,
    if (parentRunId != null) 'parent_run_id': parentRunId,
    'started_at': startedAt.toUtc().toIso8601String(),
    if (endedAt != null) 'ended_at': endedAt!.toUtc().toIso8601String(),
    'lifecycle': chatTurnLifecycleWireName(lifecycle),
    'stop_reason': chatTurnStopReasonWireName(stopReason),
    'runtime_id': runtimeId,
    'routing': routing.name,
    if (pluginId != null) 'plugin_id': pluginId,
    if (skillId != null) 'skill_id': skillId,
    'constraint': constraint.toJson(),
    'inertia': {
      'kinds': inertia.map((delta) => delta.toJson()).toList(growable: false),
    },
    'stats': stats.toJson(),
    'trajectory': trajectory.toJson(),
    if (promptRef != null) 'prompt_ref': promptRef,
    if (systemRef != null) 'system_ref': systemRef,
    if (answerRef != null) 'answer_ref': answerRef,
  };

  factory ChatTurnTrace.fromJson(Map<String, Object?> json) {
    final inertiaRaw = json['inertia'];
    final kinds = inertiaRaw is Map
        ? (inertiaRaw['kinds'] as List<dynamic>? ?? const [])
        : const <dynamic>[];
    return ChatTurnTrace(
      runId: json['run_id'] as String? ?? '',
      parentRunId: json['parent_run_id'] as String?,
      startedAt:
          DateTime.tryParse(json['started_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      endedAt: DateTime.tryParse(json['ended_at'] as String? ?? ''),
      lifecycle: parseChatTurnLifecycle(json['lifecycle'] as String?),
      stopReason: parseChatTurnStopReason(json['stop_reason'] as String?),
      runtimeId: json['runtime_id'] as String? ?? '',
      routing: ChatTurnRouting.values.firstWhere(
        (value) => value.name == json['routing'],
        orElse: () => ChatTurnRouting.unavailable,
      ),
      pluginId: json['plugin_id'] as String?,
      skillId: json['skill_id'] as String?,
      constraint: json['constraint'] is Map
          ? ChatTurnConstraint.fromJson(
              Map<String, Object?>.from(json['constraint'] as Map),
            )
          : ChatTurnConstraint.none,
      inertia: kinds
          .map(
            (raw) => ChatTurnInertiaDelta.fromJson(
              Map<String, Object?>.from(raw as Map),
            ),
          )
          .toList(growable: false),
      stats: json['stats'] is Map
          ? ChatTurnStats.fromJson(
              Map<String, Object?>.from(json['stats'] as Map),
            )
          : ChatTurnStats.empty,
      trajectory: json['trajectory'] is Map
          ? AiTrajectoryTrace.fromJson(
              Map<String, Object?>.from(json['trajectory'] as Map),
            )
          : AiTrajectoryTrace(
              runId: json['run_id'] as String? ?? '',
              nodes: const [],
            ),
      promptRef: json['prompt_ref'] as String?,
      systemRef: json['system_ref'] as String?,
      answerRef: json['answer_ref'] as String?,
    );
  }
}

String chatTurnLifecycleWireName(ChatTurnLifecycle value) {
  return switch (value) {
    ChatTurnLifecycle.firstToken => 'first_token',
    _ => value.name,
  };
}

ChatTurnLifecycle parseChatTurnLifecycle(String? raw) {
  return switch (raw) {
    'first_token' => ChatTurnLifecycle.firstToken,
    'streaming' => ChatTurnLifecycle.streaming,
    'finished' => ChatTurnLifecycle.finished,
    'aborted' => ChatTurnLifecycle.aborted,
    'failed' => ChatTurnLifecycle.failed,
    _ => ChatTurnLifecycle.started,
  };
}

String chatTurnStopReasonWireName(ChatTurnStopReason value) {
  return switch (value) {
    ChatTurnStopReason.maxTokens => 'max_tokens',
    ChatTurnStopReason.userCancel => 'user_cancel',
    ChatTurnStopReason.processKilled => 'process_killed',
    ChatTurnStopReason.engineError => 'engine_error',
    ChatTurnStopReason.emptyOutput => 'empty_output',
    ChatTurnStopReason.eos => 'eos',
    ChatTurnStopReason.unknown => 'unknown',
  };
}

ChatTurnStopReason parseChatTurnStopReason(String? raw) {
  return switch (raw) {
    'eos' => ChatTurnStopReason.eos,
    'max_tokens' => ChatTurnStopReason.maxTokens,
    'user_cancel' => ChatTurnStopReason.userCancel,
    'process_killed' => ChatTurnStopReason.processKilled,
    'engine_error' => ChatTurnStopReason.engineError,
    'empty_output' => ChatTurnStopReason.emptyOutput,
    _ => ChatTurnStopReason.unknown,
  };
}

/// Records one turn without failing the generate if persistence later throws.
class ChatTurnTraceBuilder {
  ChatTurnTraceBuilder({
    required this.runId,
    this.parentRunId,
    DateTime? startedAt,
    AiTraceRedactor? redactor,
  }) : startedAt = startedAt ?? DateTime.now().toUtc(),
       _trajectory = AiTrajectoryTraceBuilder(runId: runId, redactor: redactor);

  final String runId;
  final String? parentRunId;
  final DateTime startedAt;
  final AiTrajectoryTraceBuilder _trajectory;

  ChatTurnLifecycle _lifecycle = ChatTurnLifecycle.started;
  ChatTurnStopReason _stopReason = ChatTurnStopReason.unknown;
  DateTime? _endedAt;
  String _runtimeId = '';
  ChatTurnRouting _routing = ChatTurnRouting.unavailable;
  String? _pluginId;
  String? _skillId;
  ChatTurnConstraint _constraint = ChatTurnConstraint.none;
  final List<ChatTurnInertiaDelta> _inertia = [];
  ChatTurnStats _stats = ChatTurnStats.empty;
  String? _promptRef;
  String? _systemRef;
  String? _answerRef;

  ChatTurnTraceBuilder runtime({
    required String id,
    required ChatTurnRouting routing,
  }) {
    _runtimeId = id;
    _routing = routing;
    return this;
  }

  ChatTurnTraceBuilder plugin(String pluginId) {
    _pluginId = pluginId;
    return this;
  }

  ChatTurnTraceBuilder skill(String skillId) {
    _skillId = skillId;
    _trajectory.selectedSkill(skillId);
    return this;
  }

  ChatTurnTraceBuilder constraint({
    required bool gbnfAttached,
    String? prefixHash,
  }) {
    _constraint = ChatTurnConstraint(
      gbnfAttached: gbnfAttached,
      prefixHash: prefixHash,
    );
    return this;
  }

  ChatTurnTraceBuilder inertia({
    required String kindId,
    required int previousValue,
    required int currentValue,
  }) {
    _inertia.add(
      ChatTurnInertiaDelta(
        kindId: kindId,
        previousValue: previousValue,
        currentValue: currentValue,
      ),
    );
    return this;
  }

  ChatTurnTraceBuilder stats({
    int? prefillMs,
    int? generatedTokens,
    int? maxOutputTokens,
    int? timeToFirstTokenMs,
  }) {
    _stats = ChatTurnStats(
      prefillMs: prefillMs ?? _stats.prefillMs,
      generatedTokens: generatedTokens ?? _stats.generatedTokens,
      maxOutputTokens: maxOutputTokens ?? _stats.maxOutputTokens,
      timeToFirstTokenMs: timeToFirstTokenMs ?? _stats.timeToFirstTokenMs,
    );
    return this;
  }

  ChatTurnTraceBuilder prompt({required String summary, String? ref}) {
    _promptRef = ref ?? ChatTurnTrace.promptUri(runId);
    _trajectory.promptRef(ref: _promptRef!, summary: summary);
    return this;
  }

  ChatTurnTraceBuilder systemPrompt({required String summary, String? ref}) {
    _systemRef = ref ?? ChatTurnTrace.systemUri(runId);
    _trajectory.parametersRef(ref: _systemRef!, summary: summary);
    return this;
  }

  ChatTurnTraceBuilder answer({required String summary, String? ref}) {
    _answerRef = ref ?? ChatTurnTrace.answerUri(runId);
    _trajectory.finalAnswerRef(ref: _answerRef!, summary: summary);
    return this;
  }

  ChatTurnTraceBuilder markFirstToken() {
    if (_lifecycle == ChatTurnLifecycle.started) {
      _lifecycle = ChatTurnLifecycle.firstToken;
    }
    return this;
  }

  ChatTurnTraceBuilder markStreaming() {
    if (_lifecycle == ChatTurnLifecycle.started ||
        _lifecycle == ChatTurnLifecycle.firstToken) {
      _lifecycle = ChatTurnLifecycle.streaming;
    }
    return this;
  }

  ChatTurnTraceBuilder finish({
    ChatTurnStopReason reason = ChatTurnStopReason.eos,
    DateTime? endedAt,
  }) {
    _lifecycle = ChatTurnLifecycle.finished;
    _stopReason = reason;
    _endedAt = endedAt ?? DateTime.now().toUtc();
    return this;
  }

  ChatTurnTraceBuilder abort({
    required ChatTurnStopReason reason,
    DateTime? endedAt,
  }) {
    _lifecycle = ChatTurnLifecycle.aborted;
    _stopReason = reason;
    _endedAt = endedAt ?? DateTime.now().toUtc();
    return this;
  }

  ChatTurnTraceBuilder fail({
    required String errorCode,
    required String summary,
    DateTime? endedAt,
  }) {
    _lifecycle = ChatTurnLifecycle.failed;
    _stopReason = ChatTurnStopReason.engineError;
    _endedAt = endedAt ?? DateTime.now().toUtc();
    _trajectory.error(code: errorCode, summary: summary);
    return this;
  }

  ChatTurnTrace build() {
    return ChatTurnTrace(
      runId: runId,
      parentRunId: parentRunId,
      startedAt: startedAt,
      endedAt: _endedAt,
      lifecycle: _lifecycle,
      stopReason: _stopReason,
      runtimeId: _runtimeId,
      routing: _routing,
      pluginId: _pluginId,
      skillId: _skillId,
      constraint: _constraint,
      inertia: List<ChatTurnInertiaDelta>.unmodifiable(_inertia),
      stats: _stats,
      trajectory: _trajectory.build(),
      promptRef: _promptRef,
      systemRef: _systemRef,
      answerRef: _answerRef,
    );
  }
}
