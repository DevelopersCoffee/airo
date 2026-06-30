class ToolRequest {

  const ToolRequest({
    required this.invocationId,
    required this.caller,
    required this.workspaceId,
    required this.sessionId,
    required this.timestamp,
    required this.payload,
    this.executionContext = const {},
  });
  final String invocationId;
  final String caller;
  final String workspaceId;
  final String sessionId;
  final DateTime timestamp;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> executionContext;
}

class ToolResult {

  const ToolResult({
    required this.status,
    required this.payload,
    required this.diagnostics,
    required this.executionTime,
    this.warnings = const [],
  });
  final String status;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> diagnostics;
  final Duration executionTime;
  final List<String> warnings;
}

class ToolEvent {

  const ToolEvent({
    required this.type,
    required this.data,
    required this.timestamp,
  });
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
}
