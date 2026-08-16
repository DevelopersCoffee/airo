import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'desktop_memory_probe_export.dart';
import 'memory_severity.dart';

/// Service for querying device capabilities, particularly memory information.
///
/// Uses platform channels to retrieve native device information on Android/iOS.
/// Provides fallback values for web and unsupported platforms.
class DeviceCapabilityService {
  static const String _bindingInitializationErrorSnippet =
      'Binding has not yet been initialized';
  static const String _binaryMessengerInitializationErrorSnippet =
      'defaultBinaryMessenger was accessed before the binding was initialized';
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

  /// Platform probes must not leave the capability report spinning forever
  /// when a native bridge is unavailable or wedged after an OS update.
  // Capability probes are advisory and must never hold device analysis or
  // model selection hostage. A healthy platform channel answers far faster;
  // one second gives it room while bounding OS/plugin regressions tightly.
  static const Duration _probeTimeout = Duration(seconds: 1);

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

    if (_usesDesktopMemoryProbe) {
      final desktop = await probeDesktopMemory();
      if (desktop != null) {
        _cachedMemoryInfo = desktop;
        _lastMemoryCheck = DateTime.now();
        return desktop;
      }
    }

    if (!_usesGeminiNanoChannel) {
      return MemoryInfo.unknown();
    }

    try {
      final Map<dynamic, dynamic> result = await _channel
          .invokeMethod('getMemoryInfo')
          .timeout(_probeTimeout);

      _cachedMemoryInfo = MemoryInfo(
        totalBytes: (result['totalBytes'] as num?)?.toInt() ?? 0,
        availableBytes: (result['availableBytes'] as num?)?.toInt() ?? 0,
      );
      _lastMemoryCheck = DateTime.now();
      return _cachedMemoryInfo!;
    } catch (e) {
      if (!shouldSuppressPlatformChannelErrorLog(e)) {
        debugPrint('Error getting memory info: $e');
      }
      // Return unknown memory info on error
      return MemoryInfo.unknown();
    }
  }

  /// Gets device information including manufacturer, model, etc.
  Future<DeviceInfo> getDeviceInfo() async {
    if (kIsWeb) {
      return DeviceInfo.web();
    }

    if (_usesDesktopMemoryProbe) {
      return DeviceInfo.desktop(platform: defaultTargetPlatform.name);
    }

    if (!_usesGeminiNanoChannel) {
      return DeviceInfo.unknown();
    }

    try {
      final Map<dynamic, dynamic> result = await _channel
          .invokeMethod('getDeviceInfo')
          .timeout(_probeTimeout);

      return DeviceInfo(
        manufacturer: result['manufacturer'] as String? ?? 'Unknown',
        model: result['model'] as String? ?? 'Unknown',
        brand: result['brand'] as String? ?? 'Unknown',
        osVersion: result['release'] as String? ?? 'Unknown',
        sdkVersion: (result['sdkVersion'] as num?)?.toInt() ?? 0,
        isPixelDevice: result['isPixel'] as bool? ?? false,
        supportsOnDeviceAI: result['supportsGeminiNano'] as bool? ?? false,
        cpuSummary: result['cpuSummary'] as String?,
        gpuSummary: result['gpuSummary'] as String?,
        npuSummary: result['npuSummary'] as String?,
        storageSummary: result['storageSummary'] as String?,
        thermalSummary: result['thermalSummary'] as String?,
      );
    } catch (e) {
      if (!shouldSuppressPlatformChannelErrorLog(e)) {
        debugPrint('Error getting device info: $e');
      }
      return DeviceInfo.unknown();
    }
  }

  static bool get _usesGeminiNanoChannel =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get _usesDesktopMemoryProbe =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows);

  @visibleForTesting
  static bool shouldSuppressPlatformChannelErrorLog(Object error) {
    final message = '$error';
    return message.contains(_bindingInitializationErrorSnippet) ||
        message.contains(_binaryMessengerInitializationErrorSnippet) ||
        message.contains('MissingPluginException');
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
    return MemoryInfo.fromMegabytes(totalMB: 4096, availableMB: 2048);
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
  final String? cpuSummary;
  final String? gpuSummary;
  final String? npuSummary;
  final String? storageSummary;
  final String? thermalSummary;

  const DeviceInfo({
    required this.manufacturer,
    required this.model,
    required this.brand,
    required this.osVersion,
    required this.sdkVersion,
    required this.isPixelDevice,
    required this.supportsOnDeviceAI,
    this.cpuSummary,
    this.gpuSummary,
    this.npuSummary,
    this.storageSummary,
    this.thermalSummary,
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

  factory DeviceInfo.desktop({required String platform}) => DeviceInfo(
    manufacturer: platform,
    model: 'Desktop',
    brand: platform,
    osVersion: 'Desktop',
    sdkVersion: 0,
    isPixelDevice: false,
    supportsOnDeviceAI: false,
  );

  String get displayName => '$manufacturer $model';

  String get cpuDisplay => cpuSummary?.trim().isNotEmpty == true
      ? cpuSummary!.trim()
      : 'Not reported by platform adapter';

  String get gpuDisplay => gpuSummary?.trim().isNotEmpty == true
      ? gpuSummary!.trim()
      : 'Not reported by platform adapter';

  String get npuDisplay => npuSummary?.trim().isNotEmpty == true
      ? npuSummary!.trim()
      : supportsOnDeviceAI
      ? 'On-device AI service reported'
      : 'Not reported by platform adapter';

  String get storageDisplay => storageSummary?.trim().isNotEmpty == true
      ? storageSummary!.trim()
      : 'Not reported by platform adapter';

  String get thermalDisplay => thermalSummary?.trim().isNotEmpty == true
      ? thermalSummary!.trim()
      : 'Not reported by platform adapter';

  @override
  String toString() => 'DeviceInfo($displayName, OS: $osVersion)';
}
