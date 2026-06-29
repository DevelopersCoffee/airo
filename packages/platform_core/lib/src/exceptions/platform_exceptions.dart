class PlatformException implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const PlatformException(this.message, [this.cause, this.stackTrace]);

  @override
  String toString() => 'PlatformException: $message${cause != null ? ' (Cause: $cause)' : ''}';
}

class InitializationException extends PlatformException {
  const InitializationException(super.message, [super.cause, super.stackTrace]);
}

class ConfigurationException extends PlatformException {
  const ConfigurationException(super.message, [super.cause, super.stackTrace]);
}

class DependencyException extends PlatformException {
  const DependencyException(super.message, [super.cause, super.stackTrace]);
}

class LifecycleException extends PlatformException {
  const LifecycleException(super.message, [super.cause, super.stackTrace]);
}
