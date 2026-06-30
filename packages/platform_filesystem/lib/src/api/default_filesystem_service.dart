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
