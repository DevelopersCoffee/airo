/// Base class for all strongly typed platform identifiers.
abstract class PlatformIdentifier {
  const PlatformIdentifier(this.value);
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlatformIdentifier && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode ^ runtimeType.hashCode;

  @override
  String toString() => '$runtimeType($value)';
}

/// Identifies an extension (plugin, feature, tool provider).
class ExtensionId extends PlatformIdentifier {
  const ExtensionId(super.value);
}

/// Identifies an executable tool.
class ToolId extends PlatformIdentifier {
  const ToolId(super.value);
}

/// Identifies a specific AI engine.
class EngineId extends PlatformIdentifier {
  const EngineId(super.value);
}

/// Identifies a runtime environment.
class RuntimeId extends PlatformIdentifier {
  const RuntimeId(super.value);
}

/// Identifies an active workflow.
class WorkflowId extends PlatformIdentifier {
  const WorkflowId(super.value);
}

/// Identifies a unit of knowledge.
class KnowledgeId extends PlatformIdentifier {
  const KnowledgeId(super.value);
}

/// Identifies a persistent memory element.
class MemoryId extends PlatformIdentifier {
  const MemoryId(super.value);
}

/// Identifies a distinct workspace.
class WorkspaceId extends PlatformIdentifier {
  const WorkspaceId(super.value);
}

/// Identifies a conversation.
class ConversationId extends PlatformIdentifier {
  const ConversationId(super.value);
}

/// Identifies an active session.
class SessionId extends PlatformIdentifier {
  const SessionId(super.value);
}
