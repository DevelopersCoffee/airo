abstract class EngineException implements Exception {
  const EngineException(this.message);
  final String message;
  
  @override
  String toString() => '$runtimeType: $message';
}

class EngineLoadException extends EngineException {
  const EngineLoadException(super.message);
}

class GenerationException extends EngineException {
  const GenerationException(super.message);
}

class CapabilityException extends EngineException {
  const CapabilityException(super.message);
}

class OutOfMemoryException extends EngineException {
  const OutOfMemoryException(super.message);
}

class CancellationException extends EngineException {
  const CancellationException(super.message);
}
