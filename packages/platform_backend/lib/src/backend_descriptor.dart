
import 'package:platform_execution/platform_execution.dart';

class BackendDescriptor {
  final List<WorkloadType> supportedWorkloads;
  final List<String> supportedFormats;
  final List<String> supportedAccelerators;
  
  final Duration coldStartCost;
  final Duration warmStartCost;
  final int averageMemoryBytes;
  final int peakMemoryBytes;
  
  final bool threadSafety;
  final bool zeroCopySupport;
  final int preferredBatchSize;
  final Duration streamingLatency;
  final int expectedThroughput;
  
  final bool streamingSupport;
  final bool batchingSupport;
  final bool quantizationSupport;
  final List<String> platformSupport;
  final Priority priority;

  BackendDescriptor({
    required this.supportedWorkloads,
    required this.supportedFormats,
    required this.supportedAccelerators,
    this.coldStartCost = const Duration(milliseconds: 500),
    this.warmStartCost = const Duration(milliseconds: 10),
    this.averageMemoryBytes = 0,
    this.peakMemoryBytes = 0,
    this.threadSafety = false,
    this.zeroCopySupport = false,
    this.preferredBatchSize = 1,
    this.streamingLatency = const Duration(milliseconds: 50),
    this.expectedThroughput = 0,
    required this.streamingSupport,
    required this.batchingSupport,
    required this.quantizationSupport,
    required this.platformSupport,
    required this.priority,
  });
}
