import 'package:flutter/material.dart';

/// A shared widget that displays the Airo app icon as a placeholder.
///
/// This widget centralizes app icon usage to:
/// 1. Reduce code duplication across the app
/// 2. Enable easy asset optimization (single reference point)
/// 3. Provide consistent fallback behavior
///
/// Usage:
/// ```dart
/// AppIconPlaceholder(size: 48)
/// AppIconPlaceholder.withPadding(padding: EdgeInsets.all(8))
/// ```
class AppIconPlaceholder extends StatelessWidget {
  /// The size of the icon (width and height)
  final double? size;

  /// Padding around the icon
  final EdgeInsetsGeometry padding;

  /// Fallback icon to show if asset fails to load
  final Widget? fallbackIcon;

  /// How the icon should be scaled within its bounds
  final BoxFit fit;

  /// Path to the app icon asset
  static const String assetPath = 'assets/airo_icon.png';

  const AppIconPlaceholder({
    super.key,
    this.size,
    this.padding = EdgeInsets.zero,
    this.fallbackIcon,
    this.fit = BoxFit.contain,
  });

  /// Creates a placeholder with padding and optional size constraints
  const AppIconPlaceholder.withPadding({
    super.key,
    required this.padding,
    this.size,
    this.fallbackIcon,
    this.fit = BoxFit.contain,
  });

  /// Creates a placeholder for channel icons (with standard channel size)
  factory AppIconPlaceholder.channel({Key? key, bool isAudioOnly = false}) {
    return AppIconPlaceholder(
      key: key,
      padding: const EdgeInsets.all(8),
      fallbackIcon: Icon(
        isAudioOnly ? Icons.radio : Icons.live_tv,
        color: Colors.grey,
      ),
    );
  }

  /// Creates a placeholder for video player (larger size)
  factory AppIconPlaceholder.videoPlayer({Key? key}) {
    return AppIconPlaceholder(
      key: key,
      size: 120,
      padding: const EdgeInsets.all(16),
      fallbackIcon: const Icon(Icons.live_tv, color: Colors.white54, size: 64),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: fit,
        // Cache the image for better performance
        cacheWidth: size != null ? (size! * 2).toInt() : null,
        cacheHeight: size != null ? (size! * 2).toInt() : null,
        errorBuilder: (_, _, _) =>
            fallbackIcon ?? Icon(Icons.image, color: Colors.grey, size: size),
      ),
    );
  }

  /// Precache the app icon for faster loading
  /// Call this in main.dart or during app initialization
  static Future<void> precache(BuildContext context) async {
    await precacheImage(const AssetImage(assetPath), context);
  }
}
