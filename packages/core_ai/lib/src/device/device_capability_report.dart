import 'package:meta/meta.dart';

import '../models/offline_model_info.dart';
import 'device_capability_service.dart';
import 'memory_severity.dart';
import 'memory_budget_manager.dart';

/// A stable, user-facing snapshot of the hardware facts used by Airo's
/// planner. It deliberately contains no raw platform handles or file paths.
@immutable
class DeviceCapabilityReport {
  const DeviceCapabilityReport({
    required this.device,
    required this.memory,
    required this.recommendedModels,
    required this.generatedAt,
  });

  final DeviceInfo device;
  final MemoryInfo memory;
  final List<DeviceModelRecommendation> recommendedModels;
  final DateTime generatedAt;

  bool get hasMemoryFacts => memory.isAvailable;

  String get summary {
    if (!hasMemoryFacts) return 'Memory information is currently unavailable.';
    return '${memory.availableMB.toStringAsFixed(0)} MB available of '
        '${memory.totalMB.toStringAsFixed(0)} MB total.';
  }

  static Future<DeviceCapabilityReport> collect({
    Iterable<OfflineModelInfo> models = const <OfflineModelInfo>[],
    DeviceCapabilityService? service,
    DateTime? now,
  }) async {
    final probe = service ?? DeviceCapabilityService();
    final device = await probe.getDeviceInfo();
    final memory = await probe.getMemoryInfo(forceRefresh: true);
    final budget = MemoryBudgetManager(deviceCapability: probe);
    final recommendations = <DeviceModelRecommendation>[];
    for (final model in models) {
      final result = budget.checkMemoryForModel(
        budget.estimateMemoryUsage(model.fileSizeBytes, _modelType(model)),
        memory,
      );
      recommendations.add(
        DeviceModelRecommendation(
          modelId: model.id,
          modelName: model.name,
          severity: result,
          estimatedMemoryMb:
              budget.estimateMemoryUsage(
                model.fileSizeBytes,
                _modelType(model),
              ) /
              (1024 * 1024),
        ),
      );
    }
    recommendations.sort(
      (a, b) => a.severity.index.compareTo(b.severity.index),
    );
    return DeviceCapabilityReport(
      device: device,
      memory: memory,
      recommendedModels: List.unmodifiable(recommendations),
      generatedAt: now ?? DateTime.now(),
    );
  }

  static ModelType _modelType(OfflineModelInfo model) {
    if (model.modalities.contains(ModelModality.image) &&
        model.modalities.contains(ModelModality.audio)) {
      return ModelType.multimodal;
    }
    if (model.modalities.contains(ModelModality.image)) return ModelType.image;
    if (model.modalities.contains(ModelModality.audio)) return ModelType.audio;
    return ModelType.text;
  }
}

@immutable
class DeviceModelRecommendation {
  const DeviceModelRecommendation({
    required this.modelId,
    required this.modelName,
    required this.severity,
    required this.estimatedMemoryMb,
  });

  final String modelId;
  final String modelName;
  final MemorySeverity severity;
  final double estimatedMemoryMb;

  bool get recommended => severity.canLoad;
}
