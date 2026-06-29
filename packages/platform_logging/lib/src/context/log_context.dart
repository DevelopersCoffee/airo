import 'package:equatable/equatable.dart';

class LogContext extends Equatable {
  final String? sessionId;
  final String? workspaceId;
  final String? conversationId;
  final String? requestId;
  final String? workflowId;
  final String? correlationId;

  const LogContext({
    this.sessionId,
    this.workspaceId,
    this.conversationId,
    this.requestId,
    this.workflowId,
    this.correlationId,
  });

  LogContext copyWith({
    String? sessionId,
    String? workspaceId,
    String? conversationId,
    String? requestId,
    String? workflowId,
    String? correlationId,
  }) {
    return LogContext(
      sessionId: sessionId ?? this.sessionId,
      workspaceId: workspaceId ?? this.workspaceId,
      conversationId: conversationId ?? this.conversationId,
      requestId: requestId ?? this.requestId,
      workflowId: workflowId ?? this.workflowId,
      correlationId: correlationId ?? this.correlationId,
    );
  }

  @override
  List<Object?> get props => [
    sessionId,
    workspaceId,
    conversationId,
    requestId,
    workflowId,
    correlationId,
  ];
}
