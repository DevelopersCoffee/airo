import os

def create_file(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

base = 'packages/platform_filesystem/lib/src'

# Contracts
create_file(f'{base}/contracts/filesystem_service.dart', '''import 'package:platform_core/platform_core.dart';

abstract interface class FilesystemService implements PlatformService {
  Future<void> initialize();
  Future<void> shutdown();
}
''')

create_file(f'{base}/contracts/directory_provider.dart', '''import 'dart:io';

abstract interface class DirectoryProvider {
  Future<Directory> systemDirectory();
  Future<Directory> workspacesDirectory();
  Future<Directory> workspaceDirectory(String workspaceId);
  Future<Directory> modelsDirectory();
  Future<Directory> modelTypeDirectory(String type); // llm, embedding, whisper, tts, vision
  Future<Directory> downloadsDirectory();
  Future<Directory> cacheDirectory();
  Future<Directory> exportsDirectory();
  Future<Directory> importsDirectory();
  Future<Directory> tempDirectory();
  Future<Directory> diagnosticsDirectory();
  Future<Directory> backupsDirectory();
}
''')

create_file(f'{base}/contracts/file_manager.dart', '''import 'dart:io';
import '../files/platform_file.dart';

abstract interface class FileManager {
  Future<T> createFile<T extends PlatformFile>(T descriptor);
  Future<void> deleteFile(PlatformFile file);
  Future<bool> exists(PlatformFile file);
  Future<void> atomicWrite(PlatformFile destination, Future<void> Function(File tempFile) writeOperation);
}
''')

create_file(f'{base}/contracts/cache_manager.dart', '''abstract interface class CacheManager {
  Future<void> clearCache();
  Future<int> getCacheSize();
  Future<void> evictExpired(Duration ttl);
}
''')

create_file(f'{base}/contracts/integrity_verifier.dart', '''import 'dart:io';

class IntegrityResult {
  final bool isValid;
  final String expectedHash;
  final String actualHash;

  const IntegrityResult({
    required this.isValid,
    required this.expectedHash,
    required this.actualHash,
  });
}

abstract interface class IntegrityVerifier {
  Future<IntegrityResult> verifySha256(File file, String expectedHash);
}
''')

create_file(f'{base}/contracts/import_export_service.dart', '''import 'dart:io';
import '../files/platform_file.dart';

abstract interface class ImportExportService {
  Future<File> exportData(ExportFile exportFile, dynamic data);
  Future<dynamic> importData(File file);
}
''')

# Typed File Descriptors
create_file(f'{base}/files/platform_file.dart', '''abstract class PlatformFile {
  final String fileName;
  
  const PlatformFile(this.fileName);
  
  String get relativePath;
}
''')

create_file(f'{base}/files/file_types.dart', '''import 'platform_file.dart';

class ModelFile extends PlatformFile {
  final String modelType;
  const ModelFile(super.fileName, this.modelType);
  
  @override
  String get relativePath => 'models/$modelType/$fileName';
}

class WorkspaceFile extends PlatformFile {
  final String workspaceId;
  const WorkspaceFile(super.fileName, this.workspaceId);
  
  @override
  String get relativePath => 'workspaces/$workspaceId/$fileName';
}

class DocumentFile extends WorkspaceFile {
  const DocumentFile(String fileName, String workspaceId) : super(fileName, workspaceId);
  
  @override
  String get relativePath => 'workspaces/$workspaceId/documents/$fileName';
}

class AudioFile extends WorkspaceFile {
  const AudioFile(String fileName, String workspaceId) : super(fileName, workspaceId);
  
  @override
  String get relativePath => 'workspaces/$workspaceId/audio/$fileName';
}

class ImageFile extends WorkspaceFile {
  const ImageFile(String fileName, String workspaceId) : super(fileName, workspaceId);
  
  @override
  String get relativePath => 'workspaces/$workspaceId/images/$fileName';
}

class ExportFile extends PlatformFile {
  const ExportFile(super.fileName);
  
  @override
  String get relativePath => 'exports/$fileName';
}

class TemporaryFile extends PlatformFile {
  const TemporaryFile(super.fileName);
  
  @override
  String get relativePath => 'temp/$fileName';
}
''')

# Events
create_file(f'{base}/events/filesystem_events.dart', '''import 'package:platform_events/platform_events.dart';
import 'package:platform_core/platform_core.dart' hide PlatformEvent;

class DirectoryCreatedEvent implements PlatformEvent {
  @override
  final String eventId;
  @override
  final DateTime timestamp;
  @override
  final EventCategory category = EventCategory.system;
  @override
  final SemanticVersion version = const SemanticVersion(major: 1, minor: 0, patch: 0);
  @override
  final String? correlationId;
  @override
  final String? sessionId = null;
  @override
  final String? workspaceId = null;
  @override
  final String? source = 'platform_filesystem';
  @override
  final EventMetadata? metadata = null;

  final String directoryPath;

  DirectoryCreatedEvent({
    required this.eventId,
    required this.directoryPath,
    this.correlationId,
  }) : timestamp = DateTime.now();
}

class FileDeletedEvent implements PlatformEvent {
  @override
  final String eventId;
  @override
  final DateTime timestamp;
  @override
  final EventCategory category = EventCategory.system;
  @override
  final SemanticVersion version = const SemanticVersion(major: 1, minor: 0, patch: 0);
  @override
  final String? correlationId;
  @override
  final String? sessionId = null;
  @override
  final String? workspaceId;
  @override
  final String? source = 'platform_filesystem';
  @override
  final EventMetadata? metadata = null;

  final String filePath;

  FileDeletedEvent({
    required this.eventId,
    required this.filePath,
    this.workspaceId,
    this.correlationId,
  }) : timestamp = DateTime.now();
}

class CacheClearedEvent implements PlatformEvent {
  @override
  final String eventId;
  @override
  final DateTime timestamp;
  @override
  final EventCategory category = EventCategory.system;
  @override
  final SemanticVersion version = const SemanticVersion(major: 1, minor: 0, patch: 0);
  @override
  final String? correlationId;
  @override
  final String? sessionId = null;
  @override
  final String? workspaceId = null;
  @override
  final String? source = 'platform_filesystem';
  @override
  final EventMetadata? metadata = null;

  final int bytesFreed;

  CacheClearedEvent({
    required this.eventId,
    required this.bytesFreed,
    this.correlationId,
  }) : timestamp = DateTime.now();
}
''')

# Implementations
create_file(f'{base}/directories/default_directory_provider.dart', '''import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../contracts/directory_provider.dart';

class DefaultDirectoryProvider implements DirectoryProvider {
  late Directory _baseDir;

  Future<void> initialize() async {
    final docsDir = await getApplicationDocumentsDirectory();
    _baseDir = Directory(p.join(docsDir.path, 'AIRO'));
    await _ensureDir(_baseDir);
  }
  
  // For tests
  void initializeWith(Directory baseDir) {
    _baseDir = baseDir;
  }

  Future<Directory> _ensureDir(Directory dir) async {
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _getSubDir(String path) async {
    final dir = Directory(p.join(_baseDir.path, path));
    return await _ensureDir(dir);
  }

  @override
  Future<Directory> systemDirectory() => _getSubDir('system');

  @override
  Future<Directory> workspacesDirectory() => _getSubDir('workspaces');

  @override
  Future<Directory> workspaceDirectory(String workspaceId) => _getSubDir('workspaces/$workspaceId');

  @override
  Future<Directory> modelsDirectory() => _getSubDir('models');

  @override
  Future<Directory> modelTypeDirectory(String type) => _getSubDir('models/$type');

  @override
  Future<Directory> downloadsDirectory() => _getSubDir('downloads');

  @override
  Future<Directory> cacheDirectory() => _getSubDir('cache');

  @override
  Future<Directory> exportsDirectory() => _getSubDir('exports');

  @override
  Future<Directory> importsDirectory() => _getSubDir('imports');

  @override
  Future<Directory> tempDirectory() => _getSubDir('temp');

  @override
  Future<Directory> diagnosticsDirectory() => _getSubDir('diagnostics');

  @override
  Future<Directory> backupsDirectory() => _getSubDir('backups');
}
''')

create_file(f'{base}/api/default_filesystem_service.dart', '''import 'package:platform_core/platform_core.dart';
import '../contracts/filesystem_service.dart';
import '../directories/default_directory_provider.dart';

class DefaultFilesystemService implements FilesystemService {
  final DefaultDirectoryProvider _directoryProvider;

  DefaultFilesystemService(this._directoryProvider);

  @override
  String get serviceName => 'PlatformFilesystem';

  @override
  Future<void> initialize() async {
    await _directoryProvider.initialize();
  }

  @override
  Future<void> shutdown() async {
    // Cleanup temp logic could go here
  }
}
''')

create_file(f'{base}/files/default_file_manager.dart', '''import 'dart:io';
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
''')

create_file(f'{base}/integrity/crypto_integrity_verifier.dart', '''import 'dart:io';
import 'package:crypto/crypto.dart';
import '../contracts/integrity_verifier.dart';

class CryptoIntegrityVerifier implements IntegrityVerifier {
  @override
  Future<IntegrityResult> verifySha256(File file, String expectedHash) async {
    if (!await file.exists()) {
      return IntegrityResult(isValid: false, expectedHash: expectedHash, actualHash: 'file_not_found');
    }

    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    final actualHash = digest.toString();

    return IntegrityResult(
      isValid: actualHash.toLowerCase() == expectedHash.toLowerCase(),
      expectedHash: expectedHash.toLowerCase(),
      actualHash: actualHash.toLowerCase(),
    );
  }
}
''')

# Bootstrap
create_file(f'{base}/bootstrap/filesystem_bootstrap_task.dart', '''import 'package:platform_core/platform_core.dart';
import '../contracts/filesystem_service.dart';

class FilesystemBootstrapTask implements BootstrapTask {
  final FilesystemService _filesystemService;

  FilesystemBootstrapTask(this._filesystemService);

  @override
  String get name => 'PlatformFilesystem';

  @override
  BootstrapPhase get phase => BootstrapPhase.storage; // Runs in storage phase but logically separate

  @override
  Future<BootstrapResult> execute(BootstrapContext context) async {
    try {
      await _filesystemService.initialize();
      return const BootstrapResult.success(BootstrapPhase.storage);
    } catch (e) {
      return BootstrapResult.failure(BootstrapPhase.storage, e.toString());
    }
  }
}
''')

# Providers
create_file(f'{base}/providers/filesystem_providers.dart', '''import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_events/platform_events.dart';
import '../contracts/filesystem_service.dart';
import '../contracts/directory_provider.dart';
import '../contracts/file_manager.dart';
import '../contracts/integrity_verifier.dart';
import '../api/default_filesystem_service.dart';
import '../directories/default_directory_provider.dart';
import '../files/default_file_manager.dart';
import '../integrity/crypto_integrity_verifier.dart';

final directoryProvider = Provider<DirectoryProvider>((ref) {
  return DefaultDirectoryProvider();
});

final filesystemServiceProvider = Provider<FilesystemService>((ref) {
  return DefaultFilesystemService(ref.watch(directoryProvider) as DefaultDirectoryProvider);
});

final fileManagerProvider = Provider<FileManager>((ref) {
  final dirProvider = ref.watch(directoryProvider);
  final eventPublisher = ref.watch(eventPublisherProvider);
  return DefaultFileManager(dirProvider, eventPublisher);
});

final integrityVerifierProvider = Provider<IntegrityVerifier>((ref) {
  return CryptoIntegrityVerifier();
});
''')

# Export file
create_file('packages/platform_filesystem/lib/platform_filesystem.dart', '''library platform_filesystem;

export 'src/contracts/filesystem_service.dart';
export 'src/contracts/directory_provider.dart';
export 'src/contracts/file_manager.dart';
export 'src/contracts/cache_manager.dart';
export 'src/contracts/integrity_verifier.dart';
export 'src/contracts/import_export_service.dart';

export 'src/files/platform_file.dart';
export 'src/files/file_types.dart';

export 'src/events/filesystem_events.dart';

export 'src/providers/filesystem_providers.dart';
export 'src/bootstrap/filesystem_bootstrap_task.dart';
''')

print("Created all platform_filesystem files.")
