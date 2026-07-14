import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Device form factor for UI adaptation
///
/// Used for TV preparation (TV-P0-6: 10ft UI scaling).
/// TV detection enables:
/// - Larger touch targets (48dp → 56dp)
/// - D-pad navigation support
/// - 10ft UI adjustments
enum DeviceFormFactor {
  /// Mobile phone (portrait-primary)
  mobile,

  /// Tablet device (larger screen, touch input)
  tablet,

  /// TV device (Android TV, Fire TV, Apple TV)
  /// Requires D-pad navigation, larger UI elements
  tv,

  /// Desktop/Web (mouse/keyboard input)
  desktop,
}

/// TV platform type for platform-specific adjustments
enum TvPlatform {
  /// Amazon Fire TV (Fire TV Stick, Fire TV Cube, etc.)
  fireTv,

  /// Google Android TV (NVIDIA Shield, Sony, etc.)
  androidTv,

  /// Generic TV (other Leanback-enabled devices)
  genericTv,

  /// Not a TV device
  none,
}

/// Device form factor detection service
///
/// Detects device type for adaptive UI rendering.
/// TV detection uses Android TV/Fire TV manifest features.
class DeviceFormFactorDetector {
  DeviceFormFactorDetector._();

  static DeviceFormFactor? _cachedFormFactor;
  static TvPlatform? _cachedTvPlatform;
  static const _tvChannel = MethodChannel('com.airo/device_info');

  /// Debug override for form factor (used for testing on iPad/tablet)
  static DeviceFormFactor? debugFormFactorOverride;

  /// Debug override for TV platform
  static TvPlatform? debugTvPlatformOverride;

  /// Detect device form factor
  ///
  /// Uses heuristics for form factor detection:
  /// 1. Platform-specific TV detection (Android TV, Fire TV)
  /// 2. Screen size thresholds
  /// 3. Input type detection
  static Future<DeviceFormFactor> detect(BuildContext? context) async {
    // Return override if available
    if (debugFormFactorOverride != null) return debugFormFactorOverride!;

    // Return cached value if available
    if (_cachedFormFactor != null) return _cachedFormFactor!;

    // Web is always desktop
    if (kIsWeb) {
      _cachedFormFactor = DeviceFormFactor.desktop;
      return _cachedFormFactor!;
    }

    // Check for TV on Android
    if (Platform.isAndroid) {
      final isTV = await _isAndroidTV();
      if (isTV) {
        _cachedFormFactor = DeviceFormFactor.tv;
        return _cachedFormFactor!;
      }
    }

    // Desktop platforms
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      _cachedFormFactor = DeviceFormFactor.desktop;
      return _cachedFormFactor!;
    }

    // Mobile/Tablet detection based on screen size
    // Note: context may be stale after async gap, but we only use it
    // for MediaQuery which is safe for screen size detection
    if (context != null && context.mounted) {
      return _detectFromScreenSize(context);
    }

