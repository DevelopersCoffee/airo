/// Base class for all platform exceptions.
abstract class PlatformException implements Exception {
  const PlatformException(this.message, {this.cause});
  
  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message${cause != null ? ' (caused by: $cause)' : ''}';
}

/// Thrown when validation fails (manifests, architecture, etc.).
class ValidationException extends PlatformException {
  const ValidationException(super.message, {super.cause});
}

/// Thrown for general runtime execution errors.
class RuntimeException extends PlatformException {
  const RuntimeException(super.message, {super.cause});
}

/// Thrown by specific inference engines.
class EngineException extends PlatformException {
  const EngineException(super.message, {super.cause});
}

/// Thrown during tool execution.
class ToolException extends PlatformException {
  const ToolException(super.message, {super.cause});
}

/// Thrown during protocol communication.
class ProtocolException extends PlatformException {
  const ProtocolException(super.message, {super.cause});
}

/// Thrown during composition or feature loading.
class CompositionException extends PlatformException {
  const CompositionException(super.message, {super.cause});
}

/// Thrown for capability or requirement negotiation failures.
class CapabilityException extends PlatformException {
  const CapabilityException(super.message, {super.cause});
}
