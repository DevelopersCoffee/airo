/// Stub implementation of flutter_image_compress for TV builds
library;

import 'dart:typed_data';

/// Compress format
enum CompressFormat {
  jpeg,
  png,
  webp,
  heic,
}

/// Stub FlutterImageCompress - returns original image on TV
class FlutterImageCompress {
  /// Compress with list - returns original on TV
  static Future<Uint8List> compressWithList(
    Uint8List image, {
    int minWidth = 1920,
    int minHeight = 1080,
    int quality = 95,
    int rotate = 0,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
    int inSampleSize = 1,
  }) async {
    // Return original image on TV (no compression available)
    return image;
  }
  
  /// Compress with file - returns original bytes on TV
  static Future<Uint8List?> compressWithFile(
    String file, {
    int minWidth = 1920,
    int minHeight = 1080,
    int quality = 95,
    int rotate = 0,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
    int inSampleSize = 1,
  }) async {
    return null;
  }
  
  /// Compress and get file - returns null on TV
  static Future<dynamic> compressAndGetFile(
    String file,
    String targetPath, {
    int minWidth = 1920,
    int minHeight = 1080,
    int quality = 95,
    int rotate = 0,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
    int inSampleSize = 1,
  }) async {
    return null;
  }
  
  /// Compress asset - returns original bytes on TV
  static Future<Uint8List?> compressAssetImage(
    String assetName, {
    int minWidth = 1920,
    int minHeight = 1080,
    int quality = 95,
    int rotate = 0,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
    int inSampleSize = 1,
  }) async {
    return null;
  }
}

