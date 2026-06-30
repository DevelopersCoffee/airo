
import 'package:platform_execution/platform_execution.dart';
import 'package:platform_identity/platform_identity.dart';
import 'package:platform_provider/platform_provider.dart';

enum AcceleratorAffinity {
  preferred,
  allowed,
  forbidden
}

class BackendDescriptor extends ProviderDescriptor {
  final List<WorkloadType> supportedWorkloads;
  final Map<String, AcceleratorAffinity> acceleratorAffinity;
  
  final Duration coldStartCost;
  final Duration warmStartCost;
  final int averageMemoryBytes;
  final int peakMemoryBytes;
  
  final bool threadSafety;
  final bool zeroCopySupport;
  final Duration streamingLatency;
  final int expectedThroughput;
  
  final bool streamingSupport;
  final bool quantizationSupport;

  const BackendDescriptor({
    required super.id,
    required super.version,
    required super.priority,
    required super.capabilities,
    required super.supportedFormats,
    required super.supportedPlatforms,
    required this.supportedWorkloads,
    required this.acceleratorAffinity,
    this.coldStartCost = const Duration(milliseconds: 500),
    this.warmStartCost = const Duration(milliseconds: 10),
    this.averageMemoryBytes = 0,
    this.peakMemoryBytes = 0,
    this.threadSafety = false,
    this.zeroCopySupport = false,
    this.streamingLatency = const Duration(milliseconds: 50),
    this.expectedThroughput = 0,
    required this.streamingSupport,
    required this.quantizationSupport,
  });
}
