import 'dart:io';
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
