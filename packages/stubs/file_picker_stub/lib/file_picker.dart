/// Stub implementation of file_picker for TV builds
library;

import 'dart:typed_data';

/// File type
enum FileType { any, media, image, video, audio, custom }

/// Platform file matching file_picker 12's [PlatformFile] surface.
class PlatformFile {
  PlatformFile({
    required this.name,
    required int size,
    this.path,
    Uint8List? bytes,
  }) : _size = size,
       _bytes = bytes;

  final String name;
  final String? path;
  final int _size;
  final Uint8List? _bytes;

  Uri get uri =>
      path != null ? Uri.file(path!) : Uri.dataFromBytes(_bytes ?? const []);

  Future<int> length() async => _size;

  /// Read in-memory bytes; TV never opens an interactive picker.
  Future<Uint8List> readAsBytes() async {
    final data = _bytes;
    if (data != null) return data;
    throw StateError('PlatformFile.readAsBytes(): file data is not available.');
  }
}

/// File picker status
enum FilePickerStatus { picking, done }

/// Stub FilePicker - returns null / empty on TV
abstract final class FilePicker {
  /// Pick one file - returns null on TV
  static Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool lockParentWindow = false,
  }) async => null;

  /// Pick files - empty list on TV (matches file_picker 12 cancel).
  static Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
  }) async => const <PlatformFile>[];

  /// Save file - returns null on TV
  static Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool lockParentWindow = false,
  }) async => null;

  /// Get directory path - returns null on TV
  static Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    bool lockParentWindow = false,
  }) async => null;

  /// Clear temporary files
  static Future<bool?> clearTemporaryFiles() async => true;
}
