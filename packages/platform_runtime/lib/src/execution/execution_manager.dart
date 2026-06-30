
import '../registry/runtime_registries.dart';
import 'package:platform_identity/platform_identity.dart';

class TaskRequirements {
  final bool requiresStreaming;
  final bool preferGpu;
  final bool lowMemory;
  final List<String> requiredCapabilities;
  TaskRequirements({this.requiresStreaming = false, this.preferGpu = false, this.lowMemory = false, this.requiredCapabilities = const []});
}

abstract class LanguageBackend {
  String get name;
}

abstract class InferenceProvider {
  String get name;
}

abstract class HardwareDelegate {
  String get name;
}

class ExecutionPipeline {
  final LanguageBackend backend;
  final InferenceProvider provider;
  final HardwareDelegate delegate;
  ExecutionPipeline({required this.backend, required this.provider, required this.delegate});
}

abstract class CapabilityResolver {
  ExecutionPipeline resolve(TaskRequirements requirements);
}

abstract class ExecutionManager {
  CapabilityResolver get resolver;
  Future<void> execute(PlatformIdentifier taskId, TaskRequirements requirements);
}
