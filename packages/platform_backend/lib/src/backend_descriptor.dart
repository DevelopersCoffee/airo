
import 'package:platform_execution/platform_execution.dart';

class BackendDescriptor {
  final List<WorkloadType> supportedWorkloads;
  final List<String> supportedFormats;
  final List<String> supportedAccelerators;
  final String memoryCharacteristics;
  final bool streamingSupport;
  final bool batchingSupport;
  final bool quantizationSupport;
  final List<String> platformSupport;
  final Priority priority;

  BackendDescriptor({
    required this.supportedWorkloads,
    required this.supportedFormats,
    required this.supportedAccelerators,
    required this.memoryCharacteristics,
    required this.streamingSupport,
    required this.batchingSupport,
    required this.quantizationSupport,
    required this.platformSupport,
    required this.priority,
  });
}
