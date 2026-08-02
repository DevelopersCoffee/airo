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

  /// Human-readable planner facts for the Device Capability Report.
  ///
  /// This is intentionally derived from already collected facts. It performs no
  /// platform calls, so the screen can explain the current state without
  /// risking another stuck device probe.
  List<DeviceCapabilityDiagnostic> get diagnostics {
    final diagnostics = <DeviceCapabilityDiagnostic>[];
    if (!hasMemoryFacts) {
      diagnostics.add(
        const DeviceCapabilityDiagnostic(
          title: 'Memory probe unavailable',
          detail:
              'Airo could not read live transient memory. Model loading will run a final preflight before warm-up.',
          severity: MemorySeverity.warning,
        ),
      );
    } else {
      final availablePercent = memory.availablePercent;
      diagnostics.add(
        DeviceCapabilityDiagnostic(
          title: 'Transient memory',
          detail:
              '${memory.availableMB.toStringAsFixed(0)} MB is available right now. '
              'Airo checks this again immediately before loading a model.',
          severity: availablePercent >= 0.35
              ? MemorySeverity.safe
              : availablePercent >= 0.20
              ? MemorySeverity.warning
              : MemorySeverity.critical,
        ),
      );
    }

    diagnostics.add(
      DeviceCapabilityDiagnostic(
        title: 'On-device AI service',
        detail: device.supportsOnDeviceAI
            ? 'The platform reports an on-device AI service. Airo can consider it as a system-managed runtime when a model supports that path.'
            : 'The platform did not report a system-managed on-device AI service. Airo will prefer installed local runtimes and compatible model files.',
        severity: device.supportsOnDeviceAI
            ? MemorySeverity.safe
            : MemorySeverity.warning,
      ),
    );

    if (device.isPixelDevice) {
      diagnostics.add(
        const DeviceCapabilityDiagnostic(
          title: 'Pixel runtime profile',
          detail:
              'Pixel hardware is treated as a high-capability mobile profile, but Airo still validates the selected runtime and artifact before inference.',
          severity: MemorySeverity.safe,
        ),
      );
    }

    final blocked = recommendedModels
        .where((model) => model.severity == MemorySeverity.blocked)
        .length;
    final risky = recommendedModels
        .where((model) => model.severity == MemorySeverity.critical)
        .length;
    if (blocked > 0 || risky > 0) {
      diagnostics.add(
        DeviceCapabilityDiagnostic(
          title: 'Model fit warnings',
          detail: [
            if (risky > 0) '$risky model(s) may need reduced context',
            if (blocked > 0) '$blocked model(s) need a smaller plan or model',
          ].join(' · '),
          severity: blocked > 0
              ? MemorySeverity.blocked
              : MemorySeverity.critical,
        ),
      );
    }

    diagnostics.add(
      const DeviceCapabilityDiagnostic(
        title: 'Final runtime preflight',
        detail:
            'This report is advisory. The runtime still verifies storage, integrity, memory, and backend readiness before generation.',
        severity: MemorySeverity.safe,
      ),
    );

    return List.unmodifiable(diagnostics);
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
      final estimatedMemoryBytes = budget.estimateMemoryUsage(
        model.fileSizeBytes,
        _modelType(model),
      );
      final result = budget.checkMemoryForModel(estimatedMemoryBytes, memory);
      final estimatedMemoryMb = estimatedMemoryBytes / (1024 * 1024);
      recommendations.add(
        DeviceModelRecommendation(
          modelId: model.id,
          modelName: model.name,
          severity: result,
          estimatedMemoryMb: estimatedMemoryMb,
          expectedTokensPerSecond: _estimateTokensPerSecond(
            model: model,
            device: device,
            severity: result,
          ),
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

  static double _estimateTokensPerSecond({
    required OfflineModelInfo model,
    required DeviceInfo device,
    required MemorySeverity severity,
  }) {
    final sizeGb = model.fileSizeBytes / (1024 * 1024 * 1024);
    final normalizedSize = sizeGb.clamp(0.5, 8.0).toDouble();
    final deviceBase = device.isPixelDevice
        ? 24.0
        : device.supportsOnDeviceAI
        ? 18.0
        : 10.0;
    final severityMultiplier = switch (severity) {
      MemorySeverity.safe => 1.0,
      MemorySeverity.warning => 0.75,
      MemorySeverity.critical => 0.45,
      MemorySeverity.blocked => 0.20,
    };
    final modalityMultiplier =
        model.modalities.contains(ModelModality.image) ||
            model.modalities.contains(ModelModality.audio)
        ? 0.65
        : 1.0;
    final estimate = deviceBase * severityMultiplier * modalityMultiplier;
    return estimate / normalizedSize;
  }
}

@immutable
class DeviceModelRecommendation {
  const DeviceModelRecommendation({
    required this.modelId,
    required this.modelName,
    required this.severity,
    required this.estimatedMemoryMb,
    this.expectedTokensPerSecond,
  });

  final String modelId;
  final String modelName;
  final MemorySeverity severity;
  final double estimatedMemoryMb;
  final double? expectedTokensPerSecond;

  bool get recommended => severity.canLoad;
}

@immutable
class DeviceCapabilityDiagnostic {
  const DeviceCapabilityDiagnostic({
    required this.title,
    required this.detail,
    required this.severity,
  });

  final String title;
  final String detail;
  final MemorySeverity severity;
}
