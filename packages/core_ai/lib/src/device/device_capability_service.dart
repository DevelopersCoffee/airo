import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'memory_severity.dart';

/// Service for querying device capabilities, particularly memory information.
///
/// Uses platform channels to retrieve native device information on Android/iOS.
/// Provides fallback values for web and unsupported platforms.
class DeviceCapabilityService {
  static final DeviceCapabilityService _instance =
      DeviceCapabilityService._internal();

  factory DeviceCapabilityService() => _instance;
  DeviceCapabilityService._internal();

  /// Platform channel for native communication.
  static const MethodChannel _channel = MethodChannel('com.airo.gemini_nano');

  /// Cached memory info to avoid frequent native calls.
  MemoryInfo? _cachedMemoryInfo;
  DateTime? _lastMemoryCheck;

  /// Cache duration for memory info (5 seconds).
  static const Duration _cacheDuration = Duration(seconds: 5);

  /// Gets the current device memory information.
  ///
  /// Returns cached info if available and fresh (within [_cacheDuration]).
  /// On web or unsupported platforms, returns estimated values.
  Future<MemoryInfo> getMemoryInfo({bool forceRefresh = false}) async {
    // Check cache validity
    if (!forceRefresh &&
        _cachedMemoryInfo != null &&
        _lastMemoryCheck != null) {
      final elapsed = DateTime.now().difference(_lastMemoryCheck!);
      if (elapsed < _cacheDuration) {
        return _cachedMemoryInfo!;
      }
    }

    // Web platform doesn't have native memory access
    if (kIsWeb) {
      _cachedMemoryInfo = _getWebMemoryEstimate();
      _lastMemoryCheck = DateTime.now();
      return _cachedMemoryInfo!;
    }

    try {
      final Map<dynamic, dynamic> result =
          await _channel.invokeMethod('getMemoryInfo');

      _cachedMemoryInfo = MemoryInfo(
        totalBytes: (result['totalBytes'] as num?)?.toInt() ?? 0,
        availableBytes: (result['availableBytes'] as num?)?.toInt() ?? 0,
      );
      _lastMemoryCheck = DateTime.now();
      return _cachedMemoryInfo!;
    } catch (e) {
      debugPrint('Error getting memory info: $e');
      // Return unknown memory info on error
      return MemoryInfo.unknown();
    }
  }

  /// Gets device information including manufacturer, model, etc.
  Future<DeviceInfo> getDeviceInfo() async {
    if (kIsWeb) {
      return DeviceInfo.web();
    }

    try {
      final Map<dynamic, dynamic> result =
          await _channel.invokeMethod('getDeviceInfo');

      return DeviceInfo(
        manufacturer: result['manufacturer'] as String? ?? 'Unknown',
        model: result['model'] as String? ?? 'Unknown',
        brand: result['brand'] as String? ?? 'Unknown',
        osVersion: result['release'] as String? ?? 'Unknown',
        sdkVersion: (result['sdkVersion'] as num?)?.toInt() ?? 0,
        isPixelDevice: result['isPixel'] as bool? ?? false,
        supportsOnDeviceAI: result['supportsGeminiNano'] as bool? ?? false,
      );
    } catch (e) {
      debugPrint('Error getting device info: $e');
      return DeviceInfo.unknown();
    }
  }

  /// Clears the cached memory info.
  void clearCache() {
    _cachedMemoryInfo = null;
    _lastMemoryCheck = null;
  }

  /// Returns an estimated memory info for web platforms.
  /// Uses navigator.deviceMemory when available (limited browser support).
  MemoryInfo _getWebMemoryEstimate() {
    // Web has limited memory access. Return a conservative estimate.
    // Modern browsers may expose navigator.deviceMemory but it's limited.
    // Default to 4GB total, 2GB available for web apps.
    return MemoryInfo.fromMegabytes(
      totalMB: 4096,
      availableMB: 2048,
    );
  }
}

/// Device hardware information.
class DeviceInfo {
  final String manufacturer;
  final String model;
  final String brand;
  final String osVersion;
  final int sdkVersion;
  final bool isPixelDevice;
  final bool supportsOnDeviceAI;

  const DeviceInfo({
    required this.manufacturer,
    required this.model,
    required this.brand,
    required this.osVersion,
    required this.sdkVersion,
    required this.isPixelDevice,
    required this.supportsOnDeviceAI,
  });

  factory DeviceInfo.unknown() => const DeviceInfo(
        manufacturer: 'Unknown',
        model: 'Unknown',
        brand: 'Unknown',
        osVersion: 'Unknown',
        sdkVersion: 0,
        isPixelDevice: false,
        supportsOnDeviceAI: false,
      );

  factory DeviceInfo.web() => const DeviceInfo(
        manufacturer: 'Web',
        model: 'Browser',
        brand: 'Web',
        osVersion: 'N/A',
        sdkVersion: 0,
        isPixelDevice: false,
        supportsOnDeviceAI: false,
      );

  String get displayName => '$manufacturer $model';

  @override
  String toString() => 'DeviceInfo($displayName, OS: $osVersion)';
}

