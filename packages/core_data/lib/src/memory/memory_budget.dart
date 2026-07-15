import 'device_class.dart';

/// Byte-size constants used in budget definitions.
const int _MB = 1024 * 1024;

/// Per-device-class memory budget that constrains image caching, channel list
/// sizes, and overall RSS targets.
///
/// Obtain a budget via [MemoryBudget.forDevice]. The values are deliberately
/// conservative for low-end tiers and generous for desktop to maximize UX
/// without OOM-killing the process on constrained hardware.
class MemoryBudget {
  /// Maximum bytes the image cache may occupy.
  final int imageCacheBytes;

  /// Maximum number of images held in the cache.
  final int imageCacheCount;

  /// Upper bound on the number of channels kept in memory at once.
  final int maxChannelListSize;

  /// Target RSS (resident set size) the app should stay below during normal
  /// operation.
  final int rssTargetBytes;

  /// Absolute peak RSS the app must never exceed.
  final int rssPeakBytes;

  const MemoryBudget({
    required this.imageCacheBytes,
    required this.imageCacheCount,
    required this.maxChannelListSize,
    required this.rssTargetBytes,
    required this.rssPeakBytes,
  });

  /// Return the memory budget for the given [DeviceClass].
  static MemoryBudget forDevice(DeviceClass dc) => switch (dc) {
    DeviceClass.tvLow => const MemoryBudget(
      imageCacheBytes: 30 * _MB,
      imageCacheCount: 100,
      maxChannelListSize: 5000,
      rssTargetBytes: 200 * _MB,
      rssPeakBytes: 300 * _MB,
    ),
    DeviceClass.tvMid => const MemoryBudget(
      imageCacheBytes: 50 * _MB,
      imageCacheCount: 200,
      maxChannelListSize: 20000,
      rssTargetBytes: 300 * _MB,
      rssPeakBytes: 450 * _MB,
    ),
    DeviceClass.mobileLow => const MemoryBudget(
      imageCacheBytes: 30 * _MB,
      imageCacheCount: 150,
      maxChannelListSize: 5000,
      rssTargetBytes: 150 * _MB,
      rssPeakBytes: 250 * _MB,
    ),
    DeviceClass.mobileMid => const MemoryBudget(
      imageCacheBytes: 80 * _MB,
      imageCacheCount: 300,
      maxChannelListSize: 20000,
      rssTargetBytes: 250 * _MB,
      rssPeakBytes: 400 * _MB,
    ),
    DeviceClass.mobileHigh => const MemoryBudget(
      imageCacheBytes: 100 * _MB,
      imageCacheCount: 500,
      maxChannelListSize: 50000,
      rssTargetBytes: 400 * _MB,
      rssPeakBytes: 600 * _MB,
    ),
    DeviceClass.desktop => const MemoryBudget(
      imageCacheBytes: 200 * _MB,
      imageCacheCount: 1000,
      maxChannelListSize: 100000,
      rssTargetBytes: 800 * _MB,
      rssPeakBytes: 1200 * _MB,
    ),
  };

  @override
  String toString() =>
      'MemoryBudget(imageCache: ${imageCacheBytes ~/ _MB} MB / $imageCacheCount items, '
      'channels: $maxChannelListSize, '
      'rss: ${rssTargetBytes ~/ _MB}/${rssPeakBytes ~/ _MB} MB)';
}