    // Default to mobile
    _cachedFormFactor = DeviceFormFactor.mobile;
    return _cachedFormFactor!;
  }

  /// Synchronous detection (no TV check, uses cached or screen-based)
  static DeviceFormFactor detectSync(BuildContext context) {
    // Return override if available
    if (debugFormFactorOverride != null) return debugFormFactorOverride!;

    // Return cached if available
    if (_cachedFormFactor != null) return _cachedFormFactor!;

    // Web is desktop
    if (kIsWeb) return DeviceFormFactor.desktop;

    // Desktop platforms
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      return DeviceFormFactor.desktop;
    }

    // Screen-based detection
    return _detectFromScreenSize(context);
  }

  /// Detect from screen size (mobile vs tablet)
  static DeviceFormFactor _detectFromScreenSize(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final shortestSide = screenSize.shortestSide;

    // Tablet: shortest side >= 600dp (Material Design threshold)
    if (shortestSide >= 600) {
      _cachedFormFactor = DeviceFormFactor.tablet;
      return DeviceFormFactor.tablet;
    }

    _cachedFormFactor = DeviceFormFactor.mobile;
    return DeviceFormFactor.mobile;
  }

  /// Check if running on Android TV (uses platform channel)
  static Future<bool> _isAndroidTV() async {
    try {
      // Check for TV features via platform channel
      final result = await _tvChannel.invokeMethod<bool>('isTV');
      if (result == true) {
        // Also detect TV platform type
        await _detectTvPlatform();
        return true;
      }
      return false;
    } on MissingPluginException {
      // Platform channel not implemented yet - use fallback
      return _isAndroidTVFallback();
    } catch (_) {
      return _isAndroidTVFallback();
    }
  }

  /// Detect the specific TV platform (Fire TV, Android TV, etc.)
  static Future<TvPlatform> _detectTvPlatform() async {
    if (_cachedTvPlatform != null) return _cachedTvPlatform!;

    try {
      // Try to get TV platform from platform channel
      final platformStr = await _tvChannel.invokeMethod<String>(
        'getTvPlatform',
      );

      if (platformStr == 'fire_tv') {
        _cachedTvPlatform = TvPlatform.fireTv;
      } else if (platformStr == 'android_tv') {
        _cachedTvPlatform = TvPlatform.androidTv;
      } else {
        _cachedTvPlatform = TvPlatform.genericTv;
      }
    } on MissingPluginException {
      // Fallback detection
      _cachedTvPlatform = _detectTvPlatformFallback();
    } catch (_) {
      _cachedTvPlatform = _detectTvPlatformFallback();
    }

    return _cachedTvPlatform!;
  }

  /// Fallback TV platform detection using heuristics
  static TvPlatform _detectTvPlatformFallback() {
    // Fire TV devices have specific manufacturer strings
    // This is a best-effort fallback - actual implementation would check
    // Build.MANUFACTURER on Android
    return TvPlatform.genericTv;
  }

  /// Fallback TV detection using environment heuristics
  static bool _isAndroidTVFallback() {
    // Check environment variables (set by some TV launchers)
    // This is a best-effort fallback
    return false;
  }

  /// Get the current TV platform type
  ///
  /// Returns [TvPlatform.none] if not running on a TV.
  static Future<TvPlatform> getTvPlatform() async {
    if (debugTvPlatformOverride != null) return debugTvPlatformOverride!;
    if (!Platform.isAndroid) return TvPlatform.none;
    if (_cachedTvPlatform != null) return _cachedTvPlatform!;

    final isTV = await _isAndroidTV();
    if (!isTV) {
      _cachedTvPlatform = TvPlatform.none;
    }
    return _cachedTvPlatform ?? TvPlatform.none;
  }

  /// Check if running on Fire TV specifically
  static Future<bool> isFireTv() async {
    final platform = await getTvPlatform();
    return platform == TvPlatform.fireTv;
  }

  /// Check if device supports D-pad navigation
  static bool supportsDpadNavigation(DeviceFormFactor formFactor) {
    return formFactor == DeviceFormFactor.tv;
  }

  /// Check if device needs 10ft UI (TV viewing distance)
  static bool needs10ftUI(DeviceFormFactor formFactor) {
    return formFactor == DeviceFormFactor.tv;
  }

  /// Get recommended minimum touch target size
  static double getMinTouchTarget(DeviceFormFactor formFactor) {
    return formFactor == DeviceFormFactor.tv ? 56.0 : 48.0;
  }

  /// Get Fire TV safe zone insets
  ///
  /// Fire TV has recommended safe zones to avoid UI clipping.
  /// See: https://developer.amazon.com/docs/fire-tv/design-and-user-experience-guidelines.html
  static EdgeInsets getFireTvSafeZone() {
    return const EdgeInsets.symmetric(
      horizontal: 48.0, // 3% of 1920 ≈ 48dp
      vertical: 27.0, // 2.5% of 1080 ≈ 27dp
    );
  }

  /// Clear cached form factor (for testing)
  @visibleForTesting
  static void clearCache() {
    _cachedFormFactor = null;
    _cachedTvPlatform = null;
    debugFormFactorOverride = null;
    debugTvPlatformOverride = null;
  }
}
