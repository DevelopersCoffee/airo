/// Memory severity levels for LLM model loading.
///
/// Used to indicate how safe it is to load a model given current memory conditions.
/// Based on patterns from offline-mobile-llm-manager.
enum MemorySeverity {
  /// Model can be loaded safely with plenty of memory headroom.
  /// Usage is below 50% of total RAM budget.
  safe('Safe to load', 'Plenty of memory available'),

  /// Model can be loaded but with caution.
  /// Usage is between 50-80% of total RAM budget.
  warning('Load with caution', 'Memory usage is moderate'),

  /// Model loading is risky and may cause performance issues.
  /// Usage is between 80-100% of total RAM budget.
  critical('High risk', 'Memory usage is high, may cause slowdowns'),

  /// Model cannot be loaded - would exceed memory budget.
  /// Usage would exceed 100% of total RAM budget.
  blocked('Cannot load', 'Insufficient memory for this model');

  const MemorySeverity(this.title, this.description);

  /// Human-readable title for UI display.
  final String title;

  /// Detailed description of the severity level.
  final String description;

  /// Returns true if the model can be loaded (safe, warning, or critical).
  bool get canLoad => this != blocked;

  /// Returns true if the user should be warned before loading.
  bool get shouldWarn => this == warning || this == critical;

  /// Returns true if the severity level is risky.
  bool get isRisky => this == critical || this == blocked;
}

/// Memory information snapshot from the device.
class MemoryInfo {
  /// Total RAM in bytes.
  final int totalBytes;

  /// Available (free) RAM in bytes.
  final int availableBytes;

  /// RAM currently in use in bytes.
  int get usedBytes => totalBytes - availableBytes;

  /// Memory usage as a percentage (0.0 - 1.0).
  double get usagePercent =>
      totalBytes > 0 ? usedBytes / totalBytes : 0.0;

  /// Available memory as a percentage (0.0 - 1.0).
  double get availablePercent =>
      totalBytes > 0 ? availableBytes / totalBytes : 0.0;

  const MemoryInfo({
    required this.totalBytes,
    required this.availableBytes,
  });

  /// Creates a MemoryInfo from megabytes.
  factory MemoryInfo.fromMegabytes({
    required double totalMB,
    required double availableMB,
  }) {
    return MemoryInfo(
      totalBytes: (totalMB * 1024 * 1024).round(),
      availableBytes: (availableMB * 1024 * 1024).round(),
    );
  }

  /// Creates an unknown/unavailable memory info.
  factory MemoryInfo.unknown() {
    return const MemoryInfo(totalBytes: 0, availableBytes: 0);
  }

  /// Whether memory info is available.
  bool get isAvailable => totalBytes > 0;

  /// Total RAM in megabytes.
  double get totalMB => totalBytes / (1024 * 1024);

  /// Available RAM in megabytes.
  double get availableMB => availableBytes / (1024 * 1024);

  /// Used RAM in megabytes.
  double get usedMB => usedBytes / (1024 * 1024);

  /// Total RAM in gigabytes.
  double get totalGB => totalBytes / (1024 * 1024 * 1024);

  /// Available RAM in gigabytes.
  double get availableGB => availableBytes / (1024 * 1024 * 1024);

  @override
  String toString() {
    return 'MemoryInfo(total: ${totalGB.toStringAsFixed(1)}GB, '
        'available: ${availableGB.toStringAsFixed(1)}GB, '
        'used: ${(usagePercent * 100).toStringAsFixed(1)}%)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MemoryInfo &&
        other.totalBytes == totalBytes &&
        other.availableBytes == availableBytes;
  }

  @override
  int get hashCode => Object.hash(totalBytes, availableBytes);
}

