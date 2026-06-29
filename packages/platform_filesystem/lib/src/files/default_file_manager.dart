import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:platform_events/platform_events.dart';
import '../contracts/file_manager.dart';
import '../contracts/directory_provider.dart';
import '../files/platform_file.dart';
import '../events/filesystem_events.dart';

class DefaultFileManager implements FileManager {
  final DirectoryProvider _directoryProvider;
  final EventPublisher _eventPublisher;
  final _uuid = const Uuid();

  DefaultFileManager(this._directoryProvider, this._eventPublisher);

  Future<File> _resolvePlatformFile(PlatformFile file) async {
    // For simplicity we use the documents base by resolving against system/.. but ideally the Provider exposes a raw base.
    final sys = await _directoryProvider.systemDirectory();
    final baseDir = sys.parent;
    return File(p.join(baseDir.path, file.relativePath));
  }

  @override
  Future<T> createFile<T extends PlatformFile>(T descriptor) async {
    final file = await _resolvePlatformFile(descriptor);
    await file.parent.create(recursive: true);
    if (!await file.exists()) {
      await file.create();
    }
    return descriptor;
  }

  @override
  Future<void> deleteFile(PlatformFile descriptor) async {
    final file = await _resolvePlatformFile(descriptor);
    if (await file.exists()) {
      await file.delete();
      _eventPublisher.publish(FileDeletedEvent(
        eventId: _uuid.v4(),
        filePath: file.path,
      ));
    }
  }

  @override
  Future<bool> exists(PlatformFile descriptor) async {
    final file = await _resolvePlatformFile(descriptor);
    return await file.exists();
  }

  @override
  Future<void> atomicWrite(PlatformFile destination, Future<void> Function(File tempFile) writeOperation) async {
    final destFile = await _resolvePlatformFile(destination);
    await destFile.parent.create(recursive: true);
    
    final tempDir = await _directoryProvider.tempDirectory();
    final tempFile = File(p.join(tempDir.path, '${_uuid.v4()}.tmp'));
    
    try {
      await writeOperation(tempFile);
      // Atomic rename
      await tempFile.rename(destFile.path);
    } catch (e) {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      rethrow;
    }
  }
}
