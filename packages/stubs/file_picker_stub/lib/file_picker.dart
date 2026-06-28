/// Stub implementation of file_picker for TV builds
library;

/// File type
enum FileType { any, media, image, video, audio, custom }

/// Platform file
class PlatformFile {
  PlatformFile({
    required this.name,
    required this.size,
    this.path,
    this.bytes,
    this.extension,
  });
  final String? path;
  final String name;
  final int size;
  final List<int>? bytes;
  final String? extension;
}

/// File picker result
class FilePickerResult {
  FilePickerResult(this.files);
  final List<PlatformFile> files;

  /// Get single file
  PlatformFile? get single => files.isEmpty ? null : files.first;

  /// Get paths
  List<String?> get paths => files.map((f) => f.path).toList();

  /// Get names
  List<String> get names => files.map((f) => f.name).toList();
}

/// File picker status
enum FilePickerStatus { picking, done }

/// Stub FilePicker - returns null on TV
abstract final class FilePicker {
  /// Pick files - returns null on TV
  static Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
  }) async => null;

  /// Save file - returns null on TV
  static Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
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
