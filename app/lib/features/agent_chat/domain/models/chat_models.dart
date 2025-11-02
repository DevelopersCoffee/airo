import 'package:equatable/equatable.dart';

/// Chat conversation model
class ChatConversation extends Equatable {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<ChatMessage> messages;

  const ChatConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    this.updatedAt,
    this.messages = const [],
  });

  @override
  List<Object?> get props => [id, title, createdAt, updatedAt, messages];
}

/// Chat message model
class ChatMessage extends Equatable {
  final String id;
  final String conversationId;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final List<ToolCall>? toolCalls;
  final String? toolResult;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.timestamp,
    this.toolCalls,
    this.toolResult,
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get hasToolCalls => toolCalls != null && toolCalls!.isNotEmpty;

  @override
  List<Object?> get props => [
    id,
    conversationId,
    role,
    content,
    timestamp,
    toolCalls,
    toolResult,
  ];
}

/// Tool call model
class ToolCall extends Equatable {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  const ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  @override
  List<Object?> get props => [id, name, arguments];
}

/// Tool result model
class ToolResult extends Equatable {
  final String toolCallId;
  final String result;
  final bool isError;

  const ToolResult({
    required this.toolCallId,
    required this.result,
    this.isError = false,
  });

  @override
  List<Object?> get props => [toolCallId, result, isError];
}
