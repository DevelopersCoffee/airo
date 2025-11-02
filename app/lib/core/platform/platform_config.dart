import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum PlatformType {
  android,
  ios,
  web,
  windows,
  macos,
  linux,
  fuchsia,
}

class PlatformConfig {
  // Private constructor to prevent instantiation
  PlatformConfig._();

  /// Get current platform type
  static PlatformType get currentPlatform {
    if (kIsWeb) {
      return PlatformType.web;
    } else if (Platform.isAndroid) {
      return PlatformType.android;
    } else if (Platform.isIOS) {
      return PlatformType.ios;
    } else if (Platform.isWindows) {
      return PlatformType.windows;
    } else if (Platform.isMacOS) {
      return PlatformType.macos;
    } else if (Platform.isLinux) {
      return PlatformType.linux;
    } else if (Platform.isFuchsia) {
      return PlatformType.fuchsia;
    } else {
      return PlatformType.android; // Default fallback
    }
  }

  /// Check if running on mobile platform
  static bool get isMobile => isAndroid || isIOS;

  /// Check if running on desktop platform
  static bool get isDesktop => isWindows || isMacOS || isLinux;

  /// Platform-specific checks
  static bool get isAndroid => currentPlatform == PlatformType.android;
  static bool get isIOS => currentPlatform == PlatformType.ios;
  static bool get isWeb => currentPlatform == PlatformType.web;
  static bool get isWindows => currentPlatform == PlatformType.windows;
  static bool get isMacOS => currentPlatform == PlatformType.macos;
  static bool get isLinux => currentPlatform == PlatformType.linux;
  static bool get isFuchsia => currentPlatform == PlatformType.fuchsia;

  /// Get platform-specific app bar height
  static double getAppBarHeight() {
    switch (currentPlatform) {
      case PlatformType.ios:
        return 44.0; // iOS standard
      case PlatformType.android:
        return 56.0; // Material Design standard
      case PlatformType.web:
        return 64.0; // Larger for web
      default:
        return 56.0; // Default Material Design
    }
  }

  /// Get platform-specific padding
  static EdgeInsets getPlatformPadding() {
    switch (currentPlatform) {
      case PlatformType.ios:
        return const EdgeInsets.all(16.0);
      case PlatformType.android:
        return const EdgeInsets.all(16.0);
      case PlatformType.web:
        return const EdgeInsets.all(24.0);
      default:
        return const EdgeInsets.all(16.0);
    }
  }

  /// Get platform-specific button height
  static double getButtonHeight() {
    switch (currentPlatform) {
      case PlatformType.ios:
        return 44.0;
      case PlatformType.android:
        return 48.0;
      case PlatformType.web:
        return 52.0;
      default:
        return 48.0;
    }
  }

  /// Get platform-specific border radius
  static double getBorderRadius() {
    switch (currentPlatform) {
      case PlatformType.ios:
        return 8.0;
      case PlatformType.android:
        return 4.0;
      case PlatformType.web:
        return 6.0;
      default:
        return 4.0;
    }
  }

  /// Check if platform supports specific features
  static bool get supportsHapticFeedback => isMobile;
  static bool get supportsFileSystem => !isWeb;
  static bool get supportsCamera => isMobile;
  static bool get supportsBiometrics => isMobile;
  static bool get supportsNotifications => !isWeb;
  static bool get supportsBackgroundTasks => isMobile;

  /// Device-specific configurations
  static bool get isPixel9Compatible {
    if (!isAndroid) return false;
    // Add specific checks for Pixel 9 if needed
    return true;
  }

  static bool get isIPhone13ProMaxCompatible {
    if (!isIOS) return false;
    // Add specific checks for iPhone 13 Pro Max if needed
    return true;
  }

  static bool get isChromeCompatible {
    if (!isWeb) return false;
    // Add specific checks for Chrome if needed
    return true;
  }

  /// Get platform-specific theme adjustments
  static ThemeData adjustThemeForPlatform(ThemeData theme) {
    switch (currentPlatform) {
      case PlatformType.ios:
        return theme.copyWith(
          appBarTheme: theme.appBarTheme.copyWith(
            elevation: 0,
            scrolledUnderElevation: 0.5,
          ),
        );
      case PlatformType.android:
        return theme.copyWith(
          appBarTheme: theme.appBarTheme.copyWith(
            elevation: 4,
            scrolledUnderElevation: 3,
          ),
        );
      case PlatformType.web:
        return theme.copyWith(
          appBarTheme: theme.appBarTheme.copyWith(
            elevation: 1,
            scrolledUnderElevation: 2,
          ),
          cardTheme: theme.cardTheme.copyWith(
            elevation: 2,
          ),
        );
      default:
        return theme;
    }
  }

  /// Get platform-specific scroll physics
  static ScrollPhysics getScrollPhysics() {
    switch (currentPlatform) {
      case PlatformType.ios:
        return const BouncingScrollPhysics();
      case PlatformType.android:
        return const ClampingScrollPhysics();
      case PlatformType.web:
        return const ClampingScrollPhysics();
      default:
        return const ClampingScrollPhysics();
    }
  }

  /// Get platform name as string
  static String get platformName {
    switch (currentPlatform) {
      case PlatformType.android:
        return 'Android';
      case PlatformType.ios:
        return 'iOS';
      case PlatformType.web:
        return 'Web';
      case PlatformType.windows:
        return 'Windows';
      case PlatformType.macos:
        return 'macOS';
      case PlatformType.linux:
        return 'Linux';
      case PlatformType.fuchsia:
        return 'Fuchsia';
    }
  }

  /// Get recommended minimum screen size for platform
  static Size getMinimumScreenSize() {
    switch (currentPlatform) {
      case PlatformType.android:
        return const Size(360, 640); // Minimum Android size
      case PlatformType.ios:
        return const Size(375, 667); // iPhone SE size
      case PlatformType.web:
        return const Size(768, 1024); // Tablet size minimum
      default:
        return const Size(800, 600); // Desktop minimum
    }
  }

  /// Check if current screen size is adequate
  static bool isScreenSizeAdequate(Size screenSize) {
    final minSize = getMinimumScreenSize();
    return screenSize.width >= minSize.width && screenSize.height >= minSize.height;
  }
}
