import 'package:meta/meta.dart';

/// Stable trajectory node categories for local-first AI action tracing.
enum AiTrajectoryNodeKind {
  promptRef,
  selectedSkill,
  toolCall,
  parametersRef,
  resultRef,
  finalAnswerRef,
  confirmation,
  error,
  routine,
}

/// Stable trajectory node execution status.
enum AiTrajectoryNodeStatus { pending, succeeded, failed }

/// Redacted trajectory for QA and local observability.
@immutable
class AiTrajectoryTrace {
  const AiTrajectoryTrace({required this.runId, required this.nodes});

  static const int schemaVersion = 1;

  final String runId;
  final List<AiTrajectoryNode> nodes;

  Map<String, Object?> toJson() => {
    'schema_version': schemaVersion,
    'run_id': runId,
    'nodes': nodes.map((node) => node.toJson()).toList(growable: false),
  };
}

/// One redacted trajectory node.
@immutable
class AiTrajectoryNode {
  const AiTrajectoryNode({
    required this.sequence,
    required this.kind,
    required this.status,
    required this.label,
    this.ref,
    this.summary,
    this.errorCode,
  });

  final int sequence;
  final AiTrajectoryNodeKind kind;
  final AiTrajectoryNodeStatus status;
  final String label;
  final String? ref;
  final String? summary;
  final String? errorCode;

  Map<String, Object?> toJson() => {
    'sequence': sequence,
    'kind': kind.name,
    'status': status.name,
    'label': label,
    if (ref != null) 'ref': ref,
    if (summary != null) 'summary': summary,
    if (errorCode != null) 'error_code': errorCode,
  };
}

/// Deterministic builder for redacted trajectories.
class AiTrajectoryTraceBuilder {
  AiTrajectoryTraceBuilder({required this.runId, AiTraceRedactor? redactor})
    : _redactor = redactor ?? const AiTraceRedactor();

  final String runId;
  final AiTraceRedactor _redactor;
  final List<AiTrajectoryNode> _nodes = [];

  AiTrajectoryTraceBuilder promptRef({
    required String ref,
    required String summary,
  }) {
    return _add(
      kind: AiTrajectoryNodeKind.promptRef,
      label: 'prompt_ref',
      ref: ref,
      summary: summary,
    );
  }

  AiTrajectoryTraceBuilder selectedSkill(String skillId) {
    return _add(
      kind: AiTrajectoryNodeKind.selectedSkill,
      label: skillId,
      summary: skillId,
    );
  }

  AiTrajectoryTraceBuilder toolCall(String toolName) {
    return _add(
      kind: AiTrajectoryNodeKind.toolCall,
      label: toolName,
      summary: toolName,
    );
  }

  AiTrajectoryTraceBuilder parametersRef({
    required String ref,
    required String summary,
  }) {
    return _add(
      kind: AiTrajectoryNodeKind.parametersRef,
      label: 'parameters_ref',
      ref: ref,
      summary: summary,
    );
  }

  AiTrajectoryTraceBuilder resultRef({
    required String ref,
    required String summary,
  }) {
    return _add(
      kind: AiTrajectoryNodeKind.resultRef,
      label: 'result_ref',
      ref: ref,
      summary: summary,
    );
  }

  AiTrajectoryTraceBuilder finalAnswerRef({
    required String ref,
    required String summary,
  }) {
    return _add(
      kind: AiTrajectoryNodeKind.finalAnswerRef,
      label: 'final_answer_ref',
      ref: ref,
      summary: summary,
    );
  }

  AiTrajectoryTraceBuilder confirmationRequired({required String reason}) {
    return _add(
      kind: AiTrajectoryNodeKind.confirmation,
      status: AiTrajectoryNodeStatus.pending,
      label: 'confirmation_required',
      summary: reason,
    );
  }

  AiTrajectoryTraceBuilder error({
    required String code,
    required String summary,
  }) {
    return _add(
      kind: AiTrajectoryNodeKind.error,
      status: AiTrajectoryNodeStatus.failed,
      label: 'error',
      summary: summary,
      errorCode: code,
    );
  }

  AiTrajectoryTraceBuilder routine(String routineId) {
    return _add(
      kind: AiTrajectoryNodeKind.routine,
      label: routineId,
      summary: routineId,
    );
  }

  AiTrajectoryTrace build() {
    return AiTrajectoryTrace(
      runId: runId,
      nodes: List<AiTrajectoryNode>.unmodifiable(_nodes),
    );
  }

  AiTrajectoryTraceBuilder _add({
    required AiTrajectoryNodeKind kind,
    required String label,
    AiTrajectoryNodeStatus status = AiTrajectoryNodeStatus.succeeded,
    String? ref,
    String? summary,
    String? errorCode,
  }) {
    _nodes.add(
      AiTrajectoryNode(
        sequence: _nodes.length,
        kind: kind,
        status: status,
        label: label,
        ref: ref,
        summary: summary == null ? null : _redactor.redact(summary),
        errorCode: errorCode,
      ),
    );
    return this;
  }
}

/// Deterministic summary redactor for local trace logs.
class AiTraceRedactor {
  const AiTraceRedactor();

  String redact(String value) {
    var redacted = value;
    redacted = _replaceSecrets(redacted);
    redacted = _replaceFinance(redacted);
    redacted = _replaceHealth(redacted);
    redacted = _replaceMemory(redacted);
    return redacted;
  }

  String _replaceSecrets(String value) {
    return value
        .replaceAll(RegExp(r'sk-[A-Za-z0-9_-]+'), '[redacted:secret]')
        .replaceAll(
          RegExp(r'password\s+\S+', caseSensitive: false),
          '[redacted:secret]',
        )
        .replaceAll(
          RegExp(r'token\s+\S+', caseSensitive: false),
          '[redacted:secret]',
        );
  }

  String _replaceFinance(String value) {
    return value
        .replaceAll(RegExp(r'(?:\d[ -]?){13,19}'), '[redacted:finance]')
        .replaceAll(
          RegExp(r'\baccount\b[^,;.]*', caseSensitive: false),
          '[redacted:finance]',
        );
  }

  String _replaceHealth(String value) {
    return value.replaceAll(
      RegExp(
        r'\b(heart rate|blood pressure|medicine|medication|minoxidil|metformin)\b[^,;.]*',
        caseSensitive: false,
      ),
      '[redacted:health]',
    );
  }

  String _replaceMemory(String value) {
    return value
        .replaceAll(
          RegExp(r'\bmemory\b[^,;.]*', caseSensitive: false),
          '[redacted:memory]',
        )
        .replaceAll(
          RegExp(r'\bchildhood address\b', caseSensitive: false),
          '[redacted:memory]',
        );
  }
}
