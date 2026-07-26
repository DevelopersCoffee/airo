import 'dart:io';

/// A bounded, random-access media source consumed by the phone HTTP server.
///
/// Platform adapters may retain a permission-scoped descriptor instead of
/// exposing a filesystem path. Reads use an exclusive end offset, matching
/// [File.openRead].
abstract interface class PhoneMediaSeekableSource {
  bool get isAvailable;

  Future<int> length();

  Stream<List<int>> openRead(int start, int end);
}

/// Filesystem implementation used by desktop platforms and deterministic
/// host tests.
class FilePhoneMediaSeekableSource implements PhoneMediaSeekableSource {
  FilePhoneMediaSeekableSource(this.filePath);

  final String filePath;

  File get _file => File(filePath);

  @override
  bool get isAvailable => _file.existsSync();

  @override
  Future<int> length() => _file.length();

  @override
  Stream<List<int>> openRead(int start, int end) => _file.openRead(start, end);
}
