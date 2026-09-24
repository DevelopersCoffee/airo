import 'package:flutter/material.dart';

/// Persisted caption text size for the app-layer subtitle renderer.
enum CaptionTextSize {
  standard('standard', 16),
  large('large', 20),
  extraLarge('extra_large', 24);

  const CaptionTextSize(this.stableId, this.fontSize);

  final String stableId;
  final double fontSize;

  static CaptionTextSize fromStableId(String? value) {
    if (value == null) return CaptionTextSize.standard;
    return CaptionTextSize.values.firstWhere(
      (size) => size.stableId == value,
      orElse: () => CaptionTextSize.standard,
    );
  }
}

/// High-contrast preset colors for subtitles on video.
enum CaptionTextColor {
  white('white', Color(0xFFFFFFFF)),
  yellow('yellow', Color(0xFFFFFF00)),
  cyan('cyan', Color(0xFF00FFFF));

  const CaptionTextColor(this.stableId, this.color);

  final String stableId;
  final Color color;

  static CaptionTextColor fromStableId(String? value) {
    if (value == null) return CaptionTextColor.white;
    return CaptionTextColor.values.firstWhere(
      (color) => color.stableId == value,
      orElse: () => CaptionTextColor.white,
    );
  }
}

TextStyle captionTextStyle({
  required CaptionTextSize size,
  required CaptionTextColor color,
}) {
  return TextStyle(
    color: color.color,
    fontSize: size.fontSize,
    fontWeight: FontWeight.w600,
    height: 1.25,
    shadows: const [
      Shadow(offset: Offset(1, 1), blurRadius: 2, color: Colors.black87),
      Shadow(offset: Offset(-1, -1), blurRadius: 2, color: Colors.black87),
    ],
  );
}
