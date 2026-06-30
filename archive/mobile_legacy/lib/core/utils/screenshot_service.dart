import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

import 'logger.dart';

/// Service for capturing screenshots for bug reports.
class ScreenshotService {
  ScreenshotService._();

  /// Captures a screenshot of the given widget using a RepaintBoundary key.
  ///
  /// Returns the screenshot as bytes, or null if capture fails.
  static Future<Uint8List?> captureFromKey(GlobalKey key) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        AppLogger.warning(
          'Cannot capture screenshot: RenderRepaintBoundary not found',
          tag: 'SCREENSHOT',
        );
        return null;
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        AppLogger.warning(
          'Cannot capture screenshot: Failed to convert to bytes',
          tag: 'SCREENSHOT',
        );
        return null;
      }

      return byteData.buffer.asUint8List();
    } catch (e, stack) {
      AppLogger.error(
        'Failed to capture screenshot',
        tag: 'SCREENSHOT',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  /// Saves screenshot bytes to a temporary file.
  ///
  /// Returns the file path, or null if save fails.
  static Future<String?> saveToTempFile(Uint8List bytes) async {
    if (kIsWeb) {
      // Web doesn't support file system access the same way
      AppLogger.info(
        'Screenshot saved to memory (web platform)',
        tag: 'SCREENSHOT',
      );
      return null;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/bug_report_screenshot_$timestamp.png');
      await file.writeAsBytes(bytes);

      AppLogger.info('Screenshot saved to: ${file.path}', tag: 'SCREENSHOT');
      return file.path;
    } catch (e, stack) {
      AppLogger.error(
        'Failed to save screenshot',
        tag: 'SCREENSHOT',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  /// Converts screenshot bytes to a base64 data URL for embedding in markdown.
  ///
  /// Returns a data URL string like: `data:image/png;base64,iVBORw0KGgo...`
  static String toBase64DataUrl(Uint8List bytes) {
    final base64 = base64Encode(bytes);
    return 'data:image/png;base64,$base64';
  }

  /// Converts screenshot bytes to markdown image syntax with base64 embedding.
  ///
  /// Note: GitHub has a limit on issue body size (~65535 characters).
  /// Large screenshots may need to be compressed or resized.
  static String toMarkdownImage(Uint8List bytes, {String alt = 'Screenshot'}) {
    final dataUrl = toBase64DataUrl(bytes);
    return '![$alt]($dataUrl)';
  }

  /// Maximum size for GitHub issue embedding (30KB -> ~40KB base64)
  static const int maxGitHubBytes = 30 * 1024;

  /// Compresses screenshot bytes to fit within GitHub's limits.
  ///
  /// Uses progressive quality reduction to achieve target size.
  /// Returns compressed bytes or null if compression fails.
  static Future<Uint8List?> compressScreenshot(
    Uint8List bytes, {
    int maxWidth = 800,
    int maxHeight = 800,
    int targetSizeKb = 30,
  }) async {
    if (kIsWeb) {
      // Web compression not supported by flutter_image_compress
      AppLogger.info(
        'Image compression not available on web',
        tag: 'SCREENSHOT',
      );
      return bytes;
    }

    try {
      final targetBytes = targetSizeKb * 1024;

      // If already small enough, return as-is
      if (bytes.length <= targetBytes) {
        return bytes;
      }

      AppLogger.info(
        'Compressing screenshot: ${(bytes.length / 1024).toStringAsFixed(1)} KB -> target $targetSizeKb KB',
        tag: 'SCREENSHOT',
      );

      // Try progressive quality reduction
      final qualities = [70, 50, 30, 20];

      for (final quality in qualities) {
        final compressed = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: maxWidth,
          minHeight: maxHeight,
          quality: quality,
          format: CompressFormat.jpeg,
        );

        AppLogger.info(
          'Compressed at quality $quality: ${(compressed.length / 1024).toStringAsFixed(1)} KB',
          tag: 'SCREENSHOT',
        );

        if (compressed.length <= targetBytes) {
          return compressed;
        }
      }

      // If still too large, try with smaller dimensions
      final smallCompressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 400,
        minHeight: 400,
        quality: 20,
        format: CompressFormat.jpeg,
      );

      AppLogger.info(
        'Final compression: ${(smallCompressed.length / 1024).toStringAsFixed(1)} KB',
        tag: 'SCREENSHOT',
      );

      return smallCompressed;
    } catch (e, stack) {
      AppLogger.error(
        'Failed to compress screenshot',
        tag: 'SCREENSHOT',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  /// Compresses screenshot if needed to fit GitHub limits.
  /// Returns the original bytes if already within limits.
  static Future<Uint8List?> compressIfNeeded(Uint8List bytes) async {
    if (isWithinGitHubLimit(bytes)) {
      return bytes;
    }
    return compressScreenshot(bytes);
  }

  /// Checks if the screenshot size is within GitHub's limits.
  ///
  /// GitHub issue body has a limit of ~65535 characters.
  /// Base64 encoding increases size by ~33%, so we limit to ~40KB.
  static bool isWithinGitHubLimit(Uint8List bytes) {
    // Base64 encoding increases size by ~33%
    // GitHub limit is ~65535 chars, but we need room for other content
    // So limit screenshot to ~30KB (which becomes ~40KB in base64)
    const maxBytes = 30 * 1024;
    return bytes.length <= maxBytes;
  }

  /// Gets a warning message if screenshot is too large.
  static String? getSizeWarning(Uint8List bytes) {
    if (isWithinGitHubLimit(bytes)) return null;

    final sizeKb = (bytes.length / 1024).toStringAsFixed(1);
    return 'Screenshot is large ($sizeKb KB). It may be compressed or excluded.';
  }
}
