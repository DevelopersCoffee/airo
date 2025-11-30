/// Logging infrastructure for prompt execution and regression detection.
///
/// Tracks prompt executions with inputs, outputs, and metadata for
/// debugging and regression detection.

/// A single prompt execution log entry.
class PromptExecutionLog {
  /// Unique ID for this execution.
  final String executionId;

  /// The prompt template ID (e.g., 'diet.coach.v1').
  final String promptId;

  /// The prompt version.
  final int promptVersion;

  /// Variables used to render the prompt.
  final Map<String, dynamic> variables;

  /// The rendered prompt sent to the LLM.
  final String renderedPrompt;

  /// The LLM response.
  final String? response;

  /// Whether the execution was successful.
  final bool success;

  /// Error message if execution failed.
  final String? errorMessage;

  /// Execution duration in milliseconds.
  final int durationMs;

  /// Timestamp of execution.
  final DateTime timestamp;

  /// Which AI provider was used (nano, cloud).
  final String provider;

  /// Additional metadata.
  final Map<String, dynamic> metadata;

  const PromptExecutionLog({
    required this.executionId,
    required this.promptId,
    required this.promptVersion,
    required this.variables,
    required this.renderedPrompt,
    this.response,
    required this.success,
    this.errorMessage,
    required this.durationMs,
    required this.timestamp,
    required this.provider,
    this.metadata = const {},
  });

  /// Convert to JSON for storage.
  Map<String, dynamic> toJson() {
    return {
      'executionId': executionId,
      'promptId': promptId,
      'promptVersion': promptVersion,
      'variables': variables,
      'renderedPrompt': renderedPrompt,
      'response': response,
      'success': success,
      'errorMessage': errorMessage,
      'durationMs': durationMs,
      'timestamp': timestamp.toIso8601String(),
      'provider': provider,
      'metadata': metadata,
    };
  }

  /// Create from JSON.
  factory PromptExecutionLog.fromJson(Map<String, dynamic> json) {
    return PromptExecutionLog(
      executionId: json['executionId'] as String,
      promptId: json['promptId'] as String,
      promptVersion: json['promptVersion'] as int,
      variables: Map<String, dynamic>.from(json['variables'] ?? {}),
      renderedPrompt: json['renderedPrompt'] as String,
      response: json['response'] as String?,
      success: json['success'] as bool,
      errorMessage: json['errorMessage'] as String?,
      durationMs: json['durationMs'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      provider: json['provider'] as String,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
}

/// Interface for prompt execution logging.
abstract class PromptLogger {
  /// Log a prompt execution.
  Future<void> log(PromptExecutionLog entry);

  /// Get logs for a specific prompt ID.
  Future<List<PromptExecutionLog>> getLogsForPrompt(
    String promptId, {
    int? limit,
    DateTime? since,
  });

  /// Get all logs within a time range.
  Future<List<PromptExecutionLog>> getLogs({
    DateTime? since,
    DateTime? until,
    int? limit,
  });

  /// Get failed executions for regression detection.
  Future<List<PromptExecutionLog>> getFailedExecutions({
    String? promptId,
    DateTime? since,
    int? limit,
  });

  /// Clear old logs.
  Future<void> clearOldLogs(Duration olderThan);
}

/// In-memory implementation of PromptLogger for testing.
class InMemoryPromptLogger implements PromptLogger {
  final List<PromptExecutionLog> _logs = [];

  /// Get all logs (for testing).
  List<PromptExecutionLog> get logs => List.unmodifiable(_logs);

  @override
  Future<void> log(PromptExecutionLog entry) async {
    _logs.add(entry);
  }

  @override
  Future<List<PromptExecutionLog>> getLogsForPrompt(
    String promptId, {
    int? limit,
    DateTime? since,
  }) async {
    var filtered = _logs.where((l) => l.promptId == promptId);
    if (since != null) {
      filtered = filtered.where((l) => l.timestamp.isAfter(since));
    }
    final sorted = filtered.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return limit != null ? sorted.take(limit).toList() : sorted;
  }

  @override
  Future<List<PromptExecutionLog>> getLogs({
    DateTime? since,
    DateTime? until,
    int? limit,
  }) async {
    var filtered = _logs.where((l) => true);
    if (since != null) {
      filtered = filtered.where((l) => l.timestamp.isAfter(since));
    }
    if (until != null) {
      filtered = filtered.where((l) => l.timestamp.isBefore(until));
    }
    final sorted = filtered.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return limit != null ? sorted.take(limit).toList() : sorted;
  }

  @override
  Future<List<PromptExecutionLog>> getFailedExecutions({
    String? promptId,
    DateTime? since,
    int? limit,
  }) async {
    var filtered = _logs.where((l) => !l.success);
    if (promptId != null) {
      filtered = filtered.where((l) => l.promptId == promptId);
    }
    if (since != null) {
      filtered = filtered.where((l) => l.timestamp.isAfter(since));
    }
    final sorted = filtered.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return limit != null ? sorted.take(limit).toList() : sorted;
  }

  @override
  Future<void> clearOldLogs(Duration olderThan) async {
    final cutoff = DateTime.now().subtract(olderThan);
    _logs.removeWhere((l) => l.timestamp.isBefore(cutoff));
  }

  /// Clear all logs (for testing).
  void clear() => _logs.clear();
}

