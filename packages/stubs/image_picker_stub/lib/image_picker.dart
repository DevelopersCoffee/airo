/// Stub implementation of image_picker for TV builds
library;

import 'dart:typed_data';

/// Image source
enum ImageSource { camera, gallery }

/// Camera device
enum CameraDevice { rear, front }

/// XFile - cross platform file
class XFile {
  XFile(this.path, {this.mimeType, this.name});
  final String path;
  final String? mimeType;
  final String? name;

  /// Read as bytes
  Future<Uint8List> readAsBytes() async => Uint8List(0);

  /// Read as string
  Future<String> readAsString() async => '';

  /// Get length
  Future<int> length() async => 0;
}

/// Image picker options
class ImagePickerOptions {
  const ImagePickerOptions({
    this.maxWidth,
    this.maxHeight,
    this.imageQuality,
    this.preferredCameraDevice = CameraDevice.rear,
  });
  final double? maxWidth;
  final double? maxHeight;
  final int? imageQuality;
  final CameraDevice preferredCameraDevice;
}

/// Stub ImagePicker - returns null on TV (no camera/gallery)
class ImagePicker {
  /// Pick image - returns null on TV
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => null;

  /// Pick multiple images - returns empty list on TV
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
  }) async => [];

  /// Pick video - returns null on TV
  Future<XFile?> pickVideo({
    required ImageSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    Duration? maxDuration,
  }) async => null;

  /// Pick media - returns empty list on TV
  Future<List<XFile>> pickMedia({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
  }) async => [];
}
