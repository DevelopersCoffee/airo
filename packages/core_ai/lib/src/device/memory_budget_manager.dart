import 'device_capability_service.dart';
import 'memory_severity.dart';

/// Model type for memory overhead calculation.
enum ModelType {
  /// Text-only models (LLMs, chat models).
  text,

  /// Image/vision models (higher memory overhead).
  image,

  /// Audio/speech models.
  audio,

  /// Multi-modal models (text + image + audio).
  multimodal,
}

/// Manages memory budget for LLM model loading.
///
/// Implements the 60% RAM budget pattern from offline-mobile-llm-manager:
/// - 60% of total RAM is the safe budget for model loading
/// - Warning threshold at 50% usage of budget
/// - Different overhead multipliers for text vs image models
///
/// Reference: https://github.com/alichherawalla/offline-mobile-llm-manager
class MemoryBudgetManager {
  final DeviceCapabilityService _deviceCapability;

  /// Maximum percentage of total RAM to use for models (60%).
  static const double memoryBudgetPercent = 0.60;

  /// Warning threshold as percentage of budget (50% of budget = 30% of total).
  static const double warningThresholdPercent = 0.50;

  /// Critical threshold as percentage of budget (80% of budget = 48% of total).
  static const double criticalThresholdPercent = 0.80;

  /// Memory overhead multiplier for text models.
  /// Model file size × 1.5 = estimated runtime memory.
  static const double textModelOverhead = 1.5;

  /// Memory overhead multiplier for image/vision models.
  /// Higher due to image buffer requirements.
  static const double imageModelOverhead = 1.8;

  /// Memory overhead multiplier for audio models.
  static const double audioModelOverhead = 1.6;

  /// Memory overhead multiplier for multimodal models.
  static const double multimodalModelOverhead = 2.0;

  MemoryBudgetManager({DeviceCapabilityService? deviceCapability})
      : _deviceCapability = deviceCapability ?? DeviceCapabilityService();

  /// Estimates the runtime memory usage for a model.
  ///
  /// [fileSizeBytes] - The model file size in bytes.
  /// [type] - The type of model (affects overhead multiplier).
  ///
  /// Returns estimated memory usage in bytes.
  int estimateMemoryUsage(int fileSizeBytes, ModelType type) {
    final overhead = _getOverheadMultiplier(type);
    return (fileSizeBytes * overhead).round();
  }

  /// Gets the overhead multiplier for a model type.
  double _getOverheadMultiplier(ModelType type) {
    switch (type) {
      case ModelType.text:
        return textModelOverhead;
      case ModelType.image:
        return imageModelOverhead;
      case ModelType.audio:
        return audioModelOverhead;
      case ModelType.multimodal:
        return multimodalModelOverhead;
    }
  }

  /// Calculates the memory budget in bytes.
  int calculateBudget(MemoryInfo memoryInfo) {
    return (memoryInfo.totalBytes * memoryBudgetPercent).round();
  }

  /// Checks if a model can be loaded given current memory conditions.
  ///
  /// [estimatedUsageBytes] - Estimated memory usage from [estimateMemoryUsage].
  /// [memoryInfo] - Current device memory info.
  ///
  /// Returns the severity level for loading this model.
  MemorySeverity checkMemoryForModel(
    int estimatedUsageBytes,
    MemoryInfo memoryInfo,
  ) {
    if (!memoryInfo.isAvailable) {
      // If we can't determine memory, be conservative
      return MemorySeverity.warning;
    }

    final budget = calculateBudget(memoryInfo);

    // Check if model would exceed available memory
    if (estimatedUsageBytes > memoryInfo.availableBytes) {
      return MemorySeverity.blocked;
    }

    // Check against budget thresholds
    final usagePercent = estimatedUsageBytes / budget;

    if (usagePercent <= warningThresholdPercent) {
      return MemorySeverity.safe;
    } else if (usagePercent <= criticalThresholdPercent) {
      return MemorySeverity.warning;
    } else if (usagePercent <= 1.0) {
      return MemorySeverity.critical;
    } else {
      return MemorySeverity.blocked;
    }
  }

  /// Checks memory for loading a model file.
  ///
  /// Convenience method that combines file size estimation and memory check.
  Future<MemoryCheckResult> checkModelFile({
    required int fileSizeBytes,
    required ModelType type,
    bool forceRefresh = false,
  }) async {
    final memoryInfo =
        await _deviceCapability.getMemoryInfo(forceRefresh: forceRefresh);
    final estimatedUsage = estimateMemoryUsage(fileSizeBytes, type);
    final severity = checkMemoryForModel(estimatedUsage, memoryInfo);
    final budget = calculateBudget(memoryInfo);

    return MemoryCheckResult(
      severity: severity,
      memoryInfo: memoryInfo,
      estimatedUsageBytes: estimatedUsage,
      budgetBytes: budget,
      modelType: type,
    );
  }

  /// Gets current memory status without checking a specific model.
  Future<MemoryInfo> getCurrentMemoryInfo({bool forceRefresh = false}) {
    return _deviceCapability.getMemoryInfo(forceRefresh: forceRefresh);
  }
}

/// Result of a memory check for model loading.
class MemoryCheckResult {
  final MemorySeverity severity;
  final MemoryInfo memoryInfo;
  final int estimatedUsageBytes;
  final int budgetBytes;
  final ModelType modelType;

  const MemoryCheckResult({
    required this.severity,
    required this.memoryInfo,
    required this.estimatedUsageBytes,
    required this.budgetBytes,
    required this.modelType,
  });

  /// Whether the model can be loaded.
  bool get canLoad => severity.canLoad;

  /// Whether the user should be warned before loading.
  bool get shouldWarn => severity.shouldWarn;

  /// Estimated usage as percentage of budget.
  double get usagePercentOfBudget =>
      budgetBytes > 0 ? estimatedUsageBytes / budgetBytes : 0.0;

  /// Estimated usage in megabytes.
  double get estimatedUsageMB => estimatedUsageBytes / (1024 * 1024);

  /// Budget in megabytes.
  double get budgetMB => budgetBytes / (1024 * 1024);

  @override
  String toString() {
    return 'MemoryCheckResult(severity: $severity, '
        'usage: ${estimatedUsageMB.toStringAsFixed(0)}MB / '
        '${budgetMB.toStringAsFixed(0)}MB budget)';
  }
}

