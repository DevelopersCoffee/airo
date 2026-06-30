import 'package:platform_identity/platform_identity.dart';

class ParserCapability {
  const ParserCapability({
    required this.priority,
    required this.cost,
    required this.quality,
    required this.streaming,
    required this.parallelism,
    required this.native,
    required this.incremental,
  });
  final int priority;
  final int cost;
  final int quality;
  final bool streaming;
  final int parallelism;
  final bool native;
  final bool incremental;
}

class CompatibilityMatrix {
  const CompatibilityMatrix({
    this.streaming = false,
    this.incremental = false,
    this.parallel = false,
    this.native = false,
    this.supportedFormats = const [],
    this.unsupportedFeatures = const [],
  });

  final bool streaming;
  final bool incremental;
  final bool parallel;
  final bool native;
  final List<String> supportedFormats;
  final List<String> unsupportedFeatures;
}

class ProviderScore {
  const ProviderScore({
    this.initializationCostMs = 0,
    this.steadyStateThroughput = 0,
    this.memoryFragmentationPct = 0.0,
    this.thermalBehavior = 0.0,
    this.batteryConsumption = 0.0,
    this.historicalReliability = 1.0,
    this.crashFrequency = 0.0,
    this.modelCompatibility = const [],
    this.preferredHardware = const [],
  });

  final int initializationCostMs;
  final int steadyStateThroughput;
  final double memoryFragmentationPct;
  final double thermalBehavior;
  final double batteryConsumption;
  final double historicalReliability;
  final double crashFrequency;
  final List<String> modelCompatibility;
  final List<String> preferredHardware;
}

class ExecutionMetadata {
  const ExecutionMetadata({
    this.implementationLanguage = 'dart',
    this.device = 'cpu',
    this.streaming = false,
    this.incremental = false,
    this.threadSafety = false,
    this.platformSupport = const [],
    this.score = const ProviderScore(),
  });

  final String implementationLanguage;
  final String device;
  final bool streaming;
  final bool incremental;
  final bool threadSafety;
  final List<String> platformSupport;
  
  final ProviderScore score;
}

class ProviderDescriptor {
  const ProviderDescriptor({
    required this.id,
    required this.version,
    required this.priority,
    required this.capabilities,
    this.compatibility = const CompatibilityMatrix(),
    this.executionMetadata = const ExecutionMetadata(),
    this.parserCapability,
  });

  final ProviderId id;
  final String version;
  final int priority;
  final List<String> capabilities;
  final CompatibilityMatrix compatibility;
  final ExecutionMetadata executionMetadata;
  final ParserCapability? parserCapability;
}
