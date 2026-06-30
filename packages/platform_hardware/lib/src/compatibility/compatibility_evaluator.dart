// ignore_for_file: one_member_abstracts
import 'package:platform_hardware/src/platform/hardware_profile.dart';
import 'package:platform_models/platform_models.dart';

class CompatibilityReport {

  const CompatibilityReport({
    required this.isCompatible,
    required this.compatibilityScore,
    this.blockingReasons = const [],
    this.warnings = const [],
    this.recommendedRuntime = 'cpu',
    this.recommendedQuantization = 'none',
    this.estimatedMemoryUsageMb = 0,
  });
  final bool isCompatible;
  final double compatibilityScore;
  final List<String> blockingReasons;
  final List<String> warnings;
  final String recommendedRuntime;
  final String recommendedQuantization;
  final int estimatedMemoryUsageMb;
}

abstract interface class CompatibilityEvaluator {
  CompatibilityReport evaluate(HardwareProfile profile, ModelDescriptor model);
}

class DefaultCompatibilityEvaluator implements CompatibilityEvaluator {
  @override
  CompatibilityReport evaluate(HardwareProfile profile, ModelDescriptor model) {
    final blockingReasons = <String>[];
    final warnings = <String>[];
    
    // RAM check
    final availableRam = profile.availableMemoryMb.value;
    if (availableRam < model.minimumRamMb) {
      blockingReasons.add('Insufficient RAM. Required: ${model.minimumRamMb} MB, Available: $availableRam MB.');
    } else if (availableRam < (model.minimumRamMb * 1.2).toInt()) {
      warnings.add('RAM is very tight, performance may degrade.');
    }

    // Check Storage
    final requiredStorageMb = model.downloadManifest.totalSizeInBytes ~/ (1024 * 1024);
    if (profile.availableStorageMb.value < requiredStorageMb) {
      blockingReasons.add('Insufficient storage. Required: $requiredStorageMb MB, Available: ${profile.availableStorageMb.value} MB.');
    }

    // Runtime resolution
    var runtime = 'cpu';
    if (profile.supportsGPUInference && profile.gpu.value.supported) {
      runtime = profile.gpu.value.backend;
    } else if (profile.supportsCoreML && profile.npu.value.supported) {
      runtime = profile.npu.value.backend;
    }

    // Score calculation
    double score = 1;
    if (blockingReasons.isNotEmpty) {
      score = 0;
    } else {
      if (runtime != 'cpu') score += 0.2; // Bonus for acceleration
      if (availableRam > model.minimumRamMb * 2) score += 0.1; // Bonus for lots of ram
    }

    // Rough memory estimate
    final estimatedMemory = (model.parameterCount * 0.75) ~/ (1024 * 1024); // heuristic for Q4

    return CompatibilityReport(
      isCompatible: blockingReasons.isEmpty,
      compatibilityScore: score > 1 ? 1 : score,
      blockingReasons: blockingReasons,
      warnings: warnings,
      recommendedRuntime: runtime,
      recommendedQuantization: model.quantization,
      estimatedMemoryUsageMb: estimatedMemory,
    );
  }
}
